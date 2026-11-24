# Changelog for Linux-Diag-Script
## 2026-11-22
* Log analysis: the restart loop warning now names the affected instances (with the number of detected restart loops per instance), so the originator can be addressed directly. The detection itself is left completely to the js-controller: only its "restart loop detected" log lines (an instance that crashed several times within ten minutes) are counted, no own filter logic. Frequent instance starts alone (e.g. scheduled adapters, which are woken up by their schedule and sleep again in between) never produce such a message.

## 2026-11-18
* Log analysis: the temporary log snapshot is now filtered down to the lines needed by the analyses (error/warn messages, instance starts, restart loops, NUL-containing lines) instead of keeping the complete decompressed history; an incompletely written snapshot (e.g. full tmpfs) is removed immediately and the analysis is skipped with a red error message (EN/DE) instead of silently reporting truncated counts

## 2026-11-16
* smartctl now runs via non-interactive sudo (sudo -n), so a sudo password prompt can no longer appear inside the diag output; the existing "SMART data could not be read" message covers this case
* CPU temperature output localized: German verdict lines for the --de variant
* Memory usage of ioBroker processes uses full process titles (ps args instead of comm), so long adapter names like io.zigbee2mqtt.0 are no longer truncated at 15 characters
* Removed a trailing empty line at the end of this file

## 2026-11-14
* Added CPU temperature check (vcgencmd or thermal_zone, warning thresholds)
* Added storage check: warning if the root filesystem is on an SD card; SMART health and attribute summary if smartctl is available
* Added swap evaluation (zram detection, no-swap warning)
* Added top 10 memory usage of ioBroker processes plus total RSS
* Added zombie process listing (pid/ppid/comm)
* Node.js/npm: pre-release detection with a clear warning instead of a plain "installation is correct"; warning if the installed major version differs from the recommended one
* The vulnerability check no longer misreports a crashing check as "vulnerabilities detected": pre-release versions are detected and skipped, fetch errors are reported as "check could not be executed"
* Added capabilities (getcap) check on the node binary with a hint to 'iobroker fix'
* js-controller: pre-release/nightly detection and a notice when the controller uptime is significantly shorter than the system uptime (restart after boot)
* Added admin authentication status (native.auth of admin.0)
* Added last local backup age check for /opt/iobroker/backups
* Added history adapter storage aggregation per data point (top 10)
* Added log analysis over the available log files: error/warning counts per instance, instance start counts and restart-loop detection
* Summary extended by: Node.js pre-release, js-controller pre-release, log error/warning totals, backup age and SD card warning

## 2026-11-09
* Fixed installation date detection: fallback chain with method annotation (root inode birth time -> first pacman.log entry -> first entry of oldest dpkg.log rotation -> oldest file in /etc (birth time) -> mtime of /); fresh installs (0 days) are no longer reported as "installation date unknown"
* dpkg.log result is reported as a lower bound ("at least N days ago"), since rotated logs may not reach back to the installation
* Language checks now consistently use SKRPTLANG and [[ ]]

## 2026-11-01
* Fixed Raspberry Throttling check

## 2026-10-01
* Readded nodejs recommended version hint

## 2026-08-30
* Removed old usb port check
* Limit dmesg output concerning filesystems to last 15 lines

## 2026-05-18
* Fixed experimental zigbee ports detection
* Added adapter list

## 2026-03-10
* Code cleanup
* Added zigbee port overview
* Fixed user check

## 2026-03-01
* nodejs vulnerability check is more robust
* Changed output of netstat - Use ss if available.
* Added check for running malware process 'pawns-cli'

## 2026-01-31
* Improved --help option

## 2026-01-30
* Minor fixes

## 2026-01-26
* Only architectures amd64 and arm64 are supported for current nodejs versions
* Removed check for corepack
* Removed generic messages concerning EXT4 file system

## 2025-08-09
* Added nodejs vulnerability check
* Removed references to static release names 
* Added nodejs vulnerability check 

## 2025-05-24
* Added test for Xorg Display Server
* Only show zigbee settings when zigbee-Adapter is installed 
* Added -h / --help Option
* Summary is optional. Use Options --summary --short --zusammenfassung --kurz to show it. 
* Default output is the full diag 

## 2025-02-23
* Added diag for Zigbee-Settings (default output is masked)
* Added --unmask Option

## 2024-02-02
* Made iob diag compatible with --allow-root-Option

## 2024-10-19
* Included 'dist-info' for Lifecycle status of Debian/Ubuntu releases

## 2024-09-28
* Moved options to fix configurations to 'iob fix'

## 2024-09-21
* Added option to set `multi-user.target` on systemd-based machines
* With option '--de' some output will be in the German language
* Avoided sourcing /etc/os-release for security reasons
* Implemented Debian & Ubuntu Lifecycle check
* Made setting timezone more generic on non-Debian systemd
* Implemented check for a default user and offer to create one if missing
* Added check for 'critical errors' in dmesg
* Added 'iob list hosts' command

## 2026-05-18 
* Added iob list adapters

## 2024-06-24
* Added language information to CodeTags for copying to ioB-Forum.
* Only show mounted filesystems that are real
* Deactivated some VAR that were not used anyway

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
