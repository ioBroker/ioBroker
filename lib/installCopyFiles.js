// @ts-check
'use strict';

const fs = require('fs');
const path = require('path');
const tools = require('./tools.js');

const thisPackageRoot = path.join(__dirname, '..');
const targetDir = path.join(thisPackageRoot, '../..');

console.log(`__dirname = ${__dirname}`);
console.log(`thisPackageRoot = ${thisPackageRoot}`);
console.log(`targetDir = ${targetDir}`);


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
    console.dir(filesToCopy);
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
    const ownPackage = require('../package.json');
    // This is the package.json contents that will be in the target directory
    const rootPackageJson = {
        'name': 'iobroker.inst',
        'version': ownPackage.version,
        'private': true,
        'description': 'Automation platform in node.js',
        'scripts': ownPackage.scripts,
        // Require the dependencies in our own package.json plus the following ones
        'dependencies': Object.assign({}, ownPackage.dependencies, {
            'iobroker.js-controller': 'stable',
            'iobroker.admin': 'stable',
            'iobroker.discovery': 'stable'
        })
    };
    // Write the package.json in the root dir
    fs.writeFileSync(
        path.join(targetDir, 'package.json'),
        JSON.stringify(rootPackageJson, null, 2),
        'utf8'
    );
}
