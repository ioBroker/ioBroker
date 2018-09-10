// @ts-check
'use strict';

/*
 * This script checks the installed versions of NodeJS and npm
 * to make sure they are compatible with ioBroker.
 */

const path = require('path');
const child_process = require('child_process');
const semver = require('semver');

/**
 * Retrieves the version of the globally installed npm and node
 * @returns {{npm: string, node: string}}
 */
function getSystemVersions() {
    // Run npm -v and extract the version string
    const ret = {
        npm: undefined,
        node: undefined
    };
    try {
        let npmVersion;
        ret.node = semver.valid(process.version);
        try {
            // remove local node_modules\.bin dir from path
            // or we potentially get a wrong npm version
            const newEnv = Object.assign({}, process.env);
            newEnv.PATH = (newEnv.PATH || newEnv.Path || newEnv.path)
                .split(path.delimiter)
                .filter(dir => {
                    dir = dir.toLowerCase();
                    return !(dir.indexOf('iobroker') > -1 && dir.indexOf(path.join('node_modules', '.bin')) > -1);
                })
                .join(path.delimiter);

            npmVersion = child_process.execSync('npm -v', { encoding: 'utf8', env: newEnv });
            if (npmVersion) npmVersion = semver.valid(npmVersion.trim());
            console.log('NPM version: ' + npmVersion);
            ret.npm = npmVersion;
        } catch (e) {
            console.error('Error trying to check npm version: ' + e);
        }
    } catch (e) {
        console.error('Could not check npm version: ' + e);
        console.error('Assuming that correct version is installed.');
    }
    return ret;
}

const versions = getSystemVersions();

if (versions.node && semver.lt(versions.node, '6.0.0')) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error('ioBroker needs at least nodejs 6.x. You have installed ' + versions.node);
    console.error('Please update your nodejs version!');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(2);
}

if (versions.npm == null) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error('Aborting install because the npm version could not be checked!');
    console.error('Please check that npm is installed correctly.');
    console.error('Use "npm install -g npm@4" or "npm install -g npm@latest" to install a supported version.');
    console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(3);
}

if (semver.gte(versions.npm, '5.0.0') && semver.lt(versions.npm, '5.7.1')) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error('NPM 5 is only supported starting with version 5.7.1!');
    console.error('Please use "npm install -g npm@4" to downgrade npm to 4.x or ');
    console.error('use "npm install -g npm@latest" to install a supported version of npm 5!');
    console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(4);
}

process.exit(0);
