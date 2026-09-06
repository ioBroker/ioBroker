// @ts-check
'use strict';

/*
 * This script checks the installed versions of Node.js and npm
 * to make sure they are compatible with ioBroker.
 */

const { getSystemVersions } = require('./tools.js');
const semver = require('semver');

/*
 * The supported versions live in versions.json, which is also read by ioBroker.admin,
 * the repobuilder and the Windows installer. Do not hardcode them here.
 * The values below are only a fallback for the case that the file cannot be read.
 */
const FALLBACK_ACCEPTED_NODE_MAJORS = [20, 22, 24, 26];
const FALLBACK_RECOMMENDED_NPM_MAJOR = 10;
/** The minimum supported npm version. versions.json has no key for this. */
const MIN_NPM_VERSION = '8.0.0';
/*
 * Hard floor below which an installation cannot work at all. A Node.js version that is
 * merely missing from nodeJsAccepted is only warned about, so this is a separate concept
 * from the supported set and is deliberately not derived from versions.json.
 */
const MIN_NODE_VERSION = '16.20.0';

let supported;
try {
    supported = require('../versions.json');
} catch {
    supported = {};
}

const acceptedNodeMajors =
    Array.isArray(supported.nodeJsAccepted) && supported.nodeJsAccepted.length
        ? supported.nodeJsAccepted
        : FALLBACK_ACCEPTED_NODE_MAJORS;
const recommendedNpmMajor = supported.npmRecommended || FALLBACK_RECOMMENDED_NPM_MAJOR;

const versions = getSystemVersions();

if (versions.node && semver.lt(semver.coerce(versions.node), semver.coerce(MIN_NODE_VERSION))) {
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.error(`ioBroker needs at least Node.JS ${MIN_NODE_VERSION}. You have installed ${versions.node}`);
    console.error('Please update your Node.JS version!');
    // TODO: Print manual how to update NodeJS
    console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    process.exit(2);
}

// Not being on a supported major is not fatal: warn and let the installation continue.
if (versions.node && !acceptedNodeMajors.includes(semver.major(semver.coerce(versions.node)))) {
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.warn(`ioBroker supports Node.JS ${acceptedNodeMajors.join(', ')}. You have installed ${versions.node}`);
    console.warn('The installation continues, but this version is not supported and may cause problems.');
    console.warn('Please switch to a supported version, e.g. with "iob nodejs-update".');
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
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

if (semver.major(semver.coerce(versions.npm)) < recommendedNpmMajor) {
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    console.warn(`You are using npm ${versions.npm}, but ioBroker recommends npm ${recommendedNpmMajor} or newer.`);
    console.warn('Consider using "npm install -g npm" to install the newest version!');
    console.warn('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
}

// process.exit(0);
