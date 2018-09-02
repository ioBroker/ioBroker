// @ts-check
'use strict';

const fs = require('fs');
const path = require('path');
const tools = require('./tools.js');

const thisPackageRoot = path.join(__dirname, '../..');
const targetDir = path.join(thisPackageRoot, '../..');

// First copy files, then create a new package.json
copyFilesToRootDir();
createPackageJson();

/** Copies all necessary files in the target directory */
function copyFilesToRootDir() {
    function copyPredicate(filename) {
        // Don't copy any node_modules
        if (filename === 'node_modules') return false;
        // Don't copy files starting with .
        if (/^\./.test(filename)) return false;
        // Don't overwrite the package files
        if (/package(-lock)?\.json/.test(filename)) return false;
        return true;
    }
	
    // Enumerate all files in this module that are supposed to be in the root directory
    const filesToCopy = tools.enumFilesRecursiveSync(thisPackageRoot, copyPredicate);
    // Copy all of them to the corresponding target dir
    for (const file of filesToCopy) {
        // Find out where it's supposed to be
        const targetFileName = path.join(targetDir, path.relative(thisPackageRoot, file));
        // Ensure the directory exists
        tools.mkdirRecursiveSync(path.dirname(targetFileName));
        // And copy the file
        fs.copyFileSync(file, targetFileName);
    }
}

/** Creates a package.json with the desired contents in the root folder */
function createPackageJson() {
    const ownVersion = require('../../package.json').version;
    // This is the package.json contents that will be in the target directory
    const rootPackageJson = {
        'name': 'iobroker.inst',
        'version': ownVersion,
        'private': true,
        'description': 'Automation platform in node.js',
        'scripts': {
            'install': "echo 'inner install called'"
        },
        'dependencies': {
            '@types/node': '^10',
            'colors': '*',
            // Add necessary dependencies here
        }
    };
    // Write the package.json in the root dir
    fs.writeFileSync(
        path.join(targetDir, 'package.json'),
        JSON.stringify(rootPackageJson, null, 2),
        'utf8'
    );
}
