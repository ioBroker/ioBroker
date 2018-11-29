'use strict';

const tools = require('./tools.js');
const colors = require('colors');

if (tools.isThisInsideNodeModules()) {
    // This module is not supposed to be installed 
    // inside node_modules but directly in the base directory
    // Therefore we copy the relevant files up 2 directories
    // and prompt the user to run npm install later
    require('./installCopyFiles.js');
    if (!tools.isAutomatedInstallation()) {
        // Afterwards prompt the user to do the actual installation
        console.log(colors.green(`
╭───────────────────────────────────────────────────────╮
│ The iobroker files have been downloaded successfully. │
│ To complete the installation, you need to run         │
│                                                       │
│           npm i --production --unsafe-perm            │
│                                                       │
╰───────────────────────────────────────────────────────╯
`));
    }
// ^ This may look broken in the editor, but aligns nicely on console ^
} else {
    // We are located in the base directory. Continue with the normal installation
    require('./installSetup.js');
}
