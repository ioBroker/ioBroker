#!/bin/bash

set -ex

IOB_DIR=$([ -d /opt/iobroker ] && echo "/opt/iobroker" || echo "/usr/local/iobroker")
cd $IOB_DIR

# On linux, the iobroker user must be able to access the files
TEST_CMD="sudo -u iobroker test"
IOB_USER="iobroker"
if [ "$TRAVIS_OS_NAME" = "osx" ]; then
	# On OSX, the current one (i.e. travis)
	TEST_CMD="test"
	IOB_USER="travis"
fi

# Test that the relevant files exist and have the correct permissions

# All files in $IOB_DIR must belong to $IOB_USER and be readable
shopt -s dotglob # include dotfiles in *.* glob
for file in *.*; do
	[ $(stat -c %U $file) = "$IOB_USER" ] # has the correct owner
	$TEST_CMD -r $file # is readable
done

# The iobroker binary must be a readable and executable file
$TEST_CMD -f ./iobroker # is a file
$TEST_CMD -r ./iobroker # is readable
$TEST_CMD -x ./iobroker # is executable

# add others when necessary