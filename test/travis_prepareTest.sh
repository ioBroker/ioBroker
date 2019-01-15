#!/bin/bash

# We don't care about permissions now :D
cd /opt/iobroker
sudo chmod -R 777 /opt/iobroker

npm install request mocha chai --save

ps auxww|grep io
./iobroker start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
