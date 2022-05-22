'use strict';

const gulp   = require('gulp');
const fs     = require('fs');
const Stream = require('stream');
const Client = require('ssh2').Client;

const dist = __dirname + '/dist/';

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

    // initiate transfer of file
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
                    console.log('Simulate upload of ' + fileName);
                    return resolve();
                }

                // file must be deleted, because of the new file smaller, the rest of old file will stay.
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

gulp.task('deploy', () => {
    const install = fs.readFileSync(dist + 'install.sh');
    const fix = fs.readFileSync(dist + 'fix.sh');

    return uploadOneFile('/install.sh', install)
        .then(() => uploadOneFile('/fix.sh', fix));
});

gulp.task('create', () => {
    return new Promise(resolve => {
        if (!fs.existsSync(dist)) {
            fs.mkdirSync(dist);
        }

        const install  = fs.readFileSync(__dirname + '/installer.sh').toString('utf8');
        const fix      = fs.readFileSync(__dirname + '/fix_installation.sh').toString('utf8');
        const lib      = fs.readFileSync(__dirname + '/installer_library.sh').toString('utf8');

        // replace
        // LIB_NAME="installer_library.sh"
        // LIB_URL="https://raw.githubusercontent.com/ioBroker/ioBroker/stable-installer/$LIB_NAME"

        fs.writeFileSync(dist + 'install.sh', replaceLib(install, lib));
        fs.writeFileSync(dist + 'fix.sh',     replaceLib(fix, lib));

        resolve();
    });
});

gulp.task('fix', async () => {
    const pack = require('package.json');
    pack.name = '@iobroker/fix';
    fs.writeFileSync(__driname + '/package.json', JSON.stringify(pack, null, 2));
});

gulp.task('default', gulp.series('create', 'deploy'));
