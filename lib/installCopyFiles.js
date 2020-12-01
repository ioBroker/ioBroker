// @ts-check
'use strict';

// fs doesn't have sync copy prior to node 8.5
const fs = require('fs-extra');
const path = require('path');
const tools = require('./tools.js');

const thisPackageRoot = path.join(__dirname, '..');
const targetDir = path.join(thisPackageRoot, '../..');
const noCopyDirs = ['doc', 'img', 'node_modules', 'test', 'wiki'];

// First copy files, then create a new package.json
copyFilesToRootDir();
createPackageJson();

/** Copies all necessary files in the target directory */
function copyFilesToRootDir() {
    function copyPredicate(filename) {
        // Don't copy any of these folders:
        if (noCopyDirs.indexOf(filename) > -1) return false;
        // Don't copy files starting with .
        if (/^\./.test(filename)) return false;
        // Don't overwrite the package files
        if (/package(-lock)?\.json/.test(filename)) return false;
        return true;
    }

    tools.copyFilesRecursiveSync(thisPackageRoot, targetDir, copyPredicate);
}

/** Creates a package.json with the desired contents in the root folder */
function createPackageJson() {
    const ownPackage = require('../package.json');
    // This is the package.json contents that will be in the target directory
    const rootPackageJson = {
        'name': 'iobroker.inst',
        'version': ownPackage.version,
        'private': true,
        'description': 'Automation platform in node.js',
        // Copy scripts and required engine from our own package.json
        'scripts': ownPackage.scripts,
        'engine': ownPackage.engine,
        // Require the dependencies in our own package.json plus the following ones
        'dependencies': Object.assign({}, ownPackage.dependencies, {
            'iobroker.js-controller': 'stable',
            'iobroker.admin': 'stable',
            'iobroker.discovery': 'stable',
            'iobroker.info': 'stable'
        })
    };
    // Write the package.json in the root dir
    fs.writeFileSync(
        path.join(targetDir, 'package.json'),
        JSON.stringify(rootPackageJson, null, 2),
        'utf8'
    );
}
