'use strict';

// "iob docker" on Windows: shows whether Docker is installed and running.
// Status only - the Linux counterpart is docker.sh, which can also install Docker.

const { spawnSync } = require('node:child_process');

// Runs a command and returns its trimmed output, or null if it is missing or fails
function run(cmd, args, timeout) {
    const result = spawnSync(cmd, args, { encoding: 'utf8', timeout: timeout || 15000, windowsHide: true });
    if (result.error || result.status !== 0) {
        return null;
    }
    return (result.stdout || '').trim();
}

function usage() {
    console.log('Usage: iob docker [OPTIONS]');
    console.log('');
    console.log('Shows whether Docker is installed and running.');
    console.log('');
    console.log('Options:');
    console.log('  -h, --help   Show this help message');
    console.log('');
    console.log('Exit code: 0 if Docker is installed, 1 otherwise.');
}

// iob.bat passes all arguments, including "docker" itself
const args = process.argv.slice(2).filter(arg => arg !== 'docker' && arg !== '--allow-root');
if (args.includes('-h') || args.includes('--help')) {
    usage();
    process.exit(0);
}
const unknown = args.find(arg => arg !== '-y' && arg !== '--yes');
if (unknown) {
    console.error(`Unknown option: ${unknown}`);
    usage();
    process.exit(1);
}

const version = run('docker', ['--version']);

console.log('');
console.log('Docker status');
if (!version) {
    console.log('  Docker:          not installed');
    console.log('');
    console.log('Docker on Windows means Docker Desktop, which needs WSL2 (or Hyper-V) and administrator rights:');
    console.log('  winget install -e --id Docker.DockerDesktop');
    console.log('Docker Desktop is free for personal use, education and small businesses only, see https://www.docker.com/pricing/');
    process.exit(1);
}

console.log(`  Docker:          installed (${version})`);
// "docker info" needs the engine, so this also tells whether Docker Desktop is running
const serverVersion = run('docker', ['info', '--format', '{{.ServerVersion}}']);
console.log(`  Docker engine:   ${serverVersion ? `running (${serverVersion})` : 'not running'}`);
const composeVersion = run('docker', ['compose', 'version', '--short']);
console.log(`  Docker Compose:  ${composeVersion || 'not installed'}`);
console.log('');

if (!serverVersion) {
    console.log('Start Docker Desktop. Its engine only runs while a user is logged on, so after a reboot');
    console.log('it is not available to the ioBroker service until someone logs on.');
}
process.exit(0);
