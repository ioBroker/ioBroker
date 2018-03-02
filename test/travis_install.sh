#!/bin/bash

export NPM=$(which npm)
export NPM_MAJOR=$($NPM -v | cut -d. -f1)
export NPM_MINOR=$($NPM -v | cut -d. -f2)
export NPM_BUILD=$($NPM -v | cut -d. -f3)
export NODE=$(which node)
export NODE_MAJOR=$($NODE -v | cut -d. -f1 | cut -dv -f2)
export NODE_MINOR=$($NODE -v | cut -d. -f2)
export NODE_BUILD=$($NODE -v | cut -d. -f3)

# try to install ioBroker and capture the response code to test its behavior
sudo env "PATH=$PATH" $NPM install --unsafe-perm; export EXIT_CODE=$?
# node version too old, the script should exit with code 2
if [[ $NODE_MAJOR < 4 ]]
then
	if [[ $EXIT_CODE -eq 2 ]]; then exit 0 ; else exit 1; fi
fi

# npm version definitely supported
if [[ $NPM_MAJOR < 5 || $NPM_MAJOR > 5]]; then exit $EXIT_CODE; fi

# npm@5, check the version range
if [[ $NPM_MINOR < 7 || ($NPM_MINOR -eq 7 && $NPM_BUILD < 1)]]
then
	# unsupported version (between 5.0.0 and 5.7.0)
	# the script should return with exit code 4
	if [[ $EXIT_CODE -eq 4 ]]; then exit 0 ; else exit 1; fi
fi

# default: just return the exit code
exit $EXIT_CODE
