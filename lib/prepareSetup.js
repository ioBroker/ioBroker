'use strict';

const fs = require('fs');
const path = require('path');
const child_process = require('child_process');
const semver = require('semver');
const os = require('os');

function checkNpmVersion() {
    // Get npm version
    try {
        const nodeVersion = semver.valid(process.version);
        let npmVersion;
        try {
            // remove local node_modules\.bin dir from path
            // or we potentially get a wrong npm version
            const newEnv = Object.assign({}, process.env);
            newEnv.PATH = (newEnv.PATH || newEnv.Path || newEnv.path)
                .split(path.delimiter)
                .filter(dir => {
                    dir = dir.toLowerCase();
                    if (dir.indexOf('iobroker') > -1 && dir.indexOf(path.join('node_modules', '.bin')) > -1) return false;
                    return true;
                })
                .join(path.delimiter)
                ;

            npmVersion = child_process.execSync('npm -v', { encoding: 'utf8', env: newEnv });
            if (npmVersion) npmVersion = semver.valid(npmVersion.trim());
            console.log('NPM version: ' + npmVersion);
        } catch (e) {
            console.error('Error trying to check npm version: ' + e);
        }

        if (nodeVersion && semver.lt(nodeVersion, '4.0.0')) {
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            console.error('ioBroker needs at least nodejs 4.x. You have installed ' + nodeVersion);
            console.error('Please update your nodejs version!');
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            process.exit(2);
            return;
        }

        if (!npmVersion) {
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            console.error('Aborting install because the npm version could not be checked!');
            console.error('Please check that npm is installed correctly.');
            console.error('Use "npm install -g npm@4" or "npm install -g npm@latest" to install a supported version.');
            console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            process.exit(3);
            return;
        }

        if (semver.gte(npmVersion, '5.0.0') && semver.lt(npmVersion, '5.7.1')) {
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            console.error('NPM 5 is only supported starting with version 5.7.1!');
            console.error('Please use "npm install -g npm@4" to downgrade npm to 4.x or ');
            console.error('use "npm install -g npm@latest" to install a supported version of npm 5!');
            console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            process.exit(4);
            return;
        }
        return npmVersion;
    } catch (e) {
        console.error('Could not check npm version: ' + e);
        console.error('Assuming that correct version is installed.');
    }
}

if (semver.gte(checkNpmVersion(), '5.0.0')) {
    // disables NPM's package-lock.json on NPM >= 5 because that creates heaps of problems
    console.log('npm version >= 5: disabling package-lock');
    const rootDir = path.normalize(__dirname + '/../../../');
    fs.writeFileSync(rootDir + '.npmrc', 'package-lock=false' + os.EOL, 'utf8');
}
