#!/usr/bin/env node

'use strict';

const tools = require('./tools.js');
const platform = require('os').platform();
const colors = require('colors');
const child_process = require('child_process');

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

require('./checkVersions.js');

require('./installCopyFiles.js');
const targetDir = process.cwd();
child_process.execSync('npm install --production', {
    cwd: targetDir,
    stdio: 'inherit'
});
require('./installSetup.js');
