#!/bin/bash
# ensure the directory exists and take control of it
sudo mkdir -p /opt/iobroker
sudo chown $USER -R /opt/iobroker
cd /opt/iobroker

# suppress messages with manual installation steps
export AUTOMATED_INSTALLER="true"

# download the installer files and run them
npm i https://github.com/AlCalzone/ioBroker/tarball/install-v2
# TODO: GH#48 Make sure we don't need sudo, so we can remove that and --unsafe-perm
sudo npm i --production --unsafe-perm
# npm i --production # this is how it should be
# Because we used sudo, we now need to take control again
sudo chown $USER -R /opt/iobroker

# If we want to autostart ioBroker with systemd, enable that
if [ -f /lib/systemd/system/iobroker.service ];
then
	# We cannot use sudo here because it will fail silently otherwise
	echo "Enabling autostart..."
	systemctl daemon-reload
	systemctl enable iobroker
	systemctl start iobroker
	echo "Autostart enabled!"
fi
