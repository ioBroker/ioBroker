# Get the latest stable version of Node.js or io.js
Install-Product node $env:nodejs_version $env:platform
# if we have defined a specific npm version, use that one
if ($env:npm_version -ne $null) { npm i -g npm@$env:npm_version }

node -v
npm -v

$MIN_NODE_VERSION = [System.Version]"8.12.0"
# The maximum supported pre-npm5 npm version
$MAX_NPM_VERSION_LEGACY_EXCLUSIVE = [System.Version]"5.0.0" #Cut this when we're completely dropping old npm versions
# The minimum supported new npm version
$MIN_NPM_VERSION = [System.Version]"5.7.1"

$NodeVersion = [System.Version](node -v).Substring(1)
$NpmVersion = [System.Version](npm -v)

# we force npm to do an actual package install because it will throw a fit otherwise
# So we capture the current git status in a .tar.gz package
Push-Location -Path "node_modules\iobroker"
npm pack | Tee-Object -Variable tgz
Move-Item -Path $tgz -Destination ..\..
Pop-Location
# delete everything else
Remove-Item "node_modules\iobroker" -Force -Recurse

# try to install ioBroker and capture the response code to test its behavior
npm install "$tgz" --no-optional
$EXIT_CODE = $LASTEXITCODE

# node version too old, the script should exit with code 2
if ($NodeVersion -lt $MIN_NODE_VERSION) {
	if (($EXIT_CODE -eq 2) -or ($EXIT_CODE -eq 1)) {
		# it should return 2, but apparently, npm@2 just returns 1 on error
		echo "old node version, correct exit code. stopping installation"
		# tell the install script that the test was ok but ioB wasn't installed
		$env:iob_not_installed = "true"
		exit 0
	} else {
		echo "old node version, incorrect exit code $EXIT_CODE. canceling build"
		exit 1
	}
}

# npm@5, check the version range
if (($NpmVersion -ge $MAX_NPM_VERSION_LEGACY_EXCLUSIVE) -and ($NpmVersion -lt $MIN_NPM_VERSION)) {
	# unsupported version (between 5.0.0 and 5.7.0)
	# the script should return with exit code 4
	if ( $EXIT_CODE -eq 4 ) {
		echo "unsupported npm version $NpmVersion, correct exit code. stopping installation"
		# tell the install script that the test was ok but ioB wasn't installed
		$env:iob_not_installed = "true"
		exit 0
	} else {
		echo "unsupported npm version $NpmVersion, incorrect exit code. canceling build"
		exit 1
	}
}

# NPM version supported
# Do the 2nd part of the installation
npm install --production --no-optional
$EXIT_CODE = $LASTEXITCODE
echo "installation exit code was $EXIT_CODE"
exit $EXIT_CODE