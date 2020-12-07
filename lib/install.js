'use strict';

// If this script is run in a context where ioBroker itself shouldn't be installed,
// then skip this script
if (!!process.env.SKIP_POSTINSTALL) {
    process.exit(0);
}

const tools = require('./tools.js');
const platform = require('os').platform();
const colors = require('colors');

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

if (tools.isThisInsideNodeModules()) {
    // This module is not supposed to be installed 
    // inside node_modules but directly in the base directory
    // Therefore we copy the relevant files up 2 directories
    // and prompt the user to run npm install later
    require('./installCopyFiles.js');
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
