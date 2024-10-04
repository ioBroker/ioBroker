const { readFileSync, writeFileSync, existsSync, mkdirSync } = require('node:fs');
const Stream = require('node:stream');
const { Client } = require('ssh2');

const dist = `${__dirname}/dist/`;

const SFTP_HOST = process.env.SFTP_HOST;
const SFTP_PORT = process.env.SFTP_PORT;
const SFTP_USER = process.env.SFTP_USER;
const SFTP_PASS = process.env.SFTP_PASS;
const DEBUG     = process.env.DEBUG     === 'true' || process.env.DEBUG     === true;
const FAST_TEST = process.env.FAST_TEST === 'true' || process.env.FAST_TEST === true;

const SFTP_CONFIG = {
    host:     SFTP_HOST,
    port:     parseInt(SFTP_PORT, 10),
    username: SFTP_USER,
    password: SFTP_PASS,
};

function writeSftp(sftp, fileName, data, cb) {
    const readStream = new Stream.PassThrough();

    readStream.end(Buffer.from(data));

    const writeStream = sftp.createWriteStream(fileName);

    writeStream.on('close', () => {
        DEBUG && console.log(`${new Date().toISOString()} ${fileName} - file transferred successfully`);
        readStream.end();
        if (cb) {
            cb();
            cb = null;
        }
    });

    writeStream.on('end', () => {
        DEBUG && console.log('sftp connection closed');
        readStream.close();
        if (cb) {
            cb();
            cb = null;
        }
    });

    // initiate transfer of a file
    readStream.pipe(writeStream);
}

function uploadOneFile(fileName, data) {
    return new Promise((resolve, reject) => {
        const conn = new Client();
        conn.on('ready', () =>
            conn.sftp((err, sftp) => {
                if (err) {
                    return reject(err);
                }

                if (FAST_TEST) {
                    console.log(`Simulate upload of ${fileName}`);
                    return resolve();
                }

                // The file must be deleted, because of the new file smaller; the rest of the old file will stay.
                checkAndDeleteIfExist(sftp, fileName, () =>
                    writeSftp(sftp, fileName, data, () => {
                        sftp.end();
                        conn.end();
                        resolve();
                    }));
            }))
            .connect(SFTP_CONFIG);
    });
}

function checkAndDeleteIfExist(sftp, fileName, cb) {
    sftp.exists(fileName, doExist => {
        if (doExist) {
            sftp.unlink(fileName, cb);
        } else {
            cb();
        }
    });
}

function replaceLib(text, lib) {
    const lines = text.split('\n');
    const newLines = [];
    let ignore = false;
    for (let i = 0; i < lines.length; i++) {
        if (lines[i].includes('# get and load the LIB => START')) {
            ignore = true;
            newLines.push(lib);
        } else if (lines[i].includes('# get and load the LIB => END')) {
            ignore = false;
        } else if (!ignore) {
            newLines.push(lines[i]);
        }
    }
    return newLines.join('\n');
}

function deploy() {
    const install = readFileSync(`${dist}install.sh`);
    const fix = readFileSync(`${dist}fix.sh`);
    const diag = readFileSync(`${dist}diag.sh`);
    const nodeUpdate = readFileSync(`${dist}node-update.sh`);

    return uploadOneFile('/install.sh', install)
        .then(() => uploadOneFile('/fix.sh', fix))
        .then(() => uploadOneFile('/diag.sh', diag))
        .then(() => uploadOneFile('/node-update.sh', nodeUpdate));
}

function create() {
    if (!existsSync(dist)) {
        mkdirSync(dist);
    }

    const install  = readFileSync(`${__dirname}/installer.sh`).toString('utf8');
    const fix      = readFileSync(`${__dirname}/fix_installation.sh`).toString('utf8');
    const lib      = readFileSync(`${__dirname}/installer_library.sh`).toString('utf8');
    const diag     = readFileSync(`${__dirname}/diag.sh`).toString('utf8');
    const nodeUpdate = readFileSync(`${__dirname}/node-update.sh`).toString('utf8');

    // replace
    // LIB_NAME="installer_library.sh"
    // LIB_URL="https://raw.githubusercontent.com/ioBroker/ioBroker/stable-installer/$LIB_NAME"

    writeFileSync(`${dist}install.sh`, replaceLib(install, lib));
    writeFileSync(`${dist}fix.sh`, replaceLib(fix, lib));
    writeFileSync(`${dist}diag.sh`, diag);
    writeFileSync(`${dist}node-update.sh`, nodeUpdate);
}

function fix() {
    const pack = require('./package.json');
    pack.name = '@iobroker/fix';
    writeFileSync(`${__dirname}/package.json`, JSON.stringify(pack, null, 2));
}

if (process.argv.includes('--deploy')) {
    deploy()
        .catch(e => {
            console.error(`Cannot deploy: ${e}`);
            process.exit(1);
        });
} else if (process.argv.includes('--create')) {
    create();
} else if (process.argv.includes('--fix')) {
    fix();
} else {
    create();
    deploy()
        .catch(e => {
            console.error(`Cannot deploy: ${e}`);
            process.exit(1);
        });
}
