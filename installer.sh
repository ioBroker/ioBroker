#!/usr/bin/env bash

# Increase this version number whenever you update the installer
INSTALLER_VERSION="2022-01-23" # format YYYY-MM-DD

# Test if this script is being run as root or not
if [[ $EUID -eq 0 ]];
then IS_ROOT=true;  SUDOX=""
else IS_ROOT=false; SUDOX="sudo "; fi
ROOT_GROUP="root"
USER_GROUP="$USER"

# get and load the LIB => START
LIB_NAME="installer_library.sh"
LIB_URL="https://raw.githubusercontent.com/ioBroker/ioBroker/master/$LIB_NAME"
curl -sL $LIB_URL > ~/$LIB_NAME
if test -f ~/$LIB_NAME; then source ~/$LIB_NAME; else echo "Installer/Fixer: library not found"; exit -2; fi
# Delete the lib again. We have sourced it so we don't need it anymore
rm ~/$LIB_NAME
# get and load the LIB => END

# test one function of the library
RET=$(get_lib_version)
if [ $? -ne 0 ]; then echo "Installer/Fixer: library $LIB_NAME could not be loaded!"; exit -2; fi
if [ "$RET" == "" ]; then echo "Installer/Fixer: library $LIB_NAME does not work."; exit -2; fi
echo "Library version=$RET"

# Test which platform this script is being run on
get_platform_params
set_some_common_params

if [ "$IS_ROOT" = "true" ]; then
	print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION"
else
	print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION" "" "You might need to enter your password a couple of times."
fi

# Which npm package should be installed (default "iobroker")
INSTALL_TARGET=${INSTALL_TARGET-"iobroker"}

export AUTOMATED_INSTALLER="true"
NUM_STEPS=4

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"

# update repos
$SUDOX $INSTALL_CMD $INSTALL_CMD_UPD_ARGS update

# Install Node.js if it is not installed
if [[ $(which "node" 2>/dev/null) != *"/node" ]]; then
	install_nodejs
fi

# Check if npm is installed
if [[ $(which "npm" 2>/dev/null) != *"/npm" ]]; then
	# If not, try to install it
	install_package npm
	if [[ $(which "npm" 2>/dev/null) != *"/npm" ]]; then
		echo "${red}Cannot continue because \"npm\" is not installed and could not be installed automatically!${normal}"
		exit 1
	fi
fi

# Select an npm mirror, by default use npmjs.org
REGISTRY_URL="https://registry.npmjs.org"
case "$MIRROR" in
	[Tt]aobao)
		REGISTRY_URL="https://registry.npm.taobao.org"
		;;
esac
if [ $(npm config get registry) != "$REGISTRY_URL" ]; then
	echo "Changing npm registry to $REGISTRY_URL"
	npm config set registry $REGISTRY_URL
fi

# Determine the platform we operate on and select the installation routine/packages accordingly
install_necessary_packages

# ########################################################
print_step "Creating ioBroker user and directory" 2 "$NUM_STEPS"

# Ensure the user "iobroker" exists and is in the correct groups
if [ "$HOST_PLATFORM" = "linux" ]; then
	create_user_linux $IOB_USER
elif [ "$HOST_PLATFORM" = "freebsd" ]; then
	create_user_freebsd $IOB_USER
fi

# Ensure the installation directory exists and take control of it
$SUDOX mkdir -p $IOB_DIR
if [ "$IS_ROOT" != true ]; then
	# During the installation we need to give the current user access to the install dir
	# On Linux, we'll fix this at the end. On OSX this is okay
	if [ "$HOST_PLATFORM" = "osx" ]; then
		sudo chown -R $USER $IOB_DIR
	else
		sudo chown -R $USER:$USER_GROUP $IOB_DIR
	fi
fi
cd $IOB_DIR
echo "Directory $IOB_DIR created"

# Log some information about the installer
touch $INSTALLER_INFO_FILE
chmod 777 $INSTALLER_INFO_FILE
echo "Installer version: $INSTALLER_VERSION" >> $INSTALLER_INFO_FILE
echo "Installation date $(date +%F)" >> $INSTALLER_INFO_FILE
echo "Platform: $HOST_PLATFORM" >> $INSTALLER_INFO_FILE


# ########################################################
print_step "Installing ioBroker" 3 "$NUM_STEPS"

# Disable any warnings related to "npm audit fix"
disable_npm_audit

# Enforce strict version checks before installing new packages
force_strict_npm_version_checks

# Create ioBroker's package.json and install dependencies:
PACKAGE_JSON_FILE=$(cat <<- EOF
	{
		"name": "iobroker.inst",
		"version": "3.0.0",
		"private": true,
		"description": "Automate your Life",
		"engines": {
			"node": ">=10.0.0"
		},
		"dependencies": {
			"iobroker.js-controller": "stable",
			"iobroker.admin": "stable",
			"iobroker.discovery": "stable",
			"iobroker.info": "stable"
		}
	}
	EOF
)

# Create package.json and install all dependencies
PACKAGE_JSON_FILENAME="$IOB_DIR/package.json"
write_to_file "$PACKAGE_JSON_FILE" $PACKAGE_JSON_FILENAME
npm i --production --loglevel error --unsafe-perm > /dev/null

# ########################################################
print_step "Finalizing installation" 4 "$NUM_STEPS"

# Test which init system is used:
INITSYSTEM="unknown"
if [[ "$HOST_PLATFORM" = "freebsd" && -d "/usr/local/etc/rc.d" ]]; then
	INITSYSTEM="rc.d"
elif [[ `systemctl` =~ -\.mount ]] &> /dev/null; then
	INITSYSTEM="systemd"
elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
	INITSYSTEM="init.d"
elif [[ "$HOST_PLATFORM" = "osx" ]]; then
	INITSYSTEM="launchctl"
	PLIST_FILE_LABEL="org.ioBroker.LaunchAtLogin"
	SERVICE_FILENAME="/Users/${IOB_USER}/Library/LaunchAgents/${PLIST_FILE_LABEL}.plist"
fi
if [[ $IOB_FORCE_INITD && ${IOB_FORCE_INITD-x} ]]; then
	INITSYSTEM="init.d"
fi
echo "init system: $INITSYSTEM" >> $INSTALLER_INFO_FILE

# #############################
# Create "iob" and "iobroker" executables
# If possible, try to always execute the iobroker CLI as the correct user
IOB_NODE_CMDLINE="node"
if [ "$IOB_USER" != "$USER" ]; then
	IOB_NODE_CMDLINE="sudo -H -u $IOB_USER node"
fi
if [ "$INITSYSTEM" = "systemd" ]; then
	# systemd needs a special executable that reroutes iobroker start/stop to systemctl
	# Make sure to only use systemd when there is exactly 1 argument
	IOB_EXECUTABLE=$(cat <<- EOF
		#!$BASH_CMDLINE
		if (( \$# == 1 )) && ([ "\$1" = "start" ] || [ "\$1" = "stop" ] || [ "\$1" = "restart" ]); then
			sudo systemctl \$1 iobroker
		elif [ "\$1" = "fix" ]; then
			curl -sL $FIXER_URL | bash -
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
	)
elif [ "$INITSYSTEM" = "launchctl" ]; then
	# launchctl needs unload service to stop iobroker
	IOB_EXECUTABLE=$(cat <<- EOF
		#!$BASH_CMDLINE
		if (( \$# == 1 )) && ([ "\$1" = "start" ]); then
			launchctl load -w $SERVICE_FILENAME
		elif (( \$# == 1 )) && ([ "\$1" = "stop" ]); then
			launchctl unload -w $SERVICE_FILENAME
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js stop
		elif [ "\$1" = "fix" ]; then
			curl -sL $FIXER_URL | bash -
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
	)
else
	IOB_EXECUTABLE=$(cat <<- EOF
		#!$BASH_CMDLINE
		if [ "\$1" = "fix" ]; then
			curl -sL $FIXER_URL | bash -
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
	)
fi
if [ "$HOST_PLATFORM" = "linux" ]; then
	IOB_BIN_PATH=/usr/bin
elif [ "$HOST_PLATFORM" = "freebsd" ] || [ "$HOST_PLATFORM" = "osx" ]; then
	IOB_BIN_PATH=/usr/local/bin
fi

# Symlink the global binaries iob and iobroker
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iob
# Symlink the local binary iob
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_DIR/iob

# Create executables in the ioBroker directory
# TODO: check if this must be fixed like in in the FIXER for #216
write_to_file "$IOB_EXECUTABLE" $IOB_DIR/iobroker
make_executable "$IOB_DIR/iobroker"

# TODO: check if this is necessary, like in the FIXER
## and give them the correct ownership
#change_owner $IOB_USER "$IOB_DIR/iobroker"
#change_owner $IOB_USER "$IOB_DIR/iob"

# #############################
# Enable autostart
# From https://unix.stackexchange.com/questions/18209/detect-init-system-using-the-shell/326213
	# if [[ `/sbin/init --version` =~ upstart ]]; then echo using upstart;
	# elif [[ `systemctl` =~ -\.mount ]]; then echo using systemd;
	# elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then echo using sysv-init;
	# else echo cannot tell; fi

# Enable autostart
if [[ "$INITSYSTEM" = "init.d" ]]; then
	echo "Enabling autostart..."

	# Write a script into init.d that automatically detects the correct node executable and runs ioBroker
	INITD_FILE=$(cat <<- EOF
		#!$BASH_CMDLINE
		### BEGIN INIT INFO
		# Provides:          iobroker.sh
		# Required-Start:    \$network \$local_fs \$remote_fs
		# Required-Stop:     \$network \$local_fs \$remote_fs
		# Should-Start:      redis-server
		# Should-Stop:       redis-server
		# Default-Start:     2 3 4 5
		# Default-Stop:      0 1 6
		# Short-Description: starts ioBroker
		# Description:       starts ioBroker
		### END INIT INFO
		PIDF=$CONTROLLER_DIR/lib/iobroker.pid
		NODECMD=\$(which node)
		RETVAL=0

		start() {
			echo -n "Starting ioBroker"
			su - $IOB_USER -s "$BASH_CMDLINE" -c "\$NODECMD $CONTROLLER_DIR/iobroker.js start"
			RETVAL=\$?
		}

		stop() {
			echo -n "Stopping ioBroker"
			su - $IOB_USER -s "$BASH_CMDLINE" -c "\$NODECMD $CONTROLLER_DIR/iobroker.js stop"
			RETVAL=\$?
		}
		if [ "\$1" = "start" ]; then
			start
		elif [ "\$1" = "stop" ]; then
			stop
		elif [ "\$1" = "restart" ]; then
			stop
			start
		else
			echo "Usage: iobroker \{start\|stop\|restart\}"
			exit 1
		fi
		exit \$RETVAL
		EOF
	)

	# Create the startup file, give it the correct permissions and start ioBroker
	SERVICE_FILENAME="/etc/init.d/iobroker.sh"
	write_to_file "$INITD_FILE" $SERVICE_FILENAME
	set_root_permissions $SERVICE_FILENAME
	$SUDOX bash $SERVICE_FILENAME

	echo "Autostart enabled!"
	# Remember what we did
	if [[ $IOB_FORCE_INITD && ${IOB_FORCE_INITD-x} ]]; then
		echo "Autostart: init.d (forced)" >> "$INSTALLER_INFO_FILE"
	else
		echo "Autostart: init.d" >> "$INSTALLER_INFO_FILE"
	fi
elif [ "$INITSYSTEM" = "systemd" ]; then
	echo "Enabling autostart..."

	# Write an systemd service that automatically detects the correct node executable and runs ioBroker
	SYSTEMD_FILE=$(cat <<- EOF
		[Unit]
		Description=ioBroker Server
		Documentation=http://iobroker.net
		After=network.target redis.service influxdb.service mysql-server.service mariadb-server.service
		Wants=redis.service influxdb.service mysql-server.service mariadb-server.service

		[Service]
		Type=simple
		User=$IOB_USER
		Environment="NODE=\$(which node)"
		ExecStart=$BASH_CMDLINE -c '\${NODE} $CONTROLLER_DIR/controller.js'
		Restart=on-failure

		[Install]
		WantedBy=multi-user.target
		EOF
	)

	# Create the startup file and give it the correct permissions
	SERVICE_FILENAME="/lib/systemd/system/iobroker.service"
	write_to_file "$SYSTEMD_FILE" $SERVICE_FILENAME
	if [ "$IS_ROOT" != true ]; then
		sudo chown root:$ROOT_GROUP $SERVICE_FILENAME
	fi
	$SUDOX chmod 644 $SERVICE_FILENAME
	$SUDOX systemctl daemon-reload
	$SUDOX systemctl enable iobroker
	$SUDOX systemctl start iobroker
	echo "Autostart enabled!"
	echo "Autostart: systemd" >> "$INSTALLER_INFO_FILE"

elif [ "$INITSYSTEM" = "rc.d" ]; then
	echo "Enabling autostart..."

	PIDFILE="$CONTROLLER_DIR/lib/iobroker.pid"

	# Write an rc.d service that automatically detects the correct node executable and runs ioBroker
	RCD_FILE=$(cat <<- EOF
		#!$BASH_CMDLINE
		#
		# PROVIDE: iobroker
		# REQUIRE: DAEMON
		# KEYWORD: shutdown

		. /etc/rc.subr

		name="iobroker"
		rcvar="iobroker_enable"

		load_rc_config \$name

		iobroker_enable=\${iobroker_enable-"NO"}
		iobroker_pidfile=\${iobroker_pidfile-"$PIDFILE"}

		iobroker_start()
		{
			iobroker start
		}

		iobroker_stop()
		{
			iobroker stop
		}

		iobroker_status()
		{
			iobroker status
		}

		PATH="\${PATH}:/usr/local/bin"
		pidfile="\${iobroker_pidfile}"

		start_cmd=iobroker_start
		stop_cmd=iobroker_stop
		status_cmd=iobroker_status

		run_rc_command "\$1"
		EOF
	)

	# Create the startup file, give it the correct permissions and start ioBroker
	SERVICE_FILENAME="/usr/local/etc/rc.d/iobroker"
	write_to_file "$RCD_FILE" $SERVICE_FILENAME
	set_root_permissions $SERVICE_FILENAME

	# Make sure that $IOB_USER may access the pidfile
	$SUDOX touch "$PIDFILE"
	$SUDOX chown $IOB_USER:$IOB_USER $PIDFILE

	# Enable startup and start the service
	sysrc iobroker_enable=YES
	service iobroker start

	echo "Autostart enabled!"
	echo "Autostart: rc.d" >> "$INSTALLER_INFO_FILE"

elif [ "$INITSYSTEM" = "launchctl" ]; then
	echo "Enabling autostart..."

	NODECMD=$(which node)
	# osx use launchd.plist init system.
	PLIST_FILE=$(cat <<- EOF
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
			<key>Label</key>
			<string>${PLIST_FILE_LABEL}</string>
			<key>ProgramArguments</key>
			<array>
				<string>${NODECMD}</string>
				<string>${CONTROLLER_DIR}/iobroker.js</string>
				<string>start</string>
			</array>
			<key>KeepAlive</key>
			<true/>
			<key>RunAtLoad</key>
			<true/>
			<key>EnvironmentVariables</key>
			<dict>
				<key>PATH</key>
				<string>/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin</string>
			</dict>
		</dict>
		</plist>
		EOF
	)

	# Create the startup file, give it the correct permissions and start ioBroker
	echo "$PLIST_FILE" > $SERVICE_FILENAME

	# Enable startup and start the service
	launchctl list ${PLIST_FILE_LABEL} &> /dev/null
	if [ $? -eq 0 ]; then
		echo "Reloading service ${PLIST_FILE_LABEL}"
		launchctl unload -w $SERVICE_FILENAME
	fi
	launchctl load -w $SERVICE_FILENAME

	echo "Autostart enabled!"
	echo "Autostart: launchctl" >> "$INSTALLER_INFO_FILE"

else
	echo "${yellow}Unsupported init system, cannot enable autostart!${normal}"
	echo "Autostart: false" >> "$INSTALLER_INFO_FILE"
fi

# Raspbery image has as last line in /etc/rc.local the ioBroker installer. It must be removed
if [ -f /etc/rc.local ]; then
	if [ -w /etc/rc.local ]; then
		if [ "$IS_ROOT" != true ]; then
			sudo sed -i 's/curl -sLf https:\/\/iobroker.net\/install\.sh | bash -//g' /etc/rc.local
		else
			sed -i 's/curl -sLf https:\/\/iobroker.net\/install\.sh | bash -//g' /etc/rc.local
		fi
	fi
fi

# Enable auto-completion for ioBroker commands
enable_cli_completions

# Test again which platform this script is being run on
# This is necessary because FreeBSD does crazy stuff
get_platform_params

# Make sure that the app dir belongs to the correct user
# Don't do it on OSX, because we'll install as the current user anyways
if [ "$HOST_PLATFORM" != "osx" ]; then
	fix_dir_permissions
fi
# Force npm to run as iobroker when inside IOB_DIR
if [[ "$IS_ROOT" != true && "$USER" != "$IOB_USER" ]]; then
	change_npm_command_user
fi
change_npm_command_root

unset AUTOMATED_INSTALLER

# Detect IP address
IP=$(detect_ip_address)
print_bold "${green}ioBroker was installed successfully${normal}" "Open http://$IP:8081 in a browser and start configuring!"

print_msg "${yellow}You need to re-login before doing anything else on the console!${normal}"
exit 0
