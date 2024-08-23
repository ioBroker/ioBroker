'use strict';

const ws = require('windows-shortcuts');
const fs = require('node:fs');
const path = require('node:path');

// Get environment variables from file .env
require('dotenv').config();

//
// Get the name of a start menu entry
//
function getFullLinkFileName(menuDir, linkFileName, serviceName) {
    return path.join(menuDir, serviceName ? `[${serviceName}] ${linkFileName}` : linkFileName);
}

//
// Create one start menu entry and the according folder if not already created
//
function createStartMenuEntry(menuDir, linkFileName, serviceName, target, workingDir, args, desc, iconFileName, admin) {

    if (!fs.existsSync(menuDir)) {
        try {
            fs.mkdirSync(menuDir);
            console.log(`Start menu folder ${sMenuDir} created!`);
        }
        catch (err) {
            console.error(`Error occurred when creating a start menu folder ${sMenuDir}!`);
            console.error(err);
        }
    }

    const fullLinkFileName = getFullLinkFileName(menuDir, linkFileName, serviceName);

    ws.create(fullLinkFileName, {
        target: target,
        runStyle: 1,
        workingDir: workingDir,
        args: args,
        desc: desc,
        icon: iconFileName
    }, function (err) {
        if (err) {
            console.error(`Error occurred when creating shortcut ${fullLinkFileName}`);
            console.error(err);
        }
        else {
            if (admin) {
                fs.readFile(fullLinkFileName, function (err, data) {
                    if (err) {
                        console.error(`Shortcut "${fullLinkFileName}" could not be opened to set Admin flag!`);
                        console.error(err);
                    }
                    else {
                        try {
                            data[0x15] |= 0x20;
                            fs.writeFileSync(fullLinkFileName, data);
                            console.log(`Shortcut "${fullLinkFileName}" created with Admin flag!`);
                        }
                        catch (err) {
                            console.error(`Shortcut "${fullLinkFileName}" could not be written to set Admin flag!`);
                            console.error(err);
                        }
                    }
                });
            }
            else {
                console.log(`Shortcut "${fullLinkFileName}" created!`);
            }
        };
    });
}

//
// Remove one start menu entry
//
async function removeStartMenuEntry(menuDir, linkFileName, serviceName) {
    const fullLinkFileName = getFullLinkFileName(menuDir, linkFileName, serviceName);
    try {
        fs.rmSync(fullLinkFileName);
        console.log(`Shortcut "${fullLinkFileName}" removed!`);
    }
    catch (err) {
        if (err.code === 'ENOENT') {
            console.log(`Shortcut "${fullLinkFileName}" not removed, because it was not found!`);
        }
        else {
            console.error(`Error occurred when removing shortcut ${fullLinkFileName}`);
            console.error(err);
        }
    }
}

const iobServiceName = process.env.iobServiceName;
const sMenuDir = `${process.env.ALLUSERSPROFILE}\\Microsoft\\Windows\\Start Menu\\Programs\\ioBroker automation platform`;
const nodeVarsBat = path.join(path.dirname(process.execPath), 'nodevars.bat');
const ioNodeVarsBat = path.join(`${process.cwd()}`, 'iobnodevars.bat');
const linkCmdLine = 'ioBroker Command line.lnk';
const linkAdmin = 'ioBroker Admin.lnk';
const linkStartService = 'Start ioBroker Service.lnk';
const linkStopService = 'Stop ioBroker Service.lnk';
const linkRestartService = 'Restart ioBroker Service.lnk';
const iconPath = path.join(process.cwd(), '\\node_modules\\iobroker.admin\\adminWww\\favicon.ico');
const servicePath = path.join(process.cwd(), 'serviceiobroker.bat');

//
// Create all start menu entries and the start menu folder
//
function createStartMenu() {
    const content = '@echo off\n' +
        'echo.\n' +
        'echo **********************************************************\n' +
        'echo ***               Welcome to ioBroker.                 ***\n' +
        'echo ***                                                    ***\n' +
        'echo ***     Type \'iob help\' for list of instructions.      ***\n' +
        'echo ***                For more help see                   ***\n' +
        'echo ***     https://github.com/ioBroker/ioBroker.docs      ***\n' +
        'echo **********************************************************\n' +
        'echo.\n' +
        `call "${nodeVarsBat}"\n` +
        `cd ${process.cwd()}\n` +
        `${path.parse(process.cwd()).root.replace(/\\/g, '')}\n`;

    try {
        fs.writeFileSync(ioNodeVarsBat, content);
        console.log('Written iobnodevars.bat successfully.');
    } catch (err) {
        console.error(`Error occurred when creating file ${nodeVarsBat}`);
        console.error(err);
    }

    createStartMenuEntry(
        sMenuDir,                    // Directory in the start menu
        linkCmdLine,                 // Shortcut filename
        iobServiceName,              // Servicename, empty string for standard name iobroker
        process.env.ComSpec,         // target, in this case cmd.exe
        process.cwd(),               // ioBroker root directory
        `/k "${ioNodeVarsBat}"`,// parameter of shortcut, in this case, path to nodevars.bat
        'ioBroker Command line.',    // description
        iconPath,
        true
    );

    createStartMenuEntry(
        sMenuDir,                             // Directory in the start menu
        linkAdmin,                            // Shortcut filename
        iobServiceName,                       // Servicename, empty string for standard name iobroker
        'http://127.0.0.1:8081',              // target
        process.cwd(),                        // ioBroker root directory
        '',                                   // parameter of shortcut
        'Open ioBroker Admin in Web Browser.',// description
        iconPath,
        false
    );

    createStartMenuEntry(
        sMenuDir,                    // Directory in the start menu
        linkStartService,            // Shortcut filename
        iobServiceName,              // Servicename, empty string for standard name iobroker
        servicePath,  // target
        process.cwd(),               // ioBroker root directory
        'start',                     // parameter of shortcut
        'Start ioBroker service.',   // description
        '',
        true
    );

    createStartMenuEntry(
        sMenuDir,                    // Directory in the start menu
        linkStopService,             // Shortcut filename
        iobServiceName,              // Servicename, empty string for standard name iobroker
        servicePath, // target
        process.cwd(),               // ioBroker root directory
        'stop',                      // parameter of shortcut
        'Stop ioBroker service.',    // description
        '',
        true
    );

    createStartMenuEntry(
        sMenuDir,                      // Directory in the start menu
        linkRestartService,            // Shortcut filename
        iobServiceName,                // Servicename, empty string for standard name iobroker
        servicePath,                   // target
        process.cwd(),                 // ioBroker root directory
        'restart',                     // parameter of shortcut
        'Restart ioBroker service.',   // description
        '',
        true
    );
}

//
// Remove all start menu entries and the start menu folder
//
async function removeStartMenu() {
    await removeStartMenuEntry(sMenuDir, linkAdmin, iobServiceName);
    await removeStartMenuEntry(sMenuDir, linkCmdLine, iobServiceName);
    await removeStartMenuEntry(sMenuDir, linkStartService, iobServiceName);
    await removeStartMenuEntry(sMenuDir, linkStopService, iobServiceName);
    await removeStartMenuEntry(sMenuDir, linkRestartService, iobServiceName);
    try {
        fs.rmdirSync(sMenuDir);
        console.log(`Start menu folder ${sMenuDir} removed!`);
    }
    catch (err) {
        if (err.code === 'ENOTEMPTY') {
            console.log(`Start menu folder ${sMenuDir} not removed because it is not empty!`);
        }
        else {
            console.error(`Error occurred when removing the start menu folder ${sMenuDir}!`);
            console.error(err);
        }
    }
}

module.exports = { createStartMenu, removeStartMenu };
