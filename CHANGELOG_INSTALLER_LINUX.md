# Changelog for Linux-Installer-Script

## 2019-01-20 (https://github.com/ioBroker/ioBroker/pull/99)
* User creation and specifying which commands may be executed as sudo without password
* Creation of the startup files for /etc/init.d, systemd (Linux/OSX) and rc.d (FreeBSD), including detection of the node executable on startup
* Creation of the executables iob and iobroker
* Automated installation of commonly used packages
* More logs into INSTALLER_INFO.txt
* Automatic IP address detection for the final message
* Detection if the installer script is being run as a result of npm install or some other command. - This should fix failures during execution of npm rebuild
* Run all iobroker commands as the iobroker user if possible
* Fix iobroker start/stop/restart/status when systemd is used


## 2019-01-02 (and earlier)
* this version introducted writing INSTALLER_INFO.txt into the ioBroker directory with installation details used later on for support reasons
* initial versions of the script and added several stuff, too much to describe here. This is used as baseline for the shellscript

