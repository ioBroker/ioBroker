// @ts-check
'use strict';

/*
 * This script checks the installed versions of NodeJS and npm
 * to make sure they are compatible with ioBroker.
 */

const { getSystemVersions } = require('./tools.js');
const semver = require('semver');

// DEFINE minimum versions here:
/** The minimum required Node.JS version - should be the current LTS */
const MIN_NODE_VERSION = '12.13.0';
/** The recommended npm version - should be the one bundled with MIN_NODE_VERSION */
const RECOMMENDED_NPM_VERSION = '6.12.0';
/** The minimum supported npm version - should probably be the same major version as RECOMMENDED_NPM_VERSION*/
const MIN_NPM_VERSION = '6.0.0';

const versions = getSystemVersions();

if (versions.node && semver.lt(versions.node, semver.coerce(MIN_NODE_VERSION))) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error(`ioBroker needs at least Node.JS ${MIN_NODE_VERSION}. You have installed ${versions.node}`);
    console.error('Please update your Node.JS version!');
    // TODO: Print manual how to update NodeJS
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(2);
}

if (versions.npm == null) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error('Aborting install because the npm version could not be checked!');
    console.error('Please check that npm is installed correctly.');
    console.error('Use "npm install -g npm" to install a supported version.');
    console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(3);
}

if (semver.lt(versions.npm, semver.coerce(MIN_NPM_VERSION))) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error(`You are using npm ${versions.npm}, but ioBroker needs at least using ${MIN_NPM_VERSION}.`);
    console.error('Please use "npm install -g npm" to install a supported version!');
    console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm.');
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(4);
}

if (semver.lt(versions.npm, semver.coerce(RECOMMENDED_NPM_VERSION))) {
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.warn(`You are using npm ${versions.npm}, but ioBroker recommends using ${RECOMMENDED_NPM_VERSION}.`);
    console.warn('Consider using "npm install -g npm" to install the newest version!');
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
}

// process.exit(0);
