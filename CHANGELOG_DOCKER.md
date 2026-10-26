# Changelog for Docker Helper Script

## 2026-10-26
* Initial version of `iob docker`: shows whether Docker is installed and running, and installs it via get.docker.com after a confirmation (`-y`/`--yes` skips it); offers to start a stopped Docker service; the iobroker user is added to the docker group unless the installation is hardened
