#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# What are the permissions here?
cat INSTALLER_INFO.txt

id
ls -la /home/travis/.npm/_cacache/index-v5/**/*

npm install request mocha chai --save

ps auxww|grep io
node node_modules/iobroker.js-controller/iobroker.js start

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
