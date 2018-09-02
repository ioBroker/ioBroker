#!/bin/bash
sudo mkdir -p /opt/iobroker
cd /opt/iobroker
npm i https://github.com/AlCalzone/ioBroker/tarball/install-v2
sudo npm i --production --unsafe-perm
