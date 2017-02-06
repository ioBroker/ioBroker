#!/usr/bin/env bash
# install ioBroker on Raspbian 8/Debian Jessie with SystemD
# Copyright (c) 2017, keynight iobroker.net/forum


# install NodeJS for non Raspbian 8/Debian Jessie
#curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -



# add repos for node_4.x for Raspbian 8/Debian Jessie
echo "###############  add repos for node_4.x for Raspbian 8/Debian Jessie ###############"
curl --silent https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
if true ; then
    sudo cat <<- EOF > /etc/apt/sources.list.d/nodesource.list
deb https://deb.nodesource.com/node_4.x jessie main
deb-src https://deb.nodesource.com/node_4.x jessie main
    EOF
fi


# add start script /etc/init.d/iobroker
echo "############### add start script /etc/init.d/iobroker  ###############"
if true ; then
    sudo cat <<- EOF > /etc/init.d/iobroker
#!/bin/bash

### BEGIN INIT INFO
# Provides:          iobroker
# Required-Start:    $network $local_fs $remote_fs
# Required-Stop::    $network $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts ioBroker
# Description:       starts ioBroker
### END INIT INFO

source /etc/profile
source /etc/skel/.bashrc
source /etc/skel/.profile

(( EUID )) && echo .You need to have root privileges.. && exit 1
PIDF=/opt/iobroker/node_modules/iobroker.js-controller/lib/iobroker.pid
#NODECMD=/usr/local/bin/node
NODECMD=/usr/bin/node
IOBROKERCMD=/opt/iobroker/node_modules/iobroker.js-controller/iobroker.js
RETVAL=0
#IOBROKERUSER=root
IOBROKERUSER=roker

# Starting ioBroker
export IOBROKER_HOME=/opt/iobroker
echo -n "Starting ioBroker"
sudo -u ${IOBROKERUSER} $NODECMD $IOBROKERCMD start
    EOF
fi



# add service script /etc/systemd/system/iobroker.service
echo "############### add service script /etc/systemd/system/iobroker.service  ###############"
if true ; then
    sudo cat <<- EOF > /etc/systemd/system/iobroker.service
#
# Start ioBroker Daemon
#
# /etc/systemd/system/iobroker.service
# Invoking scripts to start/shutdown ioBroker

[Unit]
Description=ioBroker server task
Requires=network.target

[Service]

User=roker
#User=root

Type=forking
RemainAfterExit=yes
Restart=no

ExecStart=/etc/init.d/iobroker

[Install]
WantedBy=multi-user.target
    EOF
fi



# add user for ioBroker
echo "###############  Add user roker with sudo permisions for ioBroker ###############"
sudo adduser roker -G sudo --home /opt/iobroker
sudo sh -c "echo 'roker ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"


# fix permisions
sudo chmod 755  /etc/init.d/iobroker
sudo chmod 755  /etc/systemd/system/iobroker.service


# install nodejs and another tools
echo "###############  install NodeJs and another tools ###############"
# install nodejs
sudo apt-get update
sudo apt-get --purge remove node
sudo apt-get --purge remove nodejs
sudo apt-get autoremove
sudo apt-get install -y build-essential python-rpi.gpio nodejs 
# install another tools
#sudo apt-get install -y redis-server redis-tools mosquitto mosquitto-clients



# install ioBroker
echo "###############  install ioBroker ###############"
sudo mkdir /opt/iobroker
sudo chown -R roker.roker /opt/iobroker
sudo chmod 777 /opt/iobroker
cd /opt/iobroker
sudo npm install iobroker --unsafe-perm
sudo chown -R roker.roker /opt/iobroker
sudo ln -s /opt/iobroker/iobroker /usr/sbin/iobroker

echo "###############  start ioBroker ###############"
sudo systemctl daemon-reload
sudo systemctl enable iobroker.service 
sudo systemctl start iobroker.service


echo "###############  status ioBroker ###############"
sudo systemctl status iobroker.service

echo "###############  You can login in ioBroker ###############"
IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
echo "###############  http://$IP:8081/  ###############"
