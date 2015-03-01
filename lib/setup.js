/**
 *
 *  ioBroker installer from npm
 *
 *  1'2015 bluefox <bluefox@ccu.io>
 *
 *
 */

/* jshint -W097 */// jshint strict:false
/*jslint node: true */
"use strict";


var yargs = require('yargs')
    .usage('Commands:\n' +
        '$0 [--objects <host>] [--states <host>] [custom]\n')
    .default('objects', '127.0.0.1')
    .default('states',  '127.0.0.1')
    .default('lang',    'en')
;

var fs = require('fs');

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
            if (dirpath[i] != '..') {
                fs.mkdirSync(rootpath);
            } else {
                throw 'Cannot create ' + rootpath + dirpath.join('/');
            }
        }
    }
};

function copyFile(source, target, cb) {
    var cbCalled = false;

    var rd = fs.createReadStream(source);
    rd.on("error", function(err) {
        done(err);
    });
    var wr = fs.createWriteStream(target);
    wr.on("error", function(err) {
        done(err);
    });
    wr.on("close", function(ex) {
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
            cnt--;
            if (!cnt) {
                // Call npm install node-windows
                var exec = require('child_process').exec;
                // js-controller installed as npm
                console.log('npm install node-windows --production --prefix "' + __dirname + '/../../../"');
                var child = exec('npm install node-windows --production --prefix "' + __dirname + '/../../../"');
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

function setupLinux(callback) {
    fs.writeFileSync(__dirname + '/../../../iobroker', "node node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5", {mode: '777'});
    console.log('Write "./iobroker start" to start the ioBroker');
    fs.chmodSync(__dirname + '/../../../iobroker', '777');
    fs.chmodSync(__dirname + '/../../iobroker.js-controller/iobroker', '777');

    // replace @@path@@ with position of
    var parts = __dirname.replace(/\\/g, '/').split('/');
    // remove lib
    parts.pop();
    // remove iobroker
    parts.pop();

    var home = JSON.parse(JSON.stringify(parts));
    // remove node_modules
    home.pop();

    // check if /etc/init.d/ exists
    if (fs.existsSync('/usr/bin')) {
        fs.writeFileSync('/usr/bin/iobroker', 'node ' + home.join('/') + '/node_modules/iobroker.js-controller/iobroker.js $1 $2 $3 $4 $5', {mode: "777"});
        fs.chmodSync('/usr/bin/iobroker', '777');
    }

    // check if /etc/init.d/ exists
    if (fs.existsSync('/etc/init.d')) {
        // replace @@path@@ with position of
        var path = parts.join('/') + '/iobroker.js-controller/';

        var txt = fs.readFileSync(__dirname + '/../install/linux/iobroker.sh');
        txt = txt.toString().replace(/@@PATH@@/g, path);
        txt = txt.toString().replace(/@@HOME@@/g, home.join('/'));
        fs.writeFileSync(__dirname + '/../install/linux/iobroker.sh', txt, {mode: '777'});
        fs.chmodSync(__dirname + '/../install/linux/iobroker.sh', '777');

        // copy iobroker.sh from install/linux to /etc/init.d/
        copyFile(__dirname + '/../install/linux/iobroker.sh', '/etc/init.d/iobroker.sh', function () {
            txt = fs.readFileSync(__dirname + '/../install/linux/install.sh');
            txt = txt.toString().replace(/@@PATH@@/g, path);
            fs.writeFileSync(__dirname + '/../install/linux/install.sh', txt, {mode: '777'});
            fs.chmodSync(__dirname + '/../install/linux/install.sh', '777');

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
            var exec = require('child_process').exec;
            // js-controller installed as npm
            var child = exec('bash ' + __dirname + '/../install/linux/install.sh');
            child.stderr.pipe(process.stdout);
            child.on('exit', function (errCode) {
                console.log('Auto-start was enabled. Write "update-rc.d -f iobroker.sh remove" to disable auto-start');
                console.log('iobroker is started. Go to "http://ip-addr:8081" to open the admin UI.');
                if (callback) callback();
            });
        });
    }
}

function npmInstall(packet, callback) {
	var exec = require('child_process').exec;
	// install from npm
	console.log('npm install ' + packet + ' --production --silent --prefix "' + __dirname + '/../../../"');
	var child = exec('npm install ' + packet + ' --production --silent --prefix "' + __dirname + '/../../../"');
	child.stderr.pipe(process.stdout);
	child.on('exit', callback);
}

function setup(callback) {
    var config;
    var platform = require('os').platform();
    var otherInstallDirs = [];

	// install io-brocker.js-controller
	npmInstall('iobroker.js-controller', function () {
		npmInstall('iobroker.admin', function () {
		    if (!fs.existsSync(__dirname + '/../../../iobroker-data/iobroker.json')) {
				if (fs.existsSync(__dirname + '/../../iobroker.js-controller/conf/iobroker-dist.json')) {				
					config = require(__dirname + '/../../iobroker.js-controller/conf/iobroker-dist.json');
					console.log('creating conf/iobroker.json');
					config.objects.host = yargs.argv.objects || '127.0.0.1';
					config.states.host  = yargs.argv.states  || '127.0.0.1';
					config.dataDir      = tools.getDefaultDataDir();
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

                if (platform == 'linux' || platform == 'darwin') {
                    setupLinux(callback);
                    return;
                } else if (platform.match(/^win/)) {
                    setupWindows(callback);
                    return;
                }
			} catch (e) {
				console.log('Non-critical error: ' + e.message);
			}
		});
	});	
}

function setChmod(callback) {
    var platform = require('os').platform();
    console.log('Host "' + require('os').hostname() + '" (' + platform + ') updated');
    // Call command chmod +x __dirname if under linux or darwin
    if (platform == 'linux' || platform == 'darwin') {
        var exec = require('child_process').exec;
        var dir = __dirname.replace(/\\/g, '/');
        // remove last /lib"
        var parts = dir.split('/');
        parts.pop();
        dir = parts.join('/');
        var cmd = 'chmod 777 -R ' + dir;
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