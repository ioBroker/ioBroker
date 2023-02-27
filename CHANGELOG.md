# Changelog for Windows-Installer-NPX
<!-- ## **WORK IN PROGRESS**
-->

### __WORK IN PROGRESS__
* Also create Startmenu entries for Windows installation
* Add option to specify the Windows service name for Windows installation

## 4.2.2 (2023-01-14)
* Optimize Windows installer script
* Do JSONL DB compression earlier in the windows installer flow

## 4.2.1 (2022-12-22)
* Catched some errors when executed in wrong directory on windows

## 4.2.0 (2022-12-09)
* Sync Windows installer with Linux installer
* Add Windows Fixer to compress JSONL databases

## 4.1.11 (2022-05-25)
* Made the parameters call list longer

## 4.1.10 (2022-05-23)
* Start/stop service by calling `iob.bat start/stop`

## 4.1.9 (2022-05-23)
* Stop service before fix and then start service again

## 4.1.7 (2022-05-23)
* ioBroker stopped now before fix

## 4.1.5 (2022-05-22)
* Added support for windows: `iob fix`

## 4.1.4 (2022-05-22)
* Allowed to install on linux too

## 4.0.3 (2022-05-22)
* Corrected fixer

## 4.0.2 (2022-05-22)
* Activate windows as npx installer again
