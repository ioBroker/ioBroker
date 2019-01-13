#!/bin/bash

# We don't care about permissions now :D
sudo chmod -R 777 /opt/iobroker

ps auxww|grep io
/opt/iobroker/iobroker start

npm install request mocha chai --save

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
