# Changelog for Windows-Installer-NPX
<!-- ## **WORK IN PROGRESS**
-->
## 6.0.1 (2024-08-23)
* Windows: Fix service installation error on very slow PCs

## 6.0.0 (2024-08-10)
* Adjust minimum Node.js version to 18 of new main package which match to the minimum version of js-controller 6.0.x
* Rebuild Windows install logic to use the new installer script
* Windows: Ensure that git installations runs without user interaction

## 5.1.2 (2024-05-23)
* Create the correct `controller.js` file on windows to work with controller v6

## 5.0.0 (2023-09-14)
* Adjust minimum Node.js version to 16.13 for new installations which match to the minimum version of js-controller 5.0.x

## 4.3.4 (2023-04-20)
* Handle restart properly in iob.bat and iobroker.bat for Windows

## 4.3.1 (2023-02-27)
* Optimize Windows installation

## 4.3.0 (2023-02-27)
* Also create Start-menu entries for Windows installation
* Add option to specify the Windows service name for Windows installation

## 4.2.2 (2023-01-14)
* Optimize Windows installer script
* Do JSONL DB compression earlier in the Windows installer flow

## 4.2.1 (2022-12-22)
* Caught some errors when executed in wrong directory on windows

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
