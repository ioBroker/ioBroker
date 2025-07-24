# Changelog for Node.js Updater Script

## 2025-07-25
* nodejs@22 is the default installation target when no other option set
* Added basic compatibility check - Only --dry-run, no changes
* Progressbar is shown only as long as the ioBroker shutdown takes
* Fixed finding the nodesource repo keys
* Code cleanup

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
