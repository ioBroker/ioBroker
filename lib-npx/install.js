#!/usr/bin/env node

'use strict';

const tools = require('./tools.js');
const platform = require('os').platform();
const child_process = require('child_process');

function runLinux(isFix) {
    return new Promise((resolve, reject) => {
        // Install iobroker
        const cmd = `curl -sL https://iobroker.net/${isFix ? 'fix.sh' : 'install.sh'} | bash -`;

        // System call used for update of js-controller itself,
        // because during installation npm packet will be deleted too, but some files must be loaded even during the installation process.
        const exec = require('child_process').exec;
        const child = exec(cmd);

        child.stderr.pipe(process.stderr);
        child.stdout.pipe(process.stdout);

        child.on('exit', code => {
            // code 1 is strange error that cannot be explained. Everything is installed but error :(
            if (code && code !== 1) {
                reject(new Error('Cannot install: ' + code));
            } else {
                // command succeeded
                resolve();
            }
        });
    });
}

if (!/^win/.test(platform) && !tools.isAutomatedInstallation()) {
    // On Linux/OSX this must be run with the installer script now!
    const pack = require('../package.json');
    if (pack.name.includes('fix')) {
        runLinux(true)
            .then(() => {});
    } else {
        runLinux()
            .then(() => {});
    }

} else {
    require('./checkVersions.js');

    require('./installCopyFiles.js');
    const targetDir = process.cwd();
    child_process.execSync('npm install --production', {
        cwd: targetDir,
        stdio: 'inherit'
    });
    require('./installSetup.js');
}

