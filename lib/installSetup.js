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

const fs = require('fs-extra');
const path = require('path');
const tools = require('./tools.js');

/** The location of this module's root dir. E.g. /opt/iobroker */
const rootDir = path.join(__dirname, '..');
/** The location of the js-controller module. E.g. /opt/iobroker/node_modules/iobroker.js-controller */
const controllerDir = path.join(rootDir, 'node_modules/iobroker.js-controller/');

const debug = !!process.env.IOB_DEBUG;

// Save objects before exit
function processExit(exitCode) {
    process.exit(exitCode);
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
            config.dataDir = tools.getDefaultDataDir();
            // Create default data dir
            fs.ensureDirSync(config.dataDir);
            fs.writeFileSync(tools.getConfigFileName(), JSON.stringify(config, null, 2));
        } else {
            console.log('Could not find "' + controllerDir + '/conf/iobroker-dist.json". Possible iobroker.js-controller was not installed');
        }
    }

    // Enabling autostart is no longer necessary. The installers do that for us

    if (typeof callback === 'function') callback();
}

setup(processExit);
