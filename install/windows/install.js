'use strict';

const fs = require('fs-extra');
const Shortcuts = require('./shortcuts');
const execSync = require('node:child_process').execSync;
const join = require('node:path').join;

// Get environment variables from file .env
require('dotenv').config();

// Create the according Windows start menu entries
Shortcuts.createStartMenu();

const serviceName = process.env.iobServiceName ? process.env.iobServiceName : 'ioBroker';
const daemonDir = join(__dirname, 'daemon');
const serviceXml = `${serviceName.toLowerCase()}.xml`
const serviceExe = `${serviceName.toLowerCase()}.exe`
const serviceXMLPath = join(daemonDir, serviceXml);
const serviceEXEPath = join(daemonDir, serviceExe);
const controllerPath = join(__dirname, 'controller.js');

const startTimeout = 2000;
const installTimeout = 2000;
let creationTimeout = 500;

// Check if the service exists
if (fs.existsSync(serviceEXEPath) && fs.existsSync(serviceXMLPath)) {
	try {
		const cmd = `sc query state= all | find "${serviceExe}"`;
		console.debug(`Executing "${cmd}"`);
		const serviceStatus = execSync(cmd);
		console.log(`Windows service already exists: ${serviceStatus.toString()} Service will be removed and recreated.`);
		creationTimeout = 10000;

		try {
			const cmd = `sc stop ${serviceExe}`;
			console.debug(`Executing "${cmd}"`);
			const stopResult = execSync(cmd);
			console.log(stopResult.toString());
		}
		catch (e){
			console.log('Stopping Windows service failed!')
			console.log(e.toString());
		}

		try {
			const cmd = `sc delete ${serviceExe}`;
			console.debug(`Executing "${cmd}"`);
			const deleteResult = execSync(cmd);
			console.log(deleteResult.toString());
		}
		catch (e){
			console.error('Deleting Windows service failed!')
			console.warn(e.toString());
		}
	}
	catch {
		// Service not existing, OK
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
			console.error(`Error when copying service executable: ${err}`);
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

	try {
		console.debug(`Writing file ${serviceXMLPath}`);
		fs.writeFileSync(serviceXMLPath, configFile);
	}
	catch (e){
		console.error('Creation of configuration file failed!')
		console.warn(e.toString());
	}

	setTimeout(() => {
		// Install the service:
		try {
			const cmd = `${serviceEXEPath} install`;
			console.debug(`Executing "${cmd}"`);
			const installResult = execSync(cmd, () => { });
			console.log(installResult.toString());
		}
		catch (e){
			console.error('Creation of Windows service failed!')
			console.warn(e.toString());
		}

		setTimeout(() => {
			// Start the service
			try {
				const cmd = `${serviceEXEPath} start`;
				console.debug(`Executing "${cmd}"`);
				const startResult = execSync(cmd, () => { });
				console.log(startResult.toString());
			}
			catch (e){
				console.error('Starting Windows service failed!')
				console.warn(e.toString());
			}
		}, startTimeout);
	}, installTimeout);
}, creationTimeout);
