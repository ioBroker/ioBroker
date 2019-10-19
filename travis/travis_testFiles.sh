#!/bin/bash

set -ex

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# On linux, the iobroker user must be able to access the files
TEST_CMD="sudo -u iobroker test"
if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
	# On OSX, the current one (i.e. travis)
	TEST_CMD="test"
fi

# Test that the relevant files exist and have the correct permissions
$TEST_CMD -f ./iobroker # is a file
$TEST_CMD -r ./iobroker # is readable
$TEST_CMD -x ./iobroker # is executable
# add others when necessary