#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# What are the permissions here?
cat INSTALLER_INFO.txt

id
ls -la .
ls -la /home/travis
ls -la /home/travis/.npm/
ls -la /home/travis/.npm/_cacache

npm install request mocha chai --save

ps auxww|grep io
node node_modules/iobroker.js-controller/iobroker.js start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
