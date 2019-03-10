# Changelog for Linux-Fixer-Script

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
