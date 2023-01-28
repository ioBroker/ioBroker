'use strict';

const Service = require('node-windows').Service;
const Shortcuts = require('./shortcuts');

// Get environment variables from file .env 
require('dotenv').config();

// Remove the according Windows startmenu entries
Shortcuts.removeStartMenu();

// Create a new service object
const svc = new Service({
    name: process.env.iobServiceName ? process.env.iobServiceName : 'ioBroker',
    script: require('path').join(__dirname, 'controller.js')
});

// Listen for the "uninstall" event, so we know when it's done.
svc.on('uninstall', () => {
    console.log('Uninstall complete.');
    console.log('The service exists: ', svc.exists);
});

// Uninstall the service.
svc.uninstall();