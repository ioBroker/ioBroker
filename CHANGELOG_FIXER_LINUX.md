# Changelog for Linux-Fixer-Script

## 2025-02-02
* Fix user creation in Fixer script
* Block using --allow-root when not root
* Made /home/iobroker accessible for iobroker group

## 2024-10-22
* Allow iob start/stop/restart also as root but log information
* Also install passwd and polkitd packages because some lxc systems might miss it

## 2024-10-19
* Added 'distro-info' package to prerequisites list

## 2024-10-04
* Enhance root check and messaging
* Implemented adding default user if none is available
* Implemented setting multi-user.target on systemd Linux
* adds "nmcli" to allowed sudo commands
* root/sudo locked out for systemd based installations
* --allow-root Option enabled (Just for a transition time)

## 2024-08-11
* Implemented reconfiguring time zone if none is set

## 2024-01-04
* Fix package installation issues on Debian

## 2023-12-30
* Fix Nodejs Update script call
* Fixes in Nodejs installation

## 2023-12-29
* Make sure installation also proceed on new Ubuntu versions when package installations require service restarts

## 2023-10-13
* Allow to define Node.js version as parameter for "iob nodejs-update" command
* fix package installation error for gcc

## 2023-10-12
* Fix how the Node.js update script is called

## 2023-10-10
* Add command "iob nodejs-update" to update Node.js to latest recommended version (or any when major given as parameter)

## 2023-04-02
* Add check for left over npm temporary directories and clean them up if found

## 2022-12-22
* Adjustments to run diagnostic script differently

## 2022-12-09
* Add Compressing of the JSONL databases when JSONL is used
* Adjust Docker detection
* Add Diag script and "iob diag" command

## 2022-06-03
* Remove python-dev from installed debian packages again to prevent installing python2 on some distributions

## 2022-02-13
* Delay restarting js-controller after a crash to avoid locked DB files

## 2022-02-10
* Prevent npm from showing npm update information

## 2021-12-27
* Install `cmake` on linux

## 2021-04-07
* Install backitup Adapter on new installations by default (not fixer relevant)

## 2021-01-23
* (Linux) fix CLI completions
* (Linux) revert "ignore which aliases"

## 2021-01-20
* (Linux) enable auto-completion for iobroker commands
* (Linux) ignore which aliases
* (Linux) updated native packages so canvas can be built by default
* (macOS) disabled file permission check on OSX
* fixed cirrus tests
* added support of npm7

## 2020-12-07
* (FreeBSD) Fixed installation for FreeBSD by using `/usr/bin/env` to detect path for `bash` automatically and do not enforce usage of python 2.7 which is EOL
* (Linux) Use `-y` argument for `yum`

## 2020-06-15
* Corrected installer_library.sh path on github (error #281) 

## 2020-06-12
* (Linux) Added net-tools to fix error #277 "ifconfig: command not found" 
* (Linux) correctly parse string arguments inside quotes

## 2020-04-12
* (Linux) Avoid entering the sudo password for iobroker CLI

## 2020-01-30
* (Linux) Add iobroker user to the `video` group

## 2020-01-25
* The installer lib file is now deleted after sourcing it
* Configure `npm` to enforce engine versions in `package.json`

## 2020-01-13
* The `shutdown` command is no longer limited to `-h now`
* (bluefox) The following services are now started before ioBroker if possible:
    * Influx DB
    * MySQL Server
    * Maria DB

## 2019-11-29
* Add user to `video` group (Linux)

## 2019-11-26
* (ADOE) Extracted many shared Installer/Fixer functions into a common library script

## 2019-11-10
* FreeBSD should now finally be supported correctly

## 2019-10-21
* (ADOE) Large refactoring:
    * moved some functions to fit order in INSTALLER
    * refactored 3 repeated execution blocks into function "add2sudoers()"
    * introduced var $SUDOX as shortcut for "if $IS_ROOT... then ... else ... fi"
    * refactored detection of HOST_PLATFORM into function get_platform_params()
    * extended function "get_platform_params()": now delivers vars: HOST_PLATFORM, INSTALL_CMD, IOB_DIR, IOB_USER
    * changed "brew" and "pkg" to "$INSTALL_CMD"
    * refactored "Enable colored output" into function "enable_colored_output()"
    * refactored "Determine the platform..." to function  "install_necessary_packages()"
    * calling "install_package()" instead of "install_package_*"

## 2019-10-19
* Install `python-dev` to fix npm error: `ImportError: No module named compiler.ast`

## 2019-10-18
* Emergency fix to last change: escape `$` in `$(pwd)`

## 2019-10-13
* Always run `npm` as iobroker when inside installation dir

## 2019-09-30
* Allow passwordless sudo for `mysqldump`
* Allow passwordless sudo for `ldconfig`

## 2019-09-25
* Disable any warnings related to `npm audit fix`

## 2019-09-16
* Support of CentOS and AWS AMI

## 2019-07-21
* suppress warnings during npm install

## 2019-07-17
* Fix for Debian 10: Add `/sbin` and similar directories to `PATH` at the start of the script

## 2019-07-03
* Include `PATH` environment variable in OSX startup script

## 2019-06-29
* Add install fixer as iobroker shortcut via "iobroker fix"
* Autodetect `bash` path to fix `command not found` on FreeBSD

## 2019-05-14
* (Linux) Add iobroker user to the `audio` group

## 2019-04-04
* Docker: Auto-detect if the container has `CAP_NET_ADMIN` and give it to `node` if possible

## 2019-03-15
* Add `-H` flag to `sudo -u iobroker` to fix EACCES errors when using the `iobroker` commands to install stuff.

## 2019-03-10
* Don't set CAP_NET_ADMIN in Docker
* Fixed the group add command in FreeBSD

## 2019-03-06
* Fixed the setcap command so it works in Docker
* Fixed another typo in FreeBSD installation routine

## 2019-03-05
* Fixed typo in FreeBSD installation routine

## 2019-03-04
* Also set the correct ACLs when running the script as root

## 2019-03-03
* Allow the commands needed by RPI2

## 2019-03-01
* Add redis as a dependency to the `systemd` unit and `init.d` script to avoid deadlocks on shutdown
* Removed limitation for number of arguments for iobroker

## 2019-02-25
* Fix setcap and include all in one command

## 2019-02-23
* Give nodejs access to raw devices like ble

## 2019-02-21
* Brings existing installations up to par with installer version 2019-02-15
