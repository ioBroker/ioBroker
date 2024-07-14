'use strict';

const Service = require('node-windows').Service;
const fs = require('fs-extra');
const path = require('path');
const Shortcuts = require('./shortcuts');
const execSync = require('child_process').execSync;
const join = require('path').join;

// Get environment variables from file .env
require('dotenv').config();

// Create the according Windows startmenu entries
Shortcuts.createStartMenu();

const serviceName = process.env.iobServiceName ? process.env.iobServiceName : 'ioBroker';
const daemonDir = join(__dirname, 'daemon');
const serviceXml = `${serviceName.toLowerCase()}.xml`
const serviceExe = `${serviceName.toLowerCase()}.exe`
const serviceXMLPath = join(daemonDir, serviceXml);
const serviceEXEPath = join(daemonDir, serviceExe);
const controllerPath = join(__dirname, 'controller.js');

let serviceTimeout = 500;

// Check if service exists
if (fs.existsSync(serviceEXEPath) && fs.existsSync(serviceXMLPath)) {
	try {
		console.log(`sc query state= all | find "${serviceExe}"`);
		const serviceStatus = execSync(`sc query state= all | find "${serviceExe}"`);
		console.log(`Windows service already exists: ${serviceStatus.toString()} Service will be removed and recreated.`);
		serviceTimeout = 10000;

		try {
			const startResult = execSync(`sc stop ${serviceExe}`, () => { });
			console.log(startResult.toString());
		}
		catch {
			console.error('Stopping Windows service failed!')
		}

		try {
			const startResult = execSync(`sc delete ${serviceExe}`, () => { });
			console.log(startResult.toString());
		}
		catch {
			console.error('Deleting Windows service failed!')
		}
	}
	catch {
		// Service not existing, OK
		console.log('!!!!!');
	}
}

setTimeout(() => {
	// Create Service directory
	if (!fs.existsSync(daemonDir)) {
		fs.mkdirSync(daemonDir);
	}

	// Copy service executable
	fs.copyFile('install\\windows\\WinSW3.exe', serviceEXEPath, (err) => {
		if (err) {
			console.error('Error when copying service executable: ' + err);
		}
	});

	const configFile = `<service>
	<id>${serviceExe}</id>
	<name>${serviceName}</name>
	<description>ioBroker service ${serviceName}</description>
	<executable>${process.execPath}</executable>
	<arguments>${controllerPath}</arguments>
	<logmode>rotate</logmode>
	<stoptimeout>30sec</stoptimeout>
	<env name="NODE_ENV" value="production"/>
	<workingdirectory>${__dirname}</workingdirectory>
</service>`;

	fs.writeFileSync(serviceXMLPath, configFile);

	// Install the service:
	try {
		const installResult = execSync(`${serviceEXEPath} install`, () => { });
		console.log(installResult.toString());
	}
	catch {
		console.error('Creation of Windows service failed!')
	}

	// Start the service
	try {
		const startResult = execSync(`${serviceEXEPath} start`, () => { });
		console.log(startResult.toString());
	}
	catch {
		console.error('Starting Windows service failed!')
	}
}, serviceTimeout);
