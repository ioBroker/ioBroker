// @ts-check
'use strict';

const path = require('node:path');
const child_process = require('node:child_process');
const fs = require('fs-extra');
const semver = require('semver');

/**
 * Recursively enumerates all files in the given directory
 * @param {string} dir The directory to scan
 * @param {(name: string) => boolean} [predicate] An optional predicate to apply to every found file system entry
 * @returns {string[]} A list of all files found
 */
function enumFilesRecursiveSync(dir, predicate) {
    const ret = [];
    if (typeof predicate !== 'function') {
        predicate = () => true;
    }
    // enumerate all files in this directory
    const filesOrDirs = fs.readdirSync(dir)
        .filter(predicate) // exclude all files starting with "."
        .map(f => path.join(dir, f)) // and prepend the full path
        ;
    for (const entry of filesOrDirs) {
        if (fs.statSync(entry).isDirectory()) {
            // Continue recursing this directory and remember the files there
            Array.prototype.push.apply(ret, enumFilesRecursiveSync(entry, predicate));
        } else {
            // remember this file
            ret.push(entry);
        }
    }
    return ret;
}

/**
 * Recursively copies all files from the source to the target directory
 * @param {string} sourceDir The directory to scan
 * @param {string} targetDir The directory to copy to
 * @param {(name: string) => boolean} [predicate] An optional predicate to apply to every found file system entry
 */
function copyFilesRecursiveSync(sourceDir, targetDir, predicate) {
    // Enumerate all files in this module that are supposed to be in the root directory
    const filesToCopy = enumFilesRecursiveSync(sourceDir, predicate);
    // Copy all of them to the corresponding target dir
    for (const file of filesToCopy) {
        // Find out where it's supposed to be
        const targetFileName = path.join(targetDir, path.relative(sourceDir, file));
        // Ensure the directory exists
        fs.ensureDirSync(path.dirname(targetFileName));
        // And copy the file
        fs.copySync(file, targetFileName);
    }
}

/** Checks if this installation process is automated */
function isAutomatedInstallation() {
    return !!process.env.AUTOMATED_INSTALLER;
}

/**
 * Retrieves the version of the globally installed npm and node
 * @returns {{npm: string, node: string}}
 */
function getSystemVersions() {
    // Run npm -v and extract the version string
    const ret = {
        npm: undefined,
        node: undefined,
    };
    try {
        let npmVersion;
        ret.node = semver.valid(process.version);
        try {
            // remove local node_modules\.bin dir from a path
            // or we potentially get a wrong npm version
            const newEnv = Object.assign({}, process.env);
            newEnv.PATH = (newEnv.PATH || newEnv.Path || newEnv.path)
                .split(path.delimiter)
                .filter(dir => {
                    dir = dir.toLowerCase();
                    return !dir.includes('iobroker') || !dir.includes(path.join('node_modules', '.bin'));
                })
                .join(path.delimiter);

            npmVersion = child_process.execSync('npm -v', { encoding: 'utf8', env: newEnv });
            if (npmVersion) npmVersion = semver.valid(npmVersion.trim());
            console.log(`NPM version: ${npmVersion}`);
            ret.npm = npmVersion;
        } catch (e) {
            console.error(`Error trying to check npm version: ${e.message}`);
        }
    } catch (e) {
        console.error(`Could not check npm version: ${e.message}`);
        console.error('Assuming that correct version is installed.');
    }
    return ret;
}

module.exports = {
    copyFilesRecursiveSync,
    isAutomatedInstallation,
    getSystemVersions,
};
