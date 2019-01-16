#!/bin/bash

# We don't care about permissions now :D
IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR
sudo chmod -R 777 .

npm install request mocha chai --save

ps auxww|grep io
./iobroker start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
