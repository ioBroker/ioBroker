#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# sudo chown -R travis:travis /home/travis/.npm
# sudo chmod -R 777 /home/travis/.npm

sudo -H -u iobroker "npm install request mocha chai --save"

ps auxww|grep io
sudo -H -u iobroker "node node_modules/iobroker.js-controller/iobroker.js start"

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
