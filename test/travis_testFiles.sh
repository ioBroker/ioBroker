#!/bin/bash

set -x

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# Test that the relevant files exist and have the correct permissions
sudo -u iobroker test -r ./iobroker && echo "OK" # readable
sudo -u iobroker test -x ./iobroker && echo "OK" # executable
# add others when necessary