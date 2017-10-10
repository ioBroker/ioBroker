/**
 *
 *  ioBroker installer from npm
 *
 *  Copyright 1'2015-2016 bluefox <dogafox@gmail.com>
 *
 *
 */

/* jshint -W097 */// jshint strict:false
/*jslint node: true */
'use strict';

var yargs = require('yargs')
    .usage('Commands:\n' +
        '$0 [--objects <host>] [--states <host>] [custom]\n')
    .default('objects', '127.0.0.1')
    .default('states',  '127.0.0.1')
    .default('lang',    'en')
;

var fs   = require('fs');
var path = require('path');

// Save objects before exit
function processExit(exitCode) {
    process.exit(exitCode);
}

function mkpathSync(rootpath, dirpath) {
    // Remove filename
    dirpath = dirpath.split('/');
    dirpath.pop();
    if (!dirpath.length) return;

    for (var i = 0; i < dirpath.length; i++) {
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

function copyFile(source, target, cb) {
    var cbCalled = false;

    var rd = fs.createReadStream(source);
    rd.on('error', function(err) {
        done(err);
    });
    var wr = fs.createWriteStream(target);
    wr.on('error', function(err) {
        done(err);
    });
    wr.on('close', function(ex) {
        done();
    });
    rd.pipe(wr);

    function done(err) {
        if (!cbCalled) {
            if (cb) cb(err);
            cbCalled = true;
        }
    }
}

function setupWindows(callback) {
    fs.writeFileSync(__dirname + '/../../../iobroker.bat', 'node node_modules/iobroker.js-controller/iobroker.js %1 %2 %3 %4 %5');
    console.log('Write "iobroker start" to start the ioBroker');

    if (!fs.existsSync(process.env['APPDATA'] + '/npm')) fs.mkdirSync(process.env['APPDATA'] + '/npm');
    if (!fs.existsSync(process.env['APPDATA'] + '/npm-cache')) fs.mkdirSync(process.env['APPDATA'] + '/npm-cache');

    // Copy files from ../install/windows/ to path
    var files = fs.readdirSync(__dirname + '/../install/windows');
    var cnt = 0;
    for (var f = 0; f < files.length; f++) {
        cnt++;
        copyFile(__dirname + '/../install/windows/' + files[f], __dirname + '/../../../' + files[f], function () {
            if (!--cnt) {
                // Call npm install node-windows
                var exec = require('child_process').exec;
                // js-controller installed as npm
                console.log('npm install https://github.com/arthurblake/node-windows/tarball/f1fd60e93e2469663b99a9cf3a64086ecedfe1e4 --production --prefix "' + __dirname + '/../../../"');
                var child = exec('npm install https://github.com/arthurblake/node-windows/tarball/f1fd60e93e2469663b99a9cf3a64086ecedfe1e4 --production --prefix "' + __dirname + '/../../../"');
                child.stderr.pipe(process.stdout);
                child.on('exit', function () {
                    // call node install.js
                    // install node as service
                    var child1 = exec('node "' + __dirname + '/../../../install.js"');
                    child1.stderr.pipe(process.stdout);
                    child1.on('exit', function () {
                        console.log('ioBroker service installed. Write "serviceIoBroker start" to start the service and go to http://localhost:8081 to open the admin UI.');
                        console.log('To see the outputs do not start the service, but write "node node_modules/iobroker.js-controller/controller"');
                        if (callback) callback();
                    });
                });
            }
        });
    }
}

function setupFreeBSD(callback) {
    fs.writeFileSync(__dirname + '/../../../iobroker', "node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5", {mode: '755'});
    console.log('Write "service iobroker start" to start the ioBroker');
    try {
        if (!fs.existsSync(__dirname + '/../../iobroker.js-controller/iobroker')) {
            fs.writeFileSync(__dirname + '/../../iobroker.js-controller/iobroker', "#!/usr/bin/env node\nrequire(__dirname + '/lib/setup.js');");
        }
        fs.chmodSync(__dirname + '/../../../iobroker', '755');
        fs.chmodSync(__dirname + '/../../iobroker.js-controller/iobroker', '755');
    } catch (e) {
        console.error('Cannot set permissions of ' + path.normalize(__dirname + '/../../iobroker.js-controller/iobroker'));
        console.log('You can still manually copy ')
    }

    // replace @@PATH@@ with position of
    var parts = __dirname.replace(/\\/g, '/').split('/');
    // remove lib
    parts.pop();
    // remove iobroker
    parts.pop();
    var text = '';

    var home = JSON.parse(JSON.stringify(parts));
    // remove node_modules
    home.pop();

    text += 'cp ' + path.normalize(__dirname + '/../install/iobroker') + ' /usr/bin/\n';
    text += 'chmod 755 /usr/bin/iobroker\n';
    text += 'cp ' + path.normalize(__dirname + '/../install/freebsd/iobroker.sh') + ' /etc/init.d/\n';
    text += 'chmod 755 /etc/init.d/iobroker.sh\n';
    text += 'bash ' + path.normalize(__dirname + '/../install/freebsd/install.sh') + '\n';

    try {
        fs.writeFileSync(__dirname + '/../../../install.sh', text, {mode: 511});
    } catch (e) {

    }

    try{
        // check if /etc/init.d/ exists
        if (fs.existsSync('/usr/local/bin')) {
            fs.writeFileSync('/usr/local/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: "755"});
            fs.chmodSync('/usr/bin/iobroker', '755');
        }
    } catch (e) {
        console.warn('Cannot create file /usr/local/bin/iobroker!. Non critical');
        // create files for manual coping
        fs.writeFileSync(__dirname + '/../install/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: "755"});
        console.log('');
        console.log('-----------------------------------------------------');
        console.log('You can manually copy file into /usr/local/bin/. Just write:');
        console.log('    cp ' + path.normalize(__dirname + '/../install/iobroker') + ' /usr/local/bin/');
        console.log('    chmod 755 /usr/local/bin/iobroker');
        console.log('-----------------------------------------------------');
    }

    if (fs.existsSync('/usr/local/etc/rc.d')) {
        // replace @@PATH@@ with position of
        var _path = parts.join('/') + '/iobroker.js-controller/';

        var txt = fs.readFileSync(__dirname + '/../install/freebsd/iobroker');
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        fs.writeFileSync(__dirname + '/../install/freebsd/iobroker', txt, {mode: '755'});
        fs.chmodSync(__dirname + '/../install/freebsd/iobroker', '755');

        // copy iobroker from install/freebsd to /usr/local/etc/rc.d
        copyFile(__dirname + '/../install/freebsd/iobroker', '/usr/local/etc/rc.d/iobroker', function (err) {
            txt = fs.readFileSync(__dirname + '/../install/freebsd/install.sh');
            txt = txt.toString().replace(/@@PATH@@/g, _path);

            fs.writeFileSync(__dirname + '/../install/freebsd/install.sh', txt, {mode: '755'});
            fs.chmodSync(__dirname + '/../install/freebsd/install.sh', '755');

            var exec = require('child_process').exec;
            // js-controller installed as npm
            var child;

            if (err) {
                console.error('Cannot copy file to /usr/local/etc/rc.d/iobroker: ' + err);
                console.log('');
                console.log('-----------------------------------------------------');
                console.log('You can manually copy file and install autostart: ');
                console.log('     cp ' + path.normalize(__dirname + '/../install/freebsd/iobroker') + ' /usr/local/etc/rc.d/');
                console.log('     chmod 755 /usr/local/etc/rc.d/iobroker');
                console.log('     sh ' + path.normalize(__dirname + '/../install/freebsd/install.sh'));
                console.log('-----------------------------------------------------');
                console.log(' or just start "sh ' + path.normalize(__dirname + '/../../../install.sh') + '"');
                console.log('-----------------------------------------------------');
                if (callback) callback();
            } else {
                // call
                child = exec('bash ' + __dirname + '/../install/freebsd/install.sh');
                child.stderr.pipe(process.stdout);
                child.on('exit', function (errCode) {
                    console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
                    console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
                    if (callback) callback();
                });
            }
        });
    }
}

function setupLinux(callback) {
    fs.writeFileSync(__dirname + '/../../../iobroker', "node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5", {mode: '777'});
    console.log('Write "./iobroker start" to start the ioBroker');
    try {
        if (!fs.existsSync(__dirname + '/../../iobroker.js-controller/iobroker')) {
            fs.writeFileSync(__dirname + '/../../iobroker.js-controller/iobroker', "#!/usr/bin/env node\nrequire(__dirname + '/lib/setup.js');");
        }
        fs.chmodSync(__dirname + '/../../../iobroker', '777');
        fs.chmodSync(__dirname + '/../../iobroker.js-controller/iobroker', '777');
    } catch (e) {
        console.error('Cannot set permissions of ' + path.normalize(__dirname + '/../../iobroker.js-controller/iobroker'));
        console.log('You can still manually copy ')
    }

    // replace @@path@@ with position of
    var parts = __dirname.replace(/\\/g, '/').split('/');
    // remove lib
    parts.pop();
    // remove iobroker
    parts.pop();
    var text = '';

    var home = JSON.parse(JSON.stringify(parts));
    // remove node_modules
    home.pop();

    text += 'sudo cp ' + path.normalize(__dirname + '/../install/iobroker') + ' /usr/bin/\n';
    text += 'sudo chmod 777 /usr/bin/iobroker\n';
    text += 'sudo cp ' + path.normalize(__dirname + '/../install/linux/iobroker.sh') + ' /etc/init.d/\n';
    text += 'sudo chmod 777 /etc/init.d/iobroker.sh\n';
    text += 'sudo bash ' + path.normalize(__dirname + '/../install/linux/install.sh') + '\n';

    try {
        fs.writeFileSync(__dirname + '/../../../install.sh', text, {mode: 511});
    } catch (e) {

    }

    try{
        // check if /etc/init.d/ exists
        if (fs.existsSync('/usr/bin')) {
            fs.writeFileSync('/usr/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: "777"});
            fs.chmodSync('/usr/bin/iobroker', '777');
        }
    } catch (e) {
        console.warn('Cannot create file /usr/bin/iobroker!. Non critical');
        // create files for manual coping
        fs.writeFileSync(__dirname + '/../install/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: "777"});
        console.log('');
        console.log('-----------------------------------------------------');
        console.log('You can manually copy file into /usr/bin/. Just write:');
        console.log('    sudo cp ' + path.normalize(__dirname + '/../install/iobroker') + ' /usr/bin/');
        console.log('    sudo chmod 777 /usr/bin/iobroker');
        console.log('-----------------------------------------------------');
    }

    var platform = require('os').platform();
    if (platform === 'freebsd' && fs.existsSync('/usr/local/etc/rc.d')) {
        // replace @@PATH@@ with position of
        var _path = parts.join('/') + '/iobroker.js-controller/';

        var txt = fs.readFileSync(__dirname + '/../install/freebsd/iobroker');
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        fs.writeFileSync(__dirname + '/../install/freebsd/iobroker', txt, {mode: '755'});
        fs.chmodSync(__dirname + '/../install/freebsd/iobroker', '755');

        // copy iobroker from install/freebsd to /usr/local/etc/rc.d
        copyFile(__dirname + '/../install/freebsd/iobroker', '/usr/local/etc/rc.d/iobroker', function (err) {
            txt = fs.readFileSync(__dirname + '/../install/freebsd/install.sh');
            txt = txt.toString().replace(/@@PATH@@/g, _path);

            fs.writeFileSync(__dirname + '/../install/freebsd/install.sh', txt, {mode: '755'});
            fs.chmodSync(__dirname + '/../install/freebsd/install.sh', '755');

            var exec = require('child_process').exec;
            // js-controller installed as npm
            var child;

            if (err) {
                console.error('Cannot copy file to /usr/local/etc/rc.d/iobroker: ' + err);
                console.log('');
                console.log('-----------------------------------------------------');
                console.log('You can manually copy file and install autostart: ');
                console.log('     cp ' + path.normalize(__dirname + '/../install/freebsd/iobroker') + ' /usr/local/etc/rc.d/');
                console.log('     chmod 755 /usr/local/etc/rc.d/iobroker');
                console.log('     sh ' + path.normalize(__dirname + '/../install/freebsd/install.sh'));
                console.log('-----------------------------------------------------');
                console.log(' or just start "sh ' + path.normalize(__dirname + '/../../../install.sh') + '"');
                console.log('-----------------------------------------------------');
                if (callback) callback();
            } else {
                // call
                child = exec('bash ' + __dirname + '/../install/freebsd/install.sh');
                child.stderr.pipe(process.stdout);
                child.on('exit', function (errCode) {
                    console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
                    console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
                    if (callback) callback();
                });
            }
        });
    }
    // check if /etc/init.d/ exists
    if (fs.existsSync('/etc/init.d')) {
        // replace @@path@@ with position of
        var _path = parts.join('/') + '/iobroker.js-controller/';

        var txt = fs.readFileSync(__dirname + '/../install/linux/iobroker.sh');
        txt = txt.toString().replace(/@@PATH@@/g, _path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        fs.writeFileSync(__dirname + '/../install/linux/iobroker.sh', txt, {mode: '777'});
        fs.chmodSync(__dirname + '/../install/linux/iobroker.sh', '777');

        // copy iobroker.sh from install/linux to /etc/init.d/
        copyFile(__dirname + '/../install/linux/iobroker.sh', '/etc/init.d/iobroker.sh', function (err) {
            txt = fs.readFileSync(__dirname + '/../install/linux/install.sh');
            txt = txt.toString().replace(/@@PATH@@/g, _path);

            fs.writeFileSync(__dirname + '/../install/linux/install.sh', txt, {mode: '777'});
            fs.chmodSync(__dirname + '/../install/linux/install.sh', '777');

            var exec = require('child_process').exec;
            // js-controller installed as npm
            var child;

            if (err) {
                console.error('Cannot copy file to /etc/init.d/iobroker.sh: ' + err);
                console.log('');
                console.log('-----------------------------------------------------');
                console.log('You can manually copy file and install autostart: ');
                console.log('     sudo cp ' + path.normalize(__dirname + '/../install/linux/iobroker.sh') + ' /etc/init.d/');
                console.log('     sudo chmod 777 /etc/init.d/iobroker.sh');
                console.log('     sudo bash ' + path.normalize(__dirname + '/../install/linux/install.sh'));
                console.log('-----------------------------------------------------');
                console.log(' or just start "sudo bash ' + path.normalize(__dirname + '/../../../install.sh') + '"');
                console.log('-----------------------------------------------------');
                if (callback) callback();
            } else {
                // call
                //echo "Set permissions..."
                //find /opt/iobroker/ -type d -exec chmod 777 {} \;
                //find /opt/iobroker/ -type f -exec chmod 777 {} \;
                //chown -R $IO_USER:$IO_USER /opt/iobroker/
                //chmod 777 /etc/init.d/iobroker.sh
                //#Replace user pi with current user
                //sed -i -e "s/IOBROKERUSER=.*/IOBROKERUSER=$IO_USER/" /etc/init.d/iobroker.sh
                //chown root:root /etc/init.d/iobroker.sh
                //update-rc.d /etc/init.d/iobroker.sh defaults
                if (gIsSudo) {
                    child = exec('sudo bash ' + __dirname + '/../install/linux/install.sh');
                } else {
                    child = exec('bash ' + __dirname + '/../install/linux/install.sh');
                }
                child.stderr.pipe(process.stdout);
                child.on('exit', function (errCode) {
                    console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
                    console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
                    if (callback) callback();
                });
            }
        });
    }
}
var gIsSudo = false;

function npmInstall(packet, isSudo, callback) {
	var exec = require('child_process').exec;
    var platform = require('os').platform();
	// install from npm
    // Calculate directory
    var parts = __dirname.replace(/\\/g, '/').split('/');
    parts.splice(parts.length - 3, 3);
    var _path = parts.join('/');

    if (isSudo) gIsSudo = true;

    var cmd = '';
    if (platform === 'linux' || platform === 'darwin') {
        cmd = 'npm install ' + packet + ' --production --prefix ' + _path;
        if (isSudo) cmd = 'sudo ' + cmd;
    } else {
        cmd = 'npm install ' + packet + ' --production --prefix "' + _path + '"';
    }
    console.log(cmd);
    var child = exec(cmd);
	child.stderr.pipe(process.stdout);
	child.on('exit', function () {
        // Check if exist
        if ((platform === 'linux' || platform === 'darwin') && !isSudo && !fs.existsSync(_path + '/node_modules/' + packet)) {
            console.log('Cannot install as normal user. Try sudo...');
            // try sudo mode
            npmInstall(packet, true, callback);
        } else {
            if(callback) callback();
        }
    });
}

function setup(callback) {
    var config;
    var platform = require('os').platform();
    var tools = require(__dirname + '/tools.js');

	// install io-brocker.js-controller
    npmInstall('iobroker.discovery', false, function () {
		npmInstall('iobroker.admin', false, function () {
			npmInstall('iobroker.js-controller', false, function () {
                if (!fs.existsSync(__dirname + '/../../../iobroker-data/iobroker.json')) {
                    if (fs.existsSync(__dirname + '/../../iobroker.js-controller/conf/iobroker-dist.json')) {
                        config = require(__dirname + '/../../iobroker.js-controller/conf/iobroker-dist.json');
                        console.log('creating conf/iobroker.json');
                        config.objects.host = yargs.argv.objects || '127.0.0.1';
                        config.states.host  = yargs.argv.states  || '127.0.0.1';
                        config.dataDir = tools.getDefaultDataDir();
                        mkpathSync(__dirname + '/', '../' + config.dataDir);
                        // Create default data dir
                        fs.writeFileSync(tools.getConfigFileName(), JSON.stringify(config, null, 2));
                    } else {
                        console.log('Could not find "' + __dirname + '/../../iobroker.js-controller/conf/iobroker-dist.json". Possible iobroker.js-controller was not installed');
                    }
                }
                try {
                    // Create iobroker.sh and bat
                    if (!fs.existsSync(__dirname + '/../../../log')) fs.mkdirSync(__dirname + '/../../../log');

                    // Create package.json in root directory, because required by npm
                    if (!fs.existsSync(__dirname + '/../../../package.json')) {
                        fs.writeFileSync(__dirname + '/../../../package.json', JSON.stringify({
                            name: 'iobroker',
                            version: '1.0.0',
                            private: true,
                            description: 'Automation platfrom in node.js'
                        }, null, 2));
                    }

                    if (platform === 'linux' || platform === 'darwin') {
                        setupLinux(callback);
                    } else if (platform.match(/^win/)) {
                        setupWindows(callback);
                    } else if (platform === 'freebsd') {
                        setupFreeBSD(callback);
                    }
                } catch (e) {
                    console.log('Non-critical error: ' + e.message);
                }
            });
		});
	});	
}

function setChmod(callback) {
    var platform = require('os').platform();
    console.log('Host "' + require('os').hostname() + '" (' + platform + ') updated');
    // Call command chmod +x __dirname if under linux or darwin
    if (platform === 'linux' || platform === 'darwin') {
        var exec = require('child_process').exec;
        var dir = __dirname.replace(/\\/g, '/');
        // remove last /lib"
        var parts = dir.split('/');
        parts.pop();
        dir = parts.join('/');
        var cmd = 'chmod -R 777 ' + dir;
        console.log('Execute: ' + cmd);
        var child = exec(cmd);
        child.stderr.pipe(process.stdout);
        child.on('exit', function () {
            console.log('Chmod finished. Restart controller');
            if (callback) callback();
        });
    } else {
        if (callback) callback();
    }
}

setup(function (code) {
	processExit(code);
});
