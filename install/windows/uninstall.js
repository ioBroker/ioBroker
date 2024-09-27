'use strict';

const execSync = require('node:child_process').execSync;
const join = require('node:path').join;
const fs = require('node:fs');
const Shortcuts = require('./shortcuts');

// Get environment variables from file .env
require('dotenv').config();

// Remove the according Windows start menu entries
Shortcuts.removeStartMenu();

const serviceName = process.env.iobServiceName ? process.env.iobServiceName : 'ioBroker';
const daemonDir = join(__dirname, 'daemon');
const serviceXml = `${serviceName.toLowerCase()}.xml`
const serviceExe = `${serviceName.toLowerCase()}.exe`
const serviceErrLog = `${serviceName.toLowerCase()}.err.log`
const serviceOutLog = `${serviceName.toLowerCase()}.out.log`
const serviceWrapperLog = `${serviceName.toLowerCase()}.wrapper.log`
const serviceConfig = `${serviceExe}.config`
const serviceEXEPath = join(daemonDir, serviceExe);

// Stop the service:
try {
    const installResult = execSync(`${serviceEXEPath} stop`);
    console.log(installResult.toString());
} catch {
    console.error('Stopping Windows service failed!')
}

// Delete the service:
try {
    const installResult = execSync(`${serviceEXEPath} uninstall`);
    console.log(installResult.toString());

    // Remove files
    unlinkFile(join(daemonDir, serviceXml));
    unlinkFile(join(daemonDir, serviceErrLog));
    unlinkFile(join(daemonDir, serviceOutLog));
    unlinkFile(join(daemonDir, serviceWrapperLog));
    unlinkFile(join(daemonDir, serviceConfig));
    unlinkFile(serviceEXEPath);
    try {
        if (fs.existsSync(daemonDir)) {
            fs.rmdirSync(daemonDir);
            console.log(`Directory ${daemonDir} deleted.`);
        }
    } catch {
        console.warn(`Deletion of directory ${daemonDir} failed.`);
    }
} catch {
    console.error('Deletion of Windows service failed!');
}

function unlinkFile(fileName) {
    try {
        if (fs.existsSync(fileName)) {
            fs.unlinkSync(fileName);
            console.log(`${fileName} deleted.`);
        }
    } catch {
        console.warn(`Deletion of file ${fileName} failed.`);
    }
}
