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

**Parameters:** None - behavior is automatic based on the detected platform.

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
- `--silent` - Skip all user prompts and run an automated installation, with the classic output
- `--redis` - Install and configure Redis as the database backend
- `--no-autostart` - Do not start ioBroker after the installation has finished
- `--hardened` - Do not give the `iobroker` user any sudo rights, see [Hardened mode](#hardened-mode)
- `--classic` (or `--no-tui`) - The classic flow with every line of output instead of the
  [interactive display](#interactive-display), see [Classic output](#classic-output)

The piped installation accepts the same options:
```bash
curl -sL https://iobroker.net/install.sh | bash -s -- --hardened
```

**Notes:**
- On a terminal the installer starts with the [interactive display](#interactive-display): a start screen
  where `--redis`, `--no-autostart` and `--hardened` can also be switched, then a progress view of the steps
- The installer creates an `iob` command with additional parameters (see [Service Control Commands](#service-control-commands))
- Root user detection is automatic with warnings and recommendations

### Interactive display

On a terminal, the installer and `iob fix` show a full screen display: the ioBroker logo, a start screen
with the options, dialogs for the questions and a progress view of the steps. The output of the steps
goes into a log file instead of the screen, the last line of it is shown under the progress bar:
`~/iobroker-install.log` for the installer, `~/iobroker-fix.log` for the fixer. At the end the display
disappears and a summary with the address of the admin and the path of the log stays in the terminal;
if a step fails, the last lines of the log are shown instead.

Keys: `↑`/`↓` choose, `Space` switches an option, `Enter` selects, `Q` quits without changing anything.
In the dialogs `←`/`→` choose and `Y`/`N` answer directly, `No` is preselected.

The display needs a terminal with someone in front of it. The classic line output stays in every other case,
so scripts, CI and automated installations behave as before:
- `--classic`, `--no-tui` or `--silent`, or the environment variable `IOB_NO_TUI=true` or `CI`
- no terminal: cron, cloud-init, `/etc/rc.local`, `ssh host 'curl ... | bash'` without `-t`, output into a
  file or a pipe
- `TERM` unset or `dumb`, or a terminal smaller than 70 x 24 characters

`curl -sL https://iobroker.net/install.sh | bash -` gets the display too: the keys are read from the
terminal, not from stdin, which carries the script. Without sudo rights that are remembered for a while
(`timestamp_timeout=0`), the password prompts would break into the display, so it switches to the classic
output after the first one.

### Classic output

`--classic` runs the installer or the fixer the way they ran before the interactive display: every command
prints its output into the terminal as it happens (package manager, npm, service setup), the steps are
marked by `====` banners, and the questions of the fixer are plain `(y/N)` prompts. Nothing is written to
`~/iobroker-install.log` or `~/iobroker-fix.log`. Use it to watch exactly what happens, to copy the output
into a forum post, or when the display does not work with a terminal. `--no-tui` is the same option under
its technical name; the start screen of the display mentions `--classic` in its last line.

```bash
# Installer
curl -sL https://iobroker.net/install.sh | bash -s -- --classic

# Fixer
iob fix --classic

# Combined with other options
curl -sL https://iobroker.net/install.sh | bash -s -- --classic --redis
iob fix --classic --no-update
```

To keep the classic output for good, set `IOB_NO_TUI=true`, e.g. in `~/.bashrc`, see
[IOB_NO_TUI](#iob_no_tui). To keep the display and still watch every line, follow the log from a second
terminal instead: `tail -f ~/iobroker-install.log`.

## Diagnostic Commands

### iob diag

```bash
iob diag [OPTIONS]
```

**Available Parameters:**
- `--de` - Output (partially) in German language. This is the only option that switches the language.
- `--unmask` - Show otherwise masked output for complete diagnosis
- `--summary`, `--short`, `-s`, `--zusammenfassung`, `--kurz`, `-k` - Show summary only. These are exact
  aliases of each other; none of them changes the language, combine with `--de` for a German summary.
- `--help` - Display help and exit. The help text itself is German only, and `-h` is *not* recognised.
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
- `--no-update` - Skip updating the system package repositories
- `--hardened` - Switch an existing installation to [Hardened mode](#hardened-mode). An installation that is
  already hardened stays hardened on every later `iob fix`, the flag is not needed again.
- `--classic` (or `--no-tui`) - The classic flow with every line of output instead of the
  [interactive display](#interactive-display), see [Classic output](#classic-output)

On a terminal the fixer starts with the [interactive display](#interactive-display), where `--no-update`
and `--hardened` can also be switched. It first checks that ioBroker is installed and stopped, and only
then asks its questions (user account, boot target, timezone).

**Examples:**
```bash
# Run standard fix
iob fix

# Remove the sudo rights of the iobroker user
iob fix --hardened

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
- `docker` - Show the Docker status and install Docker if it is missing, see [iob docker](#iob-docker)

**Global Options:**
- `--allow-root` - Allow running commands as root (applies to `fix` and `diag`). It has no effect on
  `nodejs-update`: the wrapper accepts the flag, but the script refuses to run as root in any case,
  so it is not forwarded.

**Note:** `fix`, `diag`, `nodejs-update` and `docker` are not run from this repository. The `iob` wrapper downloads
them from `https://iobroker.net/` at invocation time, so they are always the released version, never a
local change. All options are forwarded, so `iob diag --de --unmask` works as written.

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
- `VERSION` - Major Node.js version number (20, 22, 24, etc.)
  - If not specified, installs the recommended version (`nodeJsRecommended` from `versions.json`, currently 24)
  - Must be one of the accepted major versions (`nodeJsAccepted` from `versions.json`, currently 22, 24, 26).
    The script reads that list at runtime, so the set of allowed versions can change without a new release.
  - Only major version numbers are accepted
- `--dry-run` - Show what would be done without making any changes
- `-h, --help` - Show the usage information and exit

**Examples:**
```bash
# Install recommended Node.js version
iob nodejs-update

# Install specific major version (must be one of nodeJsAccepted)
iob nodejs-update 22
iob nodejs-update 26
```

### Direct Node Update Script

```bash
./node-update.sh [VERSION]
```

Uses the same parameters as `iob nodejs-update` above.

**What node-update does:**
- Updates Node.js to a specified or recommended version
- Only works on Debian-based Linux distributions
- Removes old Node.js versions and installs from NodeSource repository
- Fixes PATH issues with incorrect Node.js installations
- Sets the Node.js capabilities again (`cap_net_admin`, `cap_net_bind_service`, `cap_net_raw`)
- Not supported in Docker containers or WSL

**System Requirements:**
- Debian-based Linux distribution (Ubuntu, Debian, etc.)
- Not running as root
- Not in a Docker container
- Not in a WSL environment
- apt-get package manager available

### Capabilities after a Node.js update

Installing Node.js replaces the binary, and with it the capabilities the installer had granted it:
`cap_net_admin`, `cap_net_bind_service` and `cap_net_raw`. Adapters that need privileged ports or raw
sockets - ping, BLE, anything listening below port 1024 - stop working until those are set again.

`node-update.sh` sets them again after the installation, before ioBroker is started. It also does so when
there is nothing to update, so `iob nodejs-update` restores them after a plain `sudo apt upgrade nodejs`,
which drops them as well. A capability that is missing from the bounding set - a container started without
`--cap-add=NET_ADMIN`, for example - is skipped with a warning, because node would not start with it.

The script runs with the sudo rights of whoever calls it, not those of the `iobroker` service account, so
this works under `--hardened` too. If `setcap` fails, the script warns and continues; `iob fix` sets the
capabilities as well.

## Docker

### iob docker

```bash
iob docker [OPTIONS]
```

Shows whether Docker is installed, whether the Docker daemon is running, which Docker Compose version
is available and whether the `iobroker` user is a member of the `docker` group. If Docker is missing,
it asks whether it should be installed now.

**Parameters:**
- `-y, --yes` - Answer all questions with yes, so Docker is installed without asking
- `-h, --help` - Show the usage information and exit

**Examples:**
```bash
# Show the status, ask before installing
iob docker

# Install without asking, e.g. from a script
iob docker -y
```

**What it does:**
- Installs Docker with Docker's convenience script from `https://get.docker.com` (Debian, Ubuntu,
  Raspberry Pi OS, Fedora, CentOS, RHEL), then enables and starts the service on systemd
- Adds the `iobroker` user to the `docker` group, so that ioBroker can reach the Docker socket.
  Restart ioBroker afterwards (`iob restart`) so the running processes get the new membership.
  A `--hardened` installation is left alone, because membership in the `docker` group is equivalent
  to root rights
- If Docker is already installed but the `iobroker` user is not in the `docker` group, it offers to add it.
  With root or passwordless sudo, a `--hardened` installation is recognized before that question
- If Docker is installed but its service is not running (systemd), it offers to start and enable it
- Questions accept `y`/`yes` and the German `j`/`ja`. Without a terminal and without `-y`, nothing is
  installed or changed: a missing answer counts as "no"
- Exit code `0` if Docker is installed at the end, `1` otherwise

The status works for every user. Installing Docker, starting its service and changing the group need
sudo rights: the `iob` wrapper downloads the script as `iobroker`, but runs it as the user who called
`iob docker`.

**Installation not supported:**
- macOS (install Docker Desktop instead) and FreeBSD (no Docker available)
- ioBroker running inside a container (install Docker on the host)
- WSL (use Docker Desktop with its WSL integration)

With an existing Docker, e.g. Docker Desktop's WSL integration, `iob docker` still shows the status and
adds the `iobroker` user to the `docker` group, which the WSL integration needs as well. Inside a
container the group is left alone, because it is not the group of the host's socket.

The command is part of the `iob` wrapper written by the installer and the fixer. On an existing
installation run `iob fix` once to get it.

**Windows:** `iob docker` only shows the status there (Docker installed, engine running, Docker Compose
version) and does not install anything. Docker on Windows means Docker Desktop, which needs WSL2 or Hyper-V,
administrator rights and, for larger companies, a paid subscription. Its engine only runs while a user is
logged on, so after a reboot it is not available to the ioBroker service until someone logs on. `-y` is
accepted but has no effect. The script is `install/windows/dockerStatus.js`, copied into the ioBroker
directory by `npx @iobroker/install` and `npx @iobroker/fix`.

## Common Parameters Across Commands

### --allow-root
This parameter is available for most maintenance commands (`fix`, `diag`, `nodejs-update`, `docker`) and allows running the command as the root user. 

**Important Notes:**
- Running as root is NOT recommended for security reasons
- Only used when absolutely necessary for system repairs
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
- No additional command-line parameters are required

### Linux/macOS Installation  
When using the shell installer:
- `--silent` skips all user prompts
- `--classic` (or `--no-tui`) keeps the classic output on a terminal, see [Classic output](#classic-output)
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

### IOB_NO_TUI
```bash
IOB_NO_TUI=true iob fix
```
Keeps the classic line output on a terminal, like `--classic`. Useful where options cannot be passed, e.g.
a wrapper script. See [Interactive display](#interactive-display).

### AUTOMATED_INSTALLER
This is automatically set by the installer to indicate an automated installation is in progress. Not intended for manual use.

## Security Considerations

- **Never run as root** unless absolutely necessary for repairs
- Use `--allow-root` only when required and understand the security implications
- The `--unmask` parameter in diagnostics may reveal sensitive system information
- Always run the installer as a regular user when possible

### Hardened mode

By default, the installer gives the `iobroker` user passwordless sudo rights for a list of system tools
(`apt-get`, `dpkg`, `systemd-run`, `mount`, `docker`, `reboot`, ...) and adds it to the `docker` group. This is
what allows adapters and the admin interface to install OS dependencies, reboot the host, mount network shares
and so on. The drawback: the `iobroker` user is effectively root, so a compromised adapter compromises the whole
host.

With `--hardened` (installer or `iob fix`):
- the `iobroker` user gets **no** sudo rights and is removed from the `docker` group;
- starting/stopping the service and running the `iob` CLI via sudo is allowed only for members of the
  `iobroker` group instead of every local user;
- the setting is stored in the root-owned sudoers file (`/etc/sudoers.d/iobroker`, on FreeBSD
  `/usr/local/etc/sudoers.d/iobroker`), so the `iobroker` user cannot switch it off.

In hardened mode the following does **not** work anymore and has to be done by an administrator on the shell:
installing OS packages for adapters (`osDependencies`), reboot/shutdown of the host from ioBroker, mounting
network shares (e.g. by backups), setting capabilities on the Node.js binary with `setcap`, and adapters that
use `docker`, `arp-scan`, `nmcli`, `vcgencmd`, `mysqldump` or other tools via sudo.

Note that `--hardened` does not change how the **installation** itself runs: the installer and the fixer use
the privileges of whoever starts them (`sudo` for a normal user), so the sudoers file and the Node.js
capabilities are written either way. The flag only decides what the `iobroker` service account may do
afterwards. The same holds for `iob nodejs-update`, which sets the capabilities again after an update.

To go back to the default setup, delete the sudoers file and run the fixer. Hardened mode exists on
Linux and FreeBSD only - macOS never writes such a file. The path differs between the two, and
removing the Linux one on FreeBSD leaves the marker in place, so the next fixer run stays hardened:
```bash
# Linux
sudo rm /etc/sudoers.d/iobroker && iob fix

# FreeBSD
sudo rm /usr/local/etc/sudoers.d/iobroker && iob fix
```

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