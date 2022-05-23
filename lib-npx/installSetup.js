/**
 *
 *  ioBroker installer from npm
 *
 *  Copyright 1'2015-2022 bluefox <dogafox@gmail.com>
 *
 *
 */

/* jshint -W097 */
/* jshint strict: false */
/* jslint node: true */
'use strict';

const yargs = require('yargs')
    .usage('Commands:\n' +
        '$0 [--objects <host>] [--states <host>] [custom]\n')
    .default('objects', '127.0.0.1')
    .default('states', '127.0.0.1')
    .default('lang', 'en');

const fs = require('fs-extra');
const path = require('path');
const { execSync }  = require('child_process');
const tools = require('./tools.js');

/** The location of this module's root dir. E.g. /opt/iobroker */
const rootDir = process.cwd();
/** The location of the js-controller module. E.g. /opt/iobroker/node_modules/iobroker.js-controller */
const controllerDir = path.join(rootDir, 'node_modules/iobroker.js-controller/');
/** The location of the executable "iobroker" (in the js-controller directory) */
// const iobrokerExecutable = path.join(controllerDir, 'iobroker');
/** The location of the executable "iobroker" inside the root directory (links to the one in js-controller) */
const iobrokerRootExecutable = path.join(rootDir, 'iobroker');
/** The location of the executable "iob" (in the js-controller directory) */
// const iobExecutable = path.join(controllerDir, 'iob');
/** The location of the executable "iob" inside the root directory (links to the one in js-controller) */
const iobRootExecutable = path.join(rootDir, 'iob');
/** The location of the log directory */
// const logDir = path.join(rootDir, 'log');
/** The location of js-controller's main module (relative) */
const jsControllerMainModule = 'node_modules/iobroker.js-controller/iobroker.js';
/** The location of js-controller's main module (absolute) */
// const jsControllerMainModuleAbsolute = path.join(rootDir, jsControllerMainModule);

/** The command line to execute ioBroker */
const commandLine = `@echo off
if %1==fix (
    npx @iobroker/fix
) else (
    if exist serviceIoBroker.bat (
        if %1==start (
            call serviceIoBroker.bat start
        ) else (
            if %1==stop (
                call serviceIoBroker.bat stop
            ) else (
                node ${jsControllerMainModule} %1 %2 %3 %4 %5
            )
        )
    ) else (
        node ${jsControllerMainModule} %1 %2 %3 %4 %5
    )
)`;

/** The command line to execute ioBroker (absolute path) */
// const commandLineAbsolute = `node ${jsControllerMainModuleAbsolute} $1 $2 $3 $4 $5`;

const debug = !!process.env.IOB_DEBUG;

// Save objects before exit
function processExit(exitCode) {
    process.exit(exitCode);
}

function setupWindows(callback) {
    const nodeWindowsVersion = require('../package.json').optionalDependencies['node-windows'].replace(/[~^<>=]+]/g, '');

    const batExists = fs.existsSync(path.join(rootDir, 'serviceIoBroker.bat'));
    fs.writeFileSync(iobrokerRootExecutable + '.bat', commandLine.replace(/\$/g, '%'));
    fs.writeFileSync(iobRootExecutable + '.bat', commandLine.replace(/\$/g, '%'));
    console.log('Write "iobroker start" to start the ioBroker');

    if (!fs.existsSync(process.env['APPDATA'] + '/npm')) {
        fs.mkdirSync(process.env['APPDATA'] + '/npm');
    }
    if (!fs.existsSync(process.env['APPDATA'] + '/npm-cache')) {
        fs.mkdirSync(process.env['APPDATA'] + '/npm-cache');
    }

    // Copy the files from /install/windows to the root dir
    tools.copyFilesRecursiveSync(path.join(rootDir, 'install/windows'), rootDir);

    // Call npm install node-windows
    // js-controller installed as npm
    const npmRootDir = rootDir.replace(/\\/g, '/');
    const cmd = `npm install node-windows@${nodeWindowsVersion} --force --loglevel error --production --save --prefix "${npmRootDir}"`;
    console.log(cmd);

    try {
        execSync(cmd, {stdio: 'inherit'});
    } catch (error) {
        console.log('Error when installing Windows Service Library: ' + error);
        callback && callback(error.code);
        return;
    }

    //console.log('Windows service library installed, now register ioBroker as Service');
    //console.log('node "' + path.join(rootDir, 'install.js') + '"');

    // stop instance if batch existed before
    try {
        if (batExists) {
            execSync('serviceIoBroker.bat stop', {
                stdio: 'inherit',
                cwd: process.cwd(),
            });
        }
    } catch (error) {
        // ignore
    }

    try {
        execSync(`node "${path.join(rootDir, 'install.js')}"`, {stdio: 'inherit'});
    } catch (error) {
        console.log('Error when registering ioBroker as service: ' + error);
        return callback && callback(error.code);
    }

    // start instance
    execSync('serviceIoBroker.bat start', {
        stdio: 'inherit',
        cwd: process.cwd(),
    });

    console.log('ioBroker service installed and started. Go to http://localhost:8081 to open the admin UI.');
    console.log('To see the outputs do not start the service, but write "node node_modules/iobroker.js-controller/controller"');
    callback && callback();
}

function log(text) {
    debug && console.log('[INSTALL] ' + text);
}

/**
 * Installs the core iobroker packages
 * @param {function} callback
 */
function setup(callback) {
    let config;
    const platform = require('os').platform();

    // We no longer create package.json and delete package-lock.json here
    // When the installation routine is run correctly, these will be in sync

    // We also no longer install the adapters manually, npm does that for us.

    log('All packages installed. Execute install.');
    if (!fs.existsSync(path.join(rootDir, 'iobroker-data', 'iobroker.json'))) {
        if (fs.existsSync(path.join(controllerDir, 'conf', 'iobroker-dist.json'))) {
            log('Create iobroker.json');
            config = require(path.join(controllerDir, 'conf', 'iobroker-dist.json'));
            console.log('creating conf/iobroker.json');
            config.objects.host = yargs.argv.objects || '127.0.0.1';
            config.states.host = yargs.argv.states || '127.0.0.1';
            config.dataDir = path.join(process.cwd(), 'iobroker-data'); //tools.getDefaultDataDir();
            // Create default data dir
            fs.ensureDirSync(config.dataDir);
            fs.writeFileSync(path.join(process.cwd(), 'iobroker-data/iobroker.json'), JSON.stringify(config, null, 2));
            execSync('iob rebuild', {
                stdio: 'inherit',
                cwd: process.cwd(),
            });
        } else {
            console.log(`Could not find "${controllerDir}/conf/iobroker-dist.json". Possible iobroker.js-controller was not installed`);
        }
    }

    // Enable autostart
    try {
        switch (platform) {
            case 'linux':
            case 'freebsd':
            case 'darwin':
                // Linux and FreeBSD is handled with the installer script
                break;
            default: {
                if (/^win/.test(platform)) {
                    // TODO: Move Windows to a PowerShell script
                    return setupWindows(callback);
                } else {
                    console.warn('Unknown platform so autostart is not enabled');
                }
            }
        }
    } catch (e) {
        console.log('Non-critical error: ' + e.message);
    }

    typeof callback === 'function' && callback();
}

setup(processExit);
