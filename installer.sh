#!/bin/bash
# ensure the directory exists
sudo mkdir -p /opt/iobroker
cd /opt/iobroker
# download the installer files and run them
npm i https://github.com/AlCalzone/ioBroker/tarball/install-v2
# TODO: GH#48 Make sure we don't need sudo, so we can remove that and --unsafe-perm
sudo npm i --production --unsafe-perm
# npm i --production # this is how it should be

# If we want to autostart ioBroker with systemd, enable that
if [ -f /lib/systemd/system/iobroker.service ];
then
	sudo systemctl daemon-reload
	sudo systemctl enable iobroker
	sudo systemctl start iobroker
fi
