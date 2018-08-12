//@ts-check

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
const rootDir = path.normalize(__dirname + '/../../../');
console.log('ROOT DIR ' + rootDir);
console.log('DIRNAME DIR ' + __dirname);
const jsDir = rootDir + 'node_modules/iobroker.js-controller/';
const child_process = require('child_process');

let linuxAutoStart = null;
let linuxInstallSh = null;
let windowsFiles = [];

// Save objects before exit
function processExit(exitCode) {
    process.exit(exitCode);
}

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

    const child = require('child_process').exec('npm install node-windows@0.1.14 --production --save --prefix "' + npmRootDir + '"');
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

function setupFreeBSD(callback) {
    fs.writeFileSync(rootDir + 'iobroker', 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
    fs.writeFileSync(rootDir + 'iob', 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});

    console.log('Write "./iob start" to start the ioBroker');
    // create
    try {
        if (!fs.existsSync(jsDir + 'iobroker')) {
            fs.writeFileSync(jsDir + 'iobroker', "#!/usr/bin/env node\nrequire(__dirname + '/lib/setup.js');");
        }
        fs.chmodSync(rootDir + 'iobroker', '755');
        fs.chmodSync(jsDir + 'iobroker', '755');
        try {
            if (!fs.existsSync(jsDir + 'iob')) {
                fs.writeFileSync(jsDir + 'iob', "#!/usr/bin/env node\nrequire(__dirname + '/lib/setup.js');");
            }
            fs.chmodSync(rootDir + 'iob', '755');
            fs.chmodSync(jsDir + 'iob', '755');
        } catch (e) {
            console.error('Cannot set permissions of ' + path.normalize(jsDir + 'iob'));
            console.log('You can still manually copy ')
        }
    } catch (e) {
        console.error('Cannot set permissions of ' + path.normalize(jsDir + 'iobroker'));
        console.log('You can still manually copy ')
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
            fs.writeFileSync('/usr/local/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
            fs.chmodSync('/usr/local/bin/iobroker', '755');
        }
    } catch (e) {
        console.warn('Cannot create file /usr/local/bin/iobroker!. Non critical');
        // create files for manual coping
        fs.writeFileSync(__dirname + '/../install/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
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
                fs.writeFileSync(__dirname + '/../install/freebsd/iobroker', txt, {mode: '755'});
                fs.chmodSync(__dirname + '/../install/freebsd/iobroker', '755');
            }
        } catch (e) {

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
        let child = require('child_process').exec('bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        child.stderr.pipe(process.stdout);
        child.on('exit', errCode => {
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

function checkUser() {
    try {
        const content = fs.readFileSync('/etc/passwd');
        let users = content.toString('utf8').split('\n');
        return !!users.find(line => line.split(':')[0] === 'iobroker');
    } catch (e) {
        console.error('Cannot read /etc/passwd: ' + e);
        return false;
    }
}

function createUser(cb) {
    if (checkUser()) {
        return cb && cb();
    } else
    if (isRoot()) {
        require('child_process')
            .exec('useradd -m -s /usr/sbin/nologin iobroker', (err, stdout, stderr) => callback(err));
    } else {
        cb('Not root');
    }
}

function setupLinux(callback) {
    fs.writeFileSync(rootDir + 'iobroker', 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
    fs.writeFileSync(rootDir + 'iob', 'node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});

    console.log('Write "./iob start" to start the ioBroker');
    // create
    try {
        if (!fs.existsSync(jsDir + 'iobroker')) {
            fs.writeFileSync(jsDir + 'iobroker', "#!/usr/bin/env node\nrequire(__dirname + '/lib/setup.js');");
        }
        fs.chmodSync(rootDir + 'iobroker', '755');
        fs.chmodSync(jsDir + 'iobroker', '755');
        try {
            if (!fs.existsSync(jsDir + 'iob')) {
                fs.writeFileSync(jsDir + 'iob', "#!/usr/bin/env node\nrequire(__dirname + '/lib/setup.js');");
            }
            fs.chmodSync(rootDir + 'iob', '755');
            fs.chmodSync(jsDir + 'iob', '755');
        } catch (e) {
            console.error('Cannot set permissions of ' + path.normalize(jsDir + 'iob'));
            console.log('You can still manually copy ')
        }
    } catch (e) {
        console.error('Cannot set permissions of ' + path.normalize(jsDir + 'iobroker'));
        console.log('You can still manually copy ')
    }

    // replace @@path@@ with position of
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
        if (fs.existsSync('/usr/bin')) {
            fs.writeFileSync('/usr/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
            fs.chmodSync('/usr/bin/iobroker', '755');
            fs.writeFileSync('/usr/bin/iob', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
            fs.chmodSync('/usr/bin/iob', '755');
        }
    } catch (e) {
        console.warn('Cannot create file /usr/bin/iobroker!. Non critical');
        // create files for manual coping
        fs.writeFileSync(__dirname + '/../install/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: '755'});
        console.log('');
        console.log('-----------------------------------------------------');
        console.log('You can manually copy file into /usr/bin/. Just write:');
        console.log('    sudo cp ' + path.normalize(__dirname + '/../install/iobroker') + ' /usr/bin/');
        console.log('    sudo chmod 755 /usr/bin/iobroker');
        console.log('-----------------------------------------------------');
    }

    const platform = require('os').platform();
    if (platform === 'freebsd' && fs.existsSync('/usr/local/etc/rc.d')) {
        // replace @@PATH@@ with position of
        const _path = parts.join('/') + '/iobroker.js-controller/';

        let txt = linuxAutoStart || fs.readFileSync(__dirname + '/../install/freebsd/iobroker');
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        try {
            if (fs.existsSync(__dirname + '/../install/linux/')) {
                fs.writeFileSync(__dirname + '/../install/freebsd/iobroker', txt, {mode: '755'});
                fs.chmodSync(__dirname + '/../install/freebsd/iobroker', '755');
            }
        } catch (e) {

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
        let child = require('child_process').exec('bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        child.stderr.pipe(process.stdout);
        child.on('exit', errCode => {
            console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
            console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
            callback && callback();
        });
    } else
    if (fs.existsSync('/lib/systemd/system/')) {
        createUser(err => {
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
                'ExecStart=' + nodePath + ' "' + jsDir + 'controller.js"\n' +
                'Restart=on-failure\n' +
                '\n' +
                '[Install]\n' +
                'WantedBy=multi-user.target';

            fs.writeFileSync('/lib/systemd/system/iobroker.service', systemd, {mode: '755'});

            console.log('Write \n' +
                '   sudo systemtl enable iobroker\n' +
                '   sudo systemctl start iobroker\n' +
                '\n' +
                'to enable autostart and to start ioBroker');
            callback && callback();
        });
    } else
    // check if /etc/init.d/ exists
    if (fs.existsSync('/etc/init.d/')) {
        // replace @@path@@ with position of
        const _path = parts.join('/') + '/iobroker.js-controller/';

        let txt = linuxAutoStart || fs.readFileSync(__dirname + '/../install/linux/iobroker.sh');
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        try {
            if (fs.existsSync(__dirname + '/../install/linux/')) {
                fs.writeFileSync(__dirname + '/../install/linux/iobroker.sh', txt, {mode: '755'});
                fs.chmodSync(__dirname + '/../install/linux/iobroker.sh', '755');
            }

            // copy iobroker.sh from install/linux to /etc/init.d/
            fs.writeFileSync('/etc/init.d/iobroker.sh', txt, {mode: '755'});

            txt = linuxInstallSh || fs.readFileSync(__dirname + '/../install/freebsd/install.sh');
            txt = txt.toString().replace(/@@PATH@@/g, _path);

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

        const exec = require('child_process').exec;
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
        if (gIsSudo) {
            child = exec('sudo bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        } else {
            child = exec('bash ' + path.normalize(path.join(rootDir, 'install.sh')));
        }
        child.stderr.pipe(process.stdout);
        child.on('exit', errCode => {
            console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
            console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
            callback && callback();
        });
    }
}

let gIsSudo = false;

/**
 * Installs an npm packet
 * @param {string} packet The packet (or packet url) to install
 * @param {boolean} isSudo Whether the installation should be executed with or without `sudo`
 * @param {function} callback Called after the installation is finished
 */
function npmInstall(packet, isSudo, callback) {
    const platform = require('os').platform();
    if (isSudo) gIsSudo = true;

    let cmd = 'npm install ' + packet + ' --production --save';
    if (isSudo && (platform === 'linux' || platform === 'darwin')) {
        cmd = 'sudo ' + cmd;
    }

    console.log(cmd);
    const child = child_process.exec(cmd, {cwd: rootDir});
    child.stdout.pipe(process.stdout);
    child.stderr.pipe(process.stdout);
    child.on('exit', () => {
        let packetFolder = packet.toLowerCase();
        // clean up packet directory
        // extract the packet name from a github url
        if (packetFolder.indexOf('github.com') > -1) {
            packetFolder = /github\.com\/\w+\/([^\/]+)\//.exec(packetFolder)[1]
        }
        // remove dist-tag
        // scoped packages start with @, so we have to check if @ is in a later position
        if (packetFolder.indexOf('@') > 0) {
            packetFolder = packetFolder.substr(0, packetFolder.indexOf('@'));
        }
        packetFolder = path.join(rootDir, '/node_modules/', packetFolder);
        console.log('packet folder is: ' + packetFolder + ' | exists: ' + fs.existsSync(packetFolder));
        // Check if the packet was installed
        if ((platform === 'linux' || platform === 'darwin') && !isSudo && !fs.existsSync(packetFolder)) {
            console.log('Cannot install as normal user. Try sudo...');
            // try sudo mode
            npmInstall(packet, true, callback);
        } else {
            if(callback) callback();
        }
    });
}

function createPackageJson() {
    const ownVersion = require(__dirname + '/../package.json').version;

    fs.writeFileSync(rootDir + 'package.json', JSON.stringify({
        name: 'iobroker.inst',
        version: ownVersion,
        private: true,
        description: 'Automation platform in node.js',
        dependencies: {
        }
    }, null, 2));
}
/**
 * Installs the core iobroker packages
 * @param {function} callback
 */
function setup(callback) {
    let config;
    const platform = require('os').platform();
    const tools = require(__dirname + '/tools.js');

    // Create package.json in root directory, because required by npm
    if (!fs.existsSync(rootDir + 'package.json')) {
        createPackageJson();
    } else {
        try {
            let pack = JSON.parse(fs.readFileSync(rootDir + 'package.json').toString('utf8'));
            // add iobroker, iobroker.js-controller and iobroker.admin to dependencies
            const ownVersion = require(__dirname + '/../package.json').version;
            pack.dependencies.iobroker = '^' + ownVersion;
            fs.writeFileSync(rootDir + 'package.json', JSON.stringify(pack, null, 2));
        } catch (e) {
            createPackageJson();
        }
    }

    // if there's a package-lock.json, it has been created by `npm install iobroker`
    // and will mess with all future installations if left unchanged
    // by deleting it, we enable npm to recreate it with the correct content
    if (fs.existsSync(rootDir + 'package-lock.json')) {
        try {
            fs.unlinkSync(rootDir + 'package-lock.json');
        } catch (e) {
            console.error('Aborting installation because package-lock.json exists and cannot be deleted.');
            processExit(1);
        }
    }
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
                windowsFiles[file] = {data: fs.readFileSync(path.join(wPath, file)).toString('utf8'), name: file};
            });
        } catch (e) {
            console.warn('Cannot read files: ' + e);
        }
    }

    // install io-broker.js-controller
    npmInstall('iobroker.discovery@stable', false, () => {
        npmInstall('iobroker.admin@stable', false, () => {
            npmInstall('iobroker.js-controller@stable', false, () => {

                if (!fs.existsSync(path.join(rootDir, 'iobroker-data', 'iobroker.json'))) {
                    if (fs.existsSync(path.join(jsDir, 'conf', 'iobroker-dist.json'))) {
                        config = require(path.join(jsDir, 'conf', 'iobroker-dist.json'));
                        console.log('creating conf/iobroker.json');
                        config.objects.host = yargs.argv.objects || '127.0.0.1';
                        config.states.host  = yargs.argv.states  || '127.0.0.1';
                        config.dataDir = tools.getDefaultDataDir();
                        mkpathSync(path.join(__dirname, '../', config.dataDir));
                        // Create default data dir
                        fs.writeFileSync(tools.getConfigFileName(), JSON.stringify(config, null, 2));
                    } else {
                        console.log('Could not find "' + jsDir + 'conf/iobroker-dist.json". Possible iobroker.js-controller was not installed');
                    }
                }

                try {
                    // Create iobroker.sh and bat
                    if (!fs.existsSync(rootDir + 'log')) fs.mkdirSync(rootDir + 'log');

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
            });
        });
    });
}
/*
function setChmod(callback) {
    const platform = require('os').platform();
    console.log('Host "' + require('os').hostname() + '" (' + platform + ') updated');
    // Call command chmod +x __dirname if under linux or darwin
    if (platform === 'linux' || platform === 'darwin') {
        const exec = require('child_process').exec;
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
