#!/bin/bash
set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# We don't care about permissions now :D
sudo chmod -R 777 .

npm install request mocha chai --save

ps auxww|grep io
node node_modules/iobroker.js-controller/iobroker.js start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
