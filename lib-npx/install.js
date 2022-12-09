#!/usr/bin/env node

'use strict';

const tools = require('./tools.js');
const path = require('path');
const platform = require('os').platform();
const { execSync, exec }  = require('child_process');
const pack = require('../package.json');
const semver = require('semver');

function runLinux(isFix) {
    console.log(`Linux installation starting... (fixing = ${isFix})`);
    return new Promise((resolve, reject) => {
        // Install iobroker
        const cmd = `curl -sL https://iobroker.net/${isFix ? 'fix.sh' : 'install.sh'} | bash -`;

        // System call used for update of js-controller itself,
        // because during installation npm packet will be deleted too, but some files must be loaded even during the installation process.
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
    if (pack.name.includes('fix')) {
        runLinux(true)
            .then(() => {});
    } else {
        runLinux()
            .then(() => {});
    }

} else {
    console.log(`Windows installation starting... (fixing = ${pack.name.includes('fix')})`);

    require('./checkVersions.js');

    require('./installCopyFiles.js');

    // We only do the basic install when we install, not on fix
    if (!pack.name.includes('fix')) {
        const targetDir = process.cwd();
        execSync('npm install --production', {
            cwd: targetDir,
            stdio: 'inherit'
        });
    }
    require('./installSetup.js');

    // fix command for windows
    if (pack.name.includes('fix')) {
        const iobrokerDir = path.join(process.cwd(), 'iobroker-data');
        const versions = tools.getSystemVersions();
        if (versions && versions.npm) {
            if (semver.lt(versions.npm, '7.0.0')) {
                execSync('npx @iobroker/jsonltool@latest', {
                    cwd: iobrokerDir,
                    stdio: 'inherit'
                });
            } else {
                execSync('npm x --yes @iobroker/jsonltool@latest', {
                    cwd: iobrokerDir,
                    stdio: 'inherit'
                });
            }
        }
    }
}
