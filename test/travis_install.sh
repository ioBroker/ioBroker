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
sudo env "PATH=$PATH" $NPM install --unsafe-perm --prefix "node_modules/iobroker"; export EXIT_CODE=$?
# node version too old, the script should exit with code 2
if [[ $NODE_MAJOR -lt 4 ]]
then
	if [[ ($EXIT_CODE -eq 2) || ($EXIT_CODE -eq 1) ]]
	then
		# it should return 2, but apparently, npm@2 just returns 1 on error
		echo "old node version, correct exit code. stopping installation"
		# tell the install script that the test was ok but ioB wasn't installed
		touch iob_not_installed
		exit 0
	else
		echo "old node version, incorrect exit code $EXIT_CODE. canceling build"
		exit 1
	fi
fi

# npm version != 5 definitely supported
if [[ $NPM_MAJOR -ne 5 ]]
then 
	echo "npm version < 5, returning exit code $EXIT_CODE"
	exit $EXIT_CODE
fi

# npm@5, check the version range
if [[ ($NPM_MINOR -lt 7) || (($NPM_MINOR -eq 7) && ($NPM_BUILD -lt 1)) ]]
then
	# unsupported version (between 5.0.0 and 5.7.0)
	# the script should return with exit code 4
	if [[ $EXIT_CODE -eq 4 ]]
	then
		echo "unsupported npm version $NPM_MAJOR.$NPM_MINOR.$NPM_BUILD, correct exit code. stopping installation"
		# tell the install script that the test was ok but ioB wasn't installed
		touch iob_not_installed
		exit 0
	else
		echo "unsupported npm version $NPM_MAJOR.$NPM_MINOR.$NPM_BUILD, incorrect exit code. canceling build"
		exit 1
	fi
fi

# default: just return the exit code
echo "installation exit code was $EXIT_CODE"
exit $EXIT_CODE
