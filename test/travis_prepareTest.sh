#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

sudo chmod -R 777 /home/travis/.npm
sudo chmod -R 777 "$IOB_DIR"
sudo usermod -a -G iobroker travis

npm install request mocha chai

ps auxww|grep io
node node_modules/iobroker.js-controller/iobroker.js start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
