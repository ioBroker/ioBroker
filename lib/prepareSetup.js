'use strict';

var fs = require('fs');
var path = require('path');
var child_process = require('child_process');
var semver = require('semver');
var os = require('os');

function checkNpmVersion() {
    // Get npm version
    try {
        var nodeVersion = semver.valid(process.version);
        var npmVersion;
        try {
            npmVersion = child_process.execSync('npm -v', { encoding: "utf8" });
            if (npmVersion) npmVersion = semver.valid(npmVersion.trim());
            console.log('NPM version: ' + npmVersion);
        } catch (e) {
            console.error('Error trying to check npm version: ' + errResp);
        }

        if (nodeVersion && semver.lt(nodeVersion, "4.0.0")) {
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
            console.error('Use "npm install -g npm@4" or "npm install -g npm@>=5.7.1" to install a supported version.');
            console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm');
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            process.exit(3);
            return;
        }

        if (semver.gte(npmVersion, "5.0.0") && semver.lt(npmVersion, "5.7.1")) {
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            console.error('NPM 5 is only supported starting with version 5.7.1!');
            console.error('Please use "npm install -g npm@4" to downgrade npm to 4.x or ');
            console.error('use "npm install -g npm@>=5.7.1" to install a supported version of npm 5!')
            console.error('You need to make sure to downgrade again with the above command after you');
            console.error('You need to make sure to repeat this step after installing an update to NodeJS and/or npm');
            console.error('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            process.exit(4);
            return;
        }
        return npmVersion;
    }
    catch (e) {
        console.error('Could not check npm version: ' + e);
        console.error('Assuming that correct version is installed.');
    }
}

if (semver.gte(checkNpmVersion(), "5.0.0")) {
    // disables NPM's package-lock.json on NPM >= 5 because that creates heaps of problems
    console.log("npm version >= 5: disabling package-lock")
    var rootDir = path.normalize(__dirname + '/../../../');
    fs.writeFileSync(rootDir + '.npmrc', 'package-lock=false' + os.EOL, "utf8");
}
