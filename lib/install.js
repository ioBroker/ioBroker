#!/usr/bin/env node

'use strict';

const tools = require('./tools.js');
const platform = require('os').platform();
const colors = require('colors');
const child_process = require('child_process');
const path = require('path');

// Test if this script is being run as a result of `npm i`
const npmArgs = process.env.npm_config_argv && JSON.parse(process.env.npm_config_argv);
if (!npmArgs || (
    npmArgs.cooked.indexOf('install') === -1 && npmArgs.cooked.indexOf('i') === -1
)) {
    // This script is not run as part of an installation (e.g. rebuild), so don't install!
    console.log(colors.yellow('lib/install.js is not being run as part of an installation - skipping...'));
    process.exit(0);
}

if (!/^win/.test(platform) && !tools.isAutomatedInstallation()) {
    // On Linux/OSX this must be run with the installer script now!
    console.error();
    console.error(colors.yellow(`
╭─────────────────────────────────────────────────────────╮
│                                                         │
│ Manual installation of ioBroker is no longer supported  │
│ on Linux, OSX and FreeBSD!                              │
│ Please refer to the documentation on how to install it! │
│ https://github.com/ioBroker/ioBroker/wiki/Installation  │
│                                                         │
╰─────────────────────────────────────────────────────────╯
`));
    console.error();
    process.exit(100);
}

console.log(process.cwd());

if (tools.isThisInsideNodeModules()) {
    // This module is not supposed to be installed
    // inside node_modules but directly in the base directory
    // Therefore we copy the relevant files up 2 directories
    // and prompt the user to run npm install later
    require('./installCopyFiles.js');
    const thisPackageRoot = path.join(__dirname, '..');
    const targetDir = path.join(process.cwd(), '../..'); //path.join(thisPackageRoot, '../..');
    child_process.execSync('npm install --production', {
        cwd: targetDir,
        stdio: 'inherit'
    });
    if (!tools.isAutomatedInstallation()) {
        // Afterwards prompt the user to do the actual installation
        console.log(colors.green(`
╭─────────────────────────────────────────────────────────────────╮
│      The ioBroker files have been downloaded successfully.      │
│         To complete the installation, you need to run           │
│                                                                 │
│        npm i --production --loglevel error --unsafe-perm        │
│                                                                 │
╰─────────────────────────────────────────────────────────────────╯
`));
    }
// ^ This may look broken in the editor, but aligns nicely on console ^
} else {
    // We are located in the base directory. Continue with the normal installation
    require('./installSetup.js');
}
