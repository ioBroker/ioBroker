#!/bin/bash

cd ../..
sudo chmod -R 777 *
ps auxww|grep io
./iobroker start
cd node_modules/iobroker/
npm install request
npm install mocha
npm install chai
sleep 60
ps auxww|grep io
date
cat ../../log/iobroker*.log
