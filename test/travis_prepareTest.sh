#!/bin/bash

cd ../..

sudo chmod -R 777 *
ps auxww|grep io
./iobroker start
sleep 60
ps auxww|grep io
date
cat ../../log/iobroker*.log

cd node_modules/iobroker/
