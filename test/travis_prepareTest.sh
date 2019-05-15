#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

sudo chmod -R 777 .
sudo usermod -a -G iobroker travis

ls -la node_modules
npm ls
npm install request mocha chai
ls -la node_modules
npm ls

ps auxww|grep io
ls -la node_modules/iobroker.js-controller
node node_modules/iobroker.js-controller/iobroker.js start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
