# Changelog for Linux-Diag-Script

# 2024-06-24
* Added language information to CodeTags for copying to ioB-Forum.

## 2024-05-22
* Added nodejs20
* pgrep fixed for Display Server Detection
* Fixed timezone detection on Docker

## 2024-04-21
* root check less strict - Script can now be run as root
* Check for Userland architecture made compatible with non-Debian Linux
* Check for Users and their Groups
* Fixed check for running Display-Server
* Added excerpt of 'top' - Only the header is displayed
* All mounted filesystems are displayed, even virtual ones
* Added check for 'by-id'-Links for serial devices (e.g. ZigBee-Sticks)
* Made nodejs-Check more compatible with non-Debian Linux
* GitHub-Installations are listed by name
* Extended 'by-id'-Checks for Zigbee COM-Ports
* Better check for running Display Servers

## 2023-10-10
* Removed output of Machine & Boot IDs.
* Added a human-readable diag of Raspberry Throttling States

## 2023-04-16
* Enhanced node.js check
* Fixed some Docker related compatibility issues

## 2023-04-02
* Add checks for npm directory issues and tell the user to run the fixer

## 2023-02-19
* Restructured Summary and added memory state

## 2023-01-02
* Added npx version to diag command
* Added latest dmesg content to diag command

## 2022-12-31
* Added tail -n 25 for iob logs
* Added status of admin in Summary

## 2022-12-30
* Added some more checks

## 2022-12-13
* Fixed 'Press any key' request

## 2022-12-09
* Initial release
