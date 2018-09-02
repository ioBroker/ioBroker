/**
 *
 *  ioBroker installer from npm
 *
 *  Copyright 1'2015-2018 bluefox <dogafox@gmail.com>
 *
 *
 */

/* jshint -W097 */// jshint strict:false
/*jslint node: true */
'use strict';

const yargs = require('yargs')
    .usage('Commands:\n' +
        '$0 [--objects <host>] [--states <host>] [custom]\n')
    .default('objects', '127.0.0.1')
    .default('states', '127.0.0.1')
    .default('lang', 'en');

const fs = require('fs');
const path = require('path');
const child_process = require('child_process');
const exec = child_process.exec;

/** The location of this module's root dir. E.g. /opt/iobroker */
const rootDir = path.join(__dirname, '..');
/** The location of the js-controller module. E.g. /opt/iobroker/node_modules/iobroker.js-controller */
const controllerDir = path.join(rootDir, 'node_modules/iobroker.js-controller/');

/** The location of the executable "iobroker" */
const iobrokerExecutable = path.join(controllerDir, 'iobroker');
/** The location of the executable "iobroker" inside the root directory (links to the one in js-controller) */
const iobrokerRootExecutable = path.join(rootDir, 'iobroker');
/** The location of the executable "iob" */
const iobExecutable = path.join(controllerDir, 'iob');
/** The location of the executable "iob" inside the root directory (links to the one in js-controller) */
const iobRootExecutable = path.join(rootDir, 'iob');


const debug = !!process.env.IOB_DEBUG;
let linuxAutoStart = null;
let linuxInstallSh = null;
const windowsFiles = [];

// Save objects before exit
function processExit(exitCode) {
    process.exit(exitCode);
}

// TODO: use the version in tools.js
function mkpathSync(rootpath, dirpath) {
    // Remove filename
    dirpath = dirpath.split('/');
    dirpath.pop();
    if (!dirpath.length) return;

    for (let i = 0; i < dirpath.length; i++) {
        rootpath += dirpath[i] + '/';
        if (!fs.existsSync(rootpath)) {
            if (dirpath[i] !== '..') {
                fs.mkdirSync(rootpath);
            } else {
                throw 'Cannot create ' + rootpath + dirpath.join('/');
            }
        }
    }
}

function setupWindows(callback) {
    fs.writeFileSync(rootDir + 'iobroker.bat', 'node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5');
    fs.writeFileSync(rootDir + 'iob.bat', 'node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5');
    console.log('Write "iobroker start" to start the ioBroker');

    if (!fs.existsSync(process.env['APPDATA'] + '/npm')) fs.mkdirSync(process.env['APPDATA'] + '/npm');
    if (!fs.existsSync(process.env['APPDATA'] + '/npm-cache')) fs.mkdirSync(process.env['APPDATA'] + '/npm-cache');

    // Copy files from ../install/windows/ to path
    for (let f = 0; f < windowsFiles.length; f++) {
        fs.writeFileSync(path.join(rootDir, windowsFiles[f].name), windowsFiles[f].data);
    }

    // Call npm install node-windows
    // js-controller installed as npm
    const npmRootDir = rootDir.replace(/\\/g, '/');
    console.log('npm install node-windows@0.1.14 --production --save --prefix "' + npmRootDir + '"');

    const child = exec('npm install node-windows@0.1.14 --production --save --prefix "' + npmRootDir + '"');
    child.stderr.pipe(process.stdout);
    child.on('exit', () => {
        // call node install.js
        // install node as service
        const child1 = exec('node "' + rootDir + 'install.js"');
        child1.stderr.pipe(process.stdout);
        child1.on('exit', () => {
            console.log('ioBroker service installed. Write "serviceIoBroker start" to start the service and go to http://localhost:8081 to open the admin UI.');
            console.log('To see the outputs do not start the service, but write "node node_modules/iobroker.js-controller/controller"');
            if (callback) callback();
        });
    });
}

function log(text) {
    debug && console.log('[INSTALL] ' + text);
}

function setupFreeBSD(callback) {
    log('Execute install for FreeBSD');

    fs.writeFileSync(iobrokerRootExecutable, 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
    fs.writeFileSync(iobRootExecutable, 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });

    console.log('Write "./iob start" to start the ioBroker');
    // create
    try {
        if (!fs.existsSync(iobrokerExecutable)) {
            fs.writeFileSync(iobrokerExecutable, "#!/usr/bin/env node\nrequire(__dirname + '/lib/installSetup.js');");
        }
        fs.chmodSync(iobrokerRootExecutable, '755');
        fs.chmodSync(iobrokerExecutable, '755');
        try {
            if (!fs.existsSync(iobExecutable)) {
                fs.writeFileSync(iobExecutable, "#!/usr/bin/env node\nrequire(__dirname + '/lib/installSetup.js');");
            }
            fs.chmodSync(iobRootExecutable, '755');
            fs.chmodSync(iobExecutable, '755');
        } catch (e) {
            console.error('Cannot set permissions of ' + iobExecutable);
            console.log('You can still manually copy ');
        }
    } catch (e) {
        console.error('Cannot set permissions of ' + iobrokerExecutable);
        console.log('You can still manually copy ');
    }

    // replace @@PATH@@ with position of
    const parts = __dirname.replace(/\\/g, '/').split('/');
    // remove lib
    parts.pop();
    // remove iobroker
    parts.pop();

    const home = JSON.parse(JSON.stringify(parts));
    // remove node_modules
    home.pop();

    try {
        // check if /etc/init.d/ exists
        if (fs.existsSync('/usr/local/bin')) {
            fs.writeFileSync('/usr/local/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
            fs.chmodSync('/usr/local/bin/iobroker', '755');
        }
    } catch (e) {
        console.warn('Cannot create file /usr/local/bin/iobroker!. Non critical');
        // create files for manual coping
        try {
            fs.writeFileSync(__dirname + '/../install/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
        } catch (e) {
            // don't care
        }
        console.log('');
        console.log('-----------------------------------------------------');
        console.log('You can manually copy file into /usr/local/bin/. Just write:');
        console.log('    cp ' + path.normalize(__dirname + '/../install/iobroker') + ' /usr/local/bin/');
        console.log('-----------------------------------------------------');
    }

    if (fs.existsSync('/usr/local/etc/rc.d')) {
        // replace @@PATH@@ with position of
        const _path = parts.join('/') + '/iobroker.js-controller/';

        let txt = linuxAutoStart || fs.readFileSync(__dirname + '/../install/freebsd/iobroker');
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        try {
            if (fs.existsSync(__dirname + '/../install/freebsd/')) {
                fs.writeFileSync(__dirname + '/../install/freebsd/iobroker', txt, { mode: '755' });
                fs.chmodSync(__dirname + '/../install/freebsd/iobroker', '755');
            }
        } catch (e) {
            // don't care
        }
        try {
            // copy iobroker from install/freebsd to /usr/local/etc/rc.d
            fs.writeFileSync('/usr/local/etc/rc.d/iobroker', txt);
            txt = linuxInstallSh || fs.readFileSync(__dirname + '/../install/freebsd/install.sh');
            txt = txt.toString().replace(/@@PATH@@/g, _path);

            fs.writeFileSync(path.join(rootDir, 'install.sh'), txt, { mode: '755' });
            fs.chmodSync(path.join(rootDir, 'install.sh'), '755');
        } catch (err) {
            console.error('Cannot copy file to /usr/local/etc/rc.d/iobroker: ' + err);
            console.log('');
            console.log('-----------------------------------------------------');
            console.log('You can manually copy file and install autostart: ');
            console.log('     cp ' + path.normalize(__dirname + '/../install/freebsd/iobroker') + ' /usr/local/etc/rc.d/');
            console.log('     chmod 755 /usr/local/etc/rc.d/iobroker');
            console.log('     sh ' + path.normalize(__dirname + '/../install/freebsd/install.sh'));
            console.log('-----------------------------------------------------');
            console.log(' or just start "sh ' + path.normalize(rootDir + 'install.sh') + '"');
            console.log('-----------------------------------------------------');
            if (callback) callback();
        }

        // js-controller installed as npm
        const child = exec('bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        child.stderr.pipe(process.stdout);
        child.on('exit', () => {
            console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
            console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
            callback && callback();
        });
    } else {
        callback && callback();
    }
}

function getNode() {
    if (fs.existsSync('/usr/bin/node')) {
        return '/usr/bin/node';
    } else if (fs.existsSync('/usr/bin/nodejs')) {
        return '/usr/bin/nodejs';
    } else if (fs.existsSync('/usr/sbin/nodejs')) {
        return '/usr/sbin/nodejs';
    } else if (fs.existsSync('/usr/sbin/node')) {
        return '/usr/sbin/node';
    } else {
        return '/usr/bin/node';
    }
}

function isRoot() {
    return process.getuid && process.getuid() === 0;
}

function checkUserLinux() {
    try {
        log('Check user iobroker');
        const content = fs.readFileSync('/etc/passwd');
        const users = content.toString('utf8').split('\n');
        return !!users.find(line => line.split(':')[0] === 'iobroker');
    } catch (e) {
        console.error('Cannot read /etc/passwd: ' + e);
        return false;
    }
}

function createUserLinux(callback) {
    if (checkUserLinux()) {
        log('User iobroker exists');
        return callback && callback();
    } else if (isRoot()) {
        log('Create user iobroker');

        exec('useradd -m -s /usr/sbin/nologin iobroker', err => {
            // add to serial
            exec('usermod -a -G dialout iobroker', () => {
                exec('usermod -a -G tty iobroker', () => {
                    // Add to GPIO group
                    exec('usermod -a -G gpio iobroker', () => {
                        callback(err);
                    });
                });
            });
        });
    } else {
        log('Required root rights to create user');
        callback('Not root');
    }
}

function chownLinux(user, callback) {
    if (user === 'root') {
        callback && callback();
    } else if (isRoot()) {
        log('Change owner of all files');
        exec('chown iobroker * -R', { cwd: rootDir }, err => {
            err && console.error('Cannot chwon: ' + err);
            exec('chown ' + rootDir + ' * -R', err => callback(err));
        });
    } else {
        console.warn('Write\n   "chown iobroker * -R"\nas root to change owner');
        callback && callback();
    }
}

function setupLinux(callback) {
    log('Execute install for Liunx');

    // create
    try {
        if (!fs.existsSync(iobrokerRootExecutable)) {
            log('Create ' + iobrokerRootExecutable);
            fs.writeFileSync(iobrokerRootExecutable, 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
        }
        fs.chmodSync(iobrokerRootExecutable, '755');

        if (!fs.existsSync(iobRootExecutable)) {
            log('Create ' + iobRootExecutable);
            fs.writeFileSync(iobRootExecutable, 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
        }
        fs.chmodSync(iobRootExecutable, '755');

        if (!fs.existsSync(iobrokerExecutable)) {
            log('Create ' + iobrokerExecutable);
            fs.writeFileSync(iobrokerExecutable, "#!/usr/bin/env node\nrequire(__dirname + '/lib/installSetup.js');", { mode: '755' });
        }
        fs.chmodSync(iobrokerExecutable, '755');

        if (!fs.existsSync(iobExecutable)) {
            log('Create ' + iobExecutable);
            fs.writeFileSync(iobExecutable, "#!/usr/bin/env node\nrequire(__dirname + '/lib/installSetup.js');", { mode: '755' });
        }
        fs.chmodSync(iobExecutable, '755');
    } catch (e) {
        console.error('Cannot set permissions of ' + iobrokerExecutable);
        console.log('You can still manually copy ');
    }

    // replace @@PATH@@ with position of
    const parts = __dirname.replace(/\\/g, '/').split('/');
    // remove lib
    parts.pop();
    // remove iobroker
    parts.pop();

    const home = JSON.parse(JSON.stringify(parts));
    // remove node_modules
    home.pop();

    log('home directory ' + home);

    try {
        // check if /etc/init.d/ exists
        if (fs.existsSync('/usr/bin')) {
            log('Create /usr/bin/iobroker');
            fs.writeFileSync('/usr/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
            fs.chmodSync('/usr/bin/iobroker', '755');

            log('Create /usr/bin/iob');
            fs.writeFileSync('/usr/bin/iob', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', { mode: '755' });
            fs.chmodSync('/usr/bin/iob', '755');
        }
    } catch (e) {
        console.warn('Cannot create file /usr/bin/iobroker!. Non critical');
        console.log('');
        console.log('-----------------------------------------------------');
        console.log('You can manually copy file into /usr/bin/. Just write:');
        console.log('    sudo cp ' + iobrokerRootExecutable + ' /usr/bin/');
        console.log('    sudo chmod 755 /usr/bin/iobroker');
        console.log('-----------------------------------------------------');
    }

    if (!process.env.IOB_FORCE_INITD && fs.existsSync('/lib/systemd/system/')) {
        log('Install systemd script');

        createUserLinux(err => {
            err && console.error('Cannot create user "iobroker": ' + err);

            const user = err ? 'root' : 'iobroker';
            const nodePath = getNode();

            const systemd =
                '[Unit]\n' +
                'Description=ioBroker Server\n' +
                'Documentation=http://iobroker.net\n' +
                'After=network.target\n' +
                '\n' +
                '[Service]\n' +
                'Type=simple\n' +
                'User=' + user + '\n' +
                'ExecStart=' + nodePath + ' "' + controllerDir + 'controller.js"\n' +
                'Restart=on-failure\n' +
                '\n' +
                '[Install]\n' +
                'WantedBy=multi-user.target';

            log('Create /lib/systemd/system/iobroker.service');
            log(systemd);

            fs.writeFileSync('/lib/systemd/system/iobroker.service', systemd, { mode: '755' });

            chownLinux(user, () => {
                console.log('');
                console.log('');
                console.log('===================================================');
                if (isRoot()) {
                    console.log('Write \n' +
                        '   systemctl daemon-reload\n' +
                        '   systemctl enable iobroker\n' +
                        '   systemctl start iobroker\n' +
                        '\n' +
                        'to enable auto-start and to start ioBroker');
                } else {
                    console.log('Write \n' +
                        '   sudo systemctl daemon-reload\n' +
                        '   sudo systemctl enable iobroker\n' +
                        '   sudo systemctl start iobroker\n' +
                        '\n' +
                        'to enable auto-start and to start ioBroker');
                }
                console.log('===================================================');
                console.log('');
                console.log('');
                callback && callback();
            });
        });
    } else if (fs.existsSync('/etc/init.d/')) { // check if /etc/init.d/ exists
        log('Install init.d script');
        // replace @@PATH@@ with position of
        const _path = parts.join('/') + '/iobroker.js-controller/';

        let txt = linuxAutoStart;
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));

        try {
            if (fs.existsSync(__dirname + '/../install/linux/')) {
                log('Create ' + __dirname + '/../install/linux/iobroker.sh');
                fs.writeFileSync(__dirname + '/../install/linux/iobroker.sh', txt, { mode: '755' });
                fs.chmodSync(__dirname + '/../install/linux/iobroker.sh', '755');
            }

            log('Create /etc/init.d/iobroker.sh');
            // copy iobroker.sh from install/linux to /etc/init.d/
            fs.writeFileSync('/etc/init.d/iobroker.sh', txt, { mode: '755' });

            txt = linuxInstallSh;
            txt = txt.toString().replace(/@@PATH@@/g, _path);

            log('Create ' + path.join(rootDir, 'install.sh'));
            fs.writeFileSync(path.join(rootDir, 'install.sh'), txt, { mode: '755' });
            fs.chmodSync(path.join(rootDir, 'install.sh'), '755');
        } catch (err) {
            console.error('Cannot copy file to /etc/init.d/iobroker.sh: ' + err);
            console.log('');
            console.log('-----------------------------------------------------');
            console.log('You can manually copy file and install autostart: ');
            console.log('     sudo cp ' + path.normalize(__dirname + '/../install/linux/iobroker.sh') + ' /etc/init.d/');
            console.log('     sudo chmod 755 /etc/init.d/iobroker.sh');
            console.log('     sudo bash ' + path.normalize(__dirname + '/../install/linux/install.sh'));
            console.log('-----------------------------------------------------');
            console.log(' or just start "sudo bash ' + path.normalize(rootDir + 'install.sh') + '"');
            console.log('-----------------------------------------------------');
            callback && callback();
        }

        // js-controller installed as npm
        let child;
        // call
        //echo "Set permissions..."
        //find /opt/iobroker/ -type d -exec chmod 755 {} \;
        //find /opt/iobroker/ -type f -exec chmod 755 {} \;
        //chown -R $IO_USER:$IO_USER /opt/iobroker/
        //chmod 755 /etc/init.d/iobroker.sh
        //#Replace user pi with current user
        //sed -i -e "s/IOBROKERUSER=.*/IOBROKERUSER=$IO_USER/" /etc/init.d/iobroker.sh
        //chown root:root /etc/init.d/iobroker.sh
        //update-rc.d /etc/init.d/iobroker.sh defaults
        log('Execute ' + path.normalize(path.join(rootDir, 'install.sh')));
        log(txt);

        if (gIsSudo) {
            child = exec('sudo bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        } else {
            child = exec('bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        }
        child.stderr.pipe(process.stdout);
        child.on('exit', errCode => {
            log('Exit code: ' + errCode);
            console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
            console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
            callback && callback();
        });
    }
}

const gIsSudo = false;

/**
 * Installs the core iobroker packages
 * @param {function} callback
 */
function setup(callback) {
    let config;
    const platform = require('os').platform();
    const tools = require(__dirname + '/tools.js');

    // We no longer create package.json and delete package-lock.json here
    // When the installation routine is run correctly, these will be in sync

    if (fs.existsSync('/etc/init.d/')) {
        linuxAutoStart = fs.readFileSync(__dirname + '/../install/linux/iobroker.sh');
        linuxInstallSh = fs.readFileSync(__dirname + '/../install/linux/install.sh');
    } else if (fs.existsSync('/usr/local/etc/rc.d')) {
        linuxAutoStart = fs.readFileSync(__dirname + '/../install/freebsd/iobroker');
        linuxInstallSh = fs.readFileSync(__dirname + '/../install/freebsd/install.sh');
    } else if (process.platform.startsWith('win')) {
        try {
            const wPath = __dirname + '/../install/windows';
            const files = fs.readdirSync(wPath);
            files.forEach(file => {
                windowsFiles[file] = { data: fs.readFileSync(path.join(wPath, file)).toString('utf8'), name: file };
            });
        } catch (e) {
            console.warn('Cannot read files: ' + e);
        }
    }

    // We no longer install the adapters manually, npm does that for us.

    log('All packages installed. Execute install.');
    if (!fs.existsSync(path.join(rootDir, 'iobroker-data', 'iobroker.json'))) {
        if (fs.existsSync(path.join(controllerDir, 'conf', 'iobroker-dist.json'))) {
            log('Create iobroker.json');
            config = require(path.join(controllerDir, 'conf', 'iobroker-dist.json'));
            console.log('creating conf/iobroker.json');
            config.objects.host = yargs.argv.objects || '127.0.0.1';
            config.states.host = yargs.argv.states || '127.0.0.1';
            config.dataDir = tools.getDefaultDataDir();
            mkpathSync(path.join(__dirname, '../', config.dataDir));
            // Create default data dir
            fs.writeFileSync(tools.getConfigFileName(), JSON.stringify(config, null, 2));
        } else {
            console.log('Could not find "' + controllerDir + 'conf/iobroker-dist.json". Possible iobroker.js-controller was not installed');
        }
    }

    try {
        // Create iobroker.sh and bat
        if (!fs.existsSync(rootDir + 'log')) {
            fs.mkdirSync(rootDir + 'log');
        }

        if (platform === 'linux' || platform === 'darwin') {
            setupLinux(callback);
        } else if (platform.match(/^win/)) {
            setupWindows(callback);
        } else if (platform === 'freebsd') {
            setupFreeBSD(callback);
        } else {
            console.warn('Unknown platform so autostart is not enabled');
            callback && callback();
        }
    } catch (e) {
        console.log('Non-critical error: ' + e.message);
        callback && callback();
    }
}
/*
function setChmod(callback) {
    const platform = require('os').platform();
    console.log('Host "' + require('os').hostname() + '" (' + platform + ') updated');
    // Call command chmod +x __dirname if under linux or darwin
    if (platform === 'linux' || platform === 'darwin') {
        let dir = __dirname.replace(/\\/g, '/');
        // remove last /lib'
        const parts = dir.split('/');
        parts.pop();
        dir = parts.join('/');
        const cmd = 'chmod -R 755 ' + dir;
        console.log('Execute: ' + cmd);
        const child = exec(cmd);
        child.stderr.pipe(process.stdout);
        child.on('exit', () => {
            console.log('Chmod finished. Restart controller');
            if (callback) callback();
        });
    } else {
        if (callback) callback();
    }
}*/

setup(processExit);