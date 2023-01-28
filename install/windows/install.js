'use strict';

const Service = require('node-windows').Service;
const Shortcuts = require('./shortcuts')

// Get environment variables from file .env 
require('dotenv').config();

// Create the according Windows startmenu entries
Shortcuts.createStartMenu();

// Create a new service object
const svc = new Service({
    name: process.env.iobServiceName ? process.env.iobServiceName : 'ioBroker',
    description: 'ioBroker service.',
    script: require('path').join(__dirname, 'controller.js'),
    env: {
        name: 'NODE_ENV',
        value: 'production'
    }
});

// Listen for the "install" event, which indicates the
// process is available as a service.
svc.on('install', () => svc.start());

// Just in case this file is run twice.
svc.on('alreadyinstalled', () => console.log(`${svc.name} service is already installed.`));

// Listen for the "start" event and let us know when the
// process has actually started working.
svc.on('start', () => console.log(`${svc.name} started!\nVisit http://127.0.0.1:8081 to configure it.`));

// Install the script as a service.
svc.install();