#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# Test that the relevant files exist and have the correct permissions
sudo -u iobroker test -r ./iobroker # readable
sudo -u iobroker test -x ./iobroker # executable
# add others when necessary