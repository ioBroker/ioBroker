// @ts-check
'use strict';

/*
 * This script checks the installed versions of NodeJS and npm
 * to make sure they are compatible with ioBroker.
 */

const path = require('path');
const child_process = require('child_process');
const semver = require('semver');

// DEFINE minimum versions here:
/** The minimum required Node.JS version - should be the current LTS */
const MIN_NODE_VERSION = '12.13.0';
/** The recommended npm version - should be the one bundled with MIN_NODE_VERSION */
const RECOMMENDED_NPM_VERSION = '6.12.0';
/** The minimum supported npm version - should probably be the same major version as RECOMMENDED_NPM_VERSION*/
const MIN_NPM_VERSION = '6.0.0';

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

if (versions.node && semver.lt(versions.node, semver.coerce(MIN_NODE_VERSION))) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error(`ioBroker needs at least Node.JS ${MIN_NODE_VERSION}. You have installed ${versions.node}`);
    console.error('Please update your Node.JS version!');
    console.error('To Update to the latest Node.JS 12.x Release you can use ')
    console.error('"curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash - \
                     &&  sudo apt-get install -y nodejs"')
    console.error('More information is available at https://github.com/nodesource/distributions/')
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(2);
}

if (versions.npm == null) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error('Aborting install because the npm version could not be checked!');
    console.error('Please check that npm is installed correctly.');
    console.error(`Use "npm install -g npm@${RECOMMENDED_NPM_VERSION}" to install a supported version.`);
    console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(3);
}

if (semver.lt(versions.npm, semver.coerce(MIN_NPM_VERSION))) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error(`You are using npm ${versions.npm}, but ioBroker needs at least using ${MIN_NPM_VERSION}.`);
    console.error(`Please use "npm install -g npm@${RECOMMENDED_NPM_VERSION}" to install a supported version!`);
    console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(4);
}

if (semver.lt(versions.npm, semver.coerce(RECOMMENDED_NPM_VERSION))) {
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.warn(`You are using npm ${versions.npm}, but ioBroker recommends using ${RECOMMENDED_NPM_VERSION}.`);
    console.warn(`Consider using "npm install -g npm@${RECOMMENDED_NPM_VERSION}" to install the newest version!`);
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
}

process.exit(0);
