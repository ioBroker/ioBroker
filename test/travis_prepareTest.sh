#!/bin/bash

sudo chmod -R 777 *
ps auxww|grep io
./iobroker start

npm install request mocha chai --save

sleep 60
ps auxww|grep io
date
cat log/iobroker*.log
