# ioBroker Commands and Parameters Reference

This document provides a comprehensive reference for all ioBroker commands and their available parameters.

## Table of Contents

- [Installation Commands](#installation-commands)
- [Diagnostic Commands](#diagnostic-commands)
- [Maintenance Commands](#maintenance-commands)
- [Service Control Commands](#service-control-commands)
- [Node.js Management Commands](#nodejs-management-commands)

## Installation Commands

### NPX Installation (Cross-platform)

#### Linux/macOS Installation
```bash
npx @iobroker/install
```

#### Windows Installation
```bash
mkdir C:\iobroker && cd C:\iobroker && npx @iobroker/install
```

**Parameters:** None - behavior is automatic based on detected platform.

### Linux/macOS Shell Installation

#### Direct Installation
```bash
curl -sL https://iobroker.net/install.sh | bash -
```

#### Manual Installation Script
```bash
./installer.sh [OPTIONS]
```

**Available Parameters:**
- `--silent` - Skip all user prompts and run automated installation
- No other direct command-line parameters supported

**Notes:**
- The installer creates an `iob` command with additional parameters (see [Service Control Commands](#service-control-commands))
- Root user detection is automatic with warnings and recommendations

## Diagnostic Commands

### iob diag

```bash
iob diag [OPTIONS]
```

**Available Parameters:**
- `--de` - Output (partially) in German language
- `--unmask` - Show otherwise masked output for complete diagnosis
- `-s, --short` - Show summary only (English)
- `-k, --kurz` - Show summary only (German)
- `--summary` - Show summary only (English)
- `--zusammenfassung` - Show summary only (German)
- `-h, --help` - Display help and exit
- `--hilfe` - Display help and exit (German)
- `--allow-root` - Allow running as root user (not recommended)

**Examples:**
```bash
# Run full diagnostic
iob diag

# Run diagnostic with German output
iob diag --de

# Show summary only
iob diag --short

# Show complete unmasked output
iob diag --unmask

# Show help
iob diag --help
```

### Direct Diagnostic Script

```bash
./diag.sh [OPTIONS]
```

Uses the same parameters as `iob diag` above.

## Maintenance Commands

### iob fix

```bash
iob fix [OPTIONS]
```

**Available Parameters:**
- `--allow-root` - Allow running as root user (not recommended, but sometimes necessary for repairs)

**Examples:**
```bash
# Run standard fix
iob fix

# Run fix as root (when necessary)
iob fix --allow-root
```

### Direct Fix Script

```bash
./fix_installation.sh [OPTIONS]
```

Uses the same parameters as `iob fix` above.

**What iob fix does:**
- Compresses JSONL databases if needed
- Fixes file permissions and ownership
- Creates default user setup if running as root
- Repairs common installation issues
- Updates boot target settings
- Fixes timezone configuration

## Service Control Commands

### iob service management

The `iob` command supports various service control operations depending on your system's init system (systemd, init.d, or launchctl on macOS).

```bash
iob [COMMAND] [OPTIONS]
```

**Available Commands:**
- `start` - Start the ioBroker service
- `stop` - Stop the ioBroker service  
- `restart` - Restart the ioBroker service
- `fix` - Run the fix/repair script
- `nodejs-update` - Run Node.js update script
- `diag` - Run diagnostic script

**Global Options:**
- `--allow-root` - Allow running commands as root (applies to fix, nodejs-update, diag)

**Examples:**
```bash
# Service control
iob start
iob stop
iob restart

# Maintenance commands
iob fix
iob nodejs-update
iob diag

# With root permission (when needed)
iob fix --allow-root
iob diag --allow-root
```

**Notes:**
- On systemd systems, `start`/`stop`/`restart` commands are redirected to `systemctl`
- On macOS with launchctl, commands use `launchctl load/unload`
- On init.d systems, commands control the service directly
- All other commands are passed through to the iobroker.js controller

## Node.js Management Commands

### iob nodejs-update

```bash
iob nodejs-update [VERSION]
```

**Parameters:**
- `VERSION` - Major Node.js version number (18, 20, 22, etc.)
  - If not specified, installs the recommended version (currently 22)
  - Must be 18 or higher
  - Only major version numbers are accepted

**Examples:**
```bash
# Install recommended Node.js version
iob nodejs-update

# Install specific major version
iob nodejs-update 20
iob nodejs-update 22
```

### Direct Node Update Script

```bash
./node-update.sh [VERSION]
```

Uses the same parameters as `iob nodejs-update` above.

**What node-update does:**
- Updates Node.js to specified or recommended version
- Only works on Debian-based Linux distributions
- Removes old Node.js versions and installs from NodeSource repository
- Fixes PATH issues with incorrect Node.js installations
- Not supported in Docker containers or WSL

**System Requirements:**
- Debian-based Linux distribution (Ubuntu, Debian, etc.)
- Not running as root
- Not in Docker container
- Not in WSL environment
- apt-get package manager available

## Common Parameters Across Commands

### --allow-root
This parameter is available for most maintenance commands (`fix`, `diag`, `nodejs-update`) and allows running the command as the root user. 

**Important Notes:**
- Running as root is NOT recommended for security reasons
- Only use when absolutely necessary for system repairs
- The installer will warn you and recommend creating a proper user setup
- Future versions may disable this option entirely

### Language Options
The diagnostic script supports localization:
- `--de` - German language output (partial)
- Default behavior uses English

### Output Control
The diagnostic script supports different output levels:
- Default: Full diagnostic output
- `--short` / `--summary`: Summary only
- `--unmask`: Show complete unmasked output (reveals sensitive information)

## Installation-Specific Parameters

### Windows Installation
When using the NPX installer on Windows:
- Only x64 systems are supported
- Installation automatically detects Windows and runs Windows-specific setup
- No additional command-line parameters required

### Linux/macOS Installation  
When using the shell installer:
- `--silent` skips all user prompts
- Automatic platform detection
- Creates system user and service setup

## Environment Variables

Some installation behavior can be controlled via environment variables:

### IOB_FORCE_INITD
```bash
export IOB_FORCE_INITD=true
./installer.sh
```
Forces the installer to use init.d instead of systemd, even if systemd is available.

### AUTOMATED_INSTALLER
This is automatically set by the installer to indicate an automated installation is in progress. Not intended for manual use.

## Security Considerations

- **Never run as root** unless absolutely necessary for repairs
- Use `--allow-root` only when required and understand the security implications
- The `--unmask` parameter in diagnostics may reveal sensitive system information
- Always run the installer as a regular user when possible

## Getting Help

For any command, you can typically get help using:
```bash
iob diag --help
./diag.sh --help
```

For general ioBroker help:
- [ioBroker Documentation](https://www.iobroker.net/#en/documentation)
- [Community Forum](https://forum.iobroker.net)
- [GitHub Issues](https://github.com/ioBroker/ioBroker/issues)