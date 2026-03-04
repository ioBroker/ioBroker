# Changelog for Node.js Updater Script
## 2026-03-04
* Skript renamed to nodejs_update.sh to avoid globbing
* Fixed removal of nodejs package, including dfsg version

## 2026-03-02
* Use deb822 format for sources in accordance with nodesource installer script
* Replace hardcoded Node.js version with dynamic lookup from `versions.json`

## 2026-01-31
* Fixed finding repo signature keys
* Removed deprecated dependency
* Minor fixes

## 2026-01-26
* Adjustments due to new package signature keys
* General fixes
* Fixing endless stop loop when iob was not even running
* Removed check for corepack
* Remove any exiting nodesource source files 

## 2025-08-14
* Avoid having two pinning files and bumping the pin priority to 1001 

## 2025-08-09
* nodejs@22 is the default installation target when no other option set
* Added basic compatibility check - Only --dry-run, no changes
* Progressbar is shown only as long as the ioBroker shutdown takes
* Fixed finding the nodesource repo keys
* Code cleanup

## 2025-05-31
* Added basic compatibility check

## 2025-02-23
* Check for illegal version option 

## 2024-10-10
* Fix buster / Debian 10 detection

## 2024-09-29
* Fixed buster&nodejs18 detection

## 2024-06-20
* Prevent nodejs-update on Buster, except installing nodejs@18
* Added removal of dfsg-nodejs version
* Suppressed some error messages

## 2024-05-23
* Added nodejs20 as the default version

## 2023-10-13
* Also allow to run as root but display informative message

## 2023-10-10
* Initial release with new Nodesource script and Node.js 18 as recommended version
