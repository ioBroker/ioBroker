#!/bin/bash

set -x

export NPM=$(which npm)
export NODE=$(which node)

# We don't care about permissions now :D
cd /opt/iobroker
sudo chmod -R 777 /opt/iobroker

ps auxww|grep io
cat -A ./iobroker
env "PATH=$PATH:$NPM:$NODE" ./iobroker start

npm install request mocha chai --save

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
