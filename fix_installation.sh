#!/bin/bash

# Increase this version number whenever you update the fixer
FIXER_VERSION="2020-06-15" # format YYYY-MM-DD

# Test if this script is being run as root or not
if [[ $EUID -eq 0 ]];
then IS_ROOT=true;  SUDOX=""
else IS_ROOT=false; SUDOX="sudo "; fi
ROOT_GROUP="root"
USER_GROUP="$USER"

# get and load the LIB => START
LIB_NAME="installer_library.sh"
LIB_URL="https://raw.githubusercontent.com/ioBroker/ioBroker/master/$LIB_NAME"
# get and load the LIB
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

# Test if ioBroker is installed
if [ ! -d "$IOB_DIR" ] || [ ! -d "$CONTROLLER_DIR" ]; then
	echo "ioBroker is not installed in $IOB_DIR! Cannot fix anything..."
	exit 1
fi

# Test if ioBroker is running
if ps aux | grep " io\." &> /dev/null ; then
	echo "ioBroker or some processes are still running:"
	ps aux | grep -o " io\.\w*\.[0-9]*"
	echo "Please stop them first and try again!"
	exit 1
fi

# Create the log file if it doesn't exist
if [ ! -f "$INSTALLER_INFO_FILE" ]; then
	touch $INSTALLER_INFO_FILE
	chmod 777 $INSTALLER_INFO_FILE
fi
echo "Fixer version: $FIXER_VERSION" >> $INSTALLER_INFO_FILE
echo "Fix date $(date +%F)" >> $INSTALLER_INFO_FILE


if [ "$IS_ROOT" = true ]; then
	print_bold "Welcome to the ioBroker installation fixer!" "Script version: $FIXER_VERSION"
else
	print_bold "Welcome to the ioBroker installation fixer!" "Script version: $FIXER_VERSION" "" "You might need to enter your password a couple of times."
fi

NUM_STEPS=3

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"

# update repos
$SUDOX $INSTALL_CMD update

# Determine the platform we operate on and select the installation routine/packages accordingly
install_necessary_packages

# ########################################################
print_step "Checking ioBroker user and directory permissions" 2 "$NUM_STEPS"
if [ "$USER" != "$IOB_USER" ]; then
	# Ensure the user "iobroker" exists and is in the correct groups
	if [ "$HOST_PLATFORM" = "linux" ]; then
		create_user_linux $IOB_USER
	elif [ "$HOST_PLATFORM" = "freebsd" ]; then
		create_user_freebsd $IOB_USER
	fi
fi

cd $IOB_DIR
# Disable any warnings related to "npm audit fix"
disable_npm_audit

# Enforce strict version checks before installing new packages
force_strict_npm_version_checks

if [ "$HOST_PLATFORM" = "freebsd" ]; then
	# Make sure we use the correct python binary
	set_npm_python
fi

# Force npm to run as iobroker when inside IOB_DIR
if [[ "$IS_ROOT" != true && "$USER" != "$IOB_USER" ]]; then
	change_npm_command_user
fi
change_npm_command_root

# Make sure that the app dir belongs to the correct user
fix_dir_permissions

# ########################################################
print_step "Checking autostart" 3 "$NUM_STEPS"

# First delete all possible remains of an old installation
INITD_FILE="/etc/init.d/iobroker.sh"
if [ -f "$INITD_FILE" ]; then
	$SUDOX rm "$INITD_FILE"
fi

SYSTEMD_FILE="/lib/systemd/system/iobroker.service"
if [ -f "$SYSTEMD_FILE" ]; then
	$SUDOX rm "$SYSTEMD_FILE"
	systemctl stop iobroker &> /dev/null
	$SUDOX systemctl daemon-reload
fi

RCD_FILE="/usr/local/etc/rc.d/iobroker"
if [ -f "$RCD_FILE" ]; then
	$SUDOX rm "$RCD_FILE"
	sysrc iobroker_enable-=YES
fi

PLIST_FILE_LABEL="org.ioBroker.LaunchAtLogin"
LAUNCHCTL_FILE="/Users/${IOB_USER}/Library/LaunchAgents/${PLIST_FILE_LABEL}.plist"
if [ -f "$LAUNCHCTL_FILE" ]; then
	# Enable startup and start the service
	launchctl list ${PLIST_FILE_LABEL} &> /dev/null
	if [ $? -eq 0 ]; then
		launchctl unload -w $LAUNCHCTL_FILE
	fi
	rm "$LAUNCHCTL_FILE"
fi

# Test which init system is used:
INITSYSTEM="unknown"
if [[ "$HOST_PLATFORM" = "freebsd" && -d "/usr/local/etc/rc.d" ]]; then
	INITSYSTEM="rc.d"
	SERVICE_FILENAME="/usr/local/etc/rc.d/iobroker"
elif [[ `systemctl` =~ -\.mount ]] &> /dev/null; then
	INITSYSTEM="systemd"
	SERVICE_FILENAME="/lib/systemd/system/iobroker.service"
elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
	INITSYSTEM="init.d"
	SERVICE_FILENAME="/etc/init.d/iobroker.sh"
elif [[ "$HOST_PLATFORM" = "osx" ]]; then
	INITSYSTEM="launchctl"
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
# First remove the old binaries and symlinks
$SUDOX rm -f $IOB_DIR/iobroker
$SUDOX rm -f $IOB_BIN_PATH/iobroker
$SUDOX rm -f $IOB_DIR/iob
$SUDOX rm -f $IOB_BIN_PATH/iob

# Symlink the global binaries iob and iobroker
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iob
# Symlink the local binary iob
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_DIR/iob

# Create executables in the ioBroker directory
write_to_file "$IOB_EXECUTABLE" $IOB_DIR/iobroker
make_executable "$IOB_DIR/iobroker"

# and give them the correct ownership
change_owner $IOB_USER "$IOB_DIR/iobroker"
change_owner $IOB_USER "$IOB_DIR/iob"

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
	write_to_file "$INITD_FILE" $SERVICE_FILENAME
	set_root_permissions $SERVICE_FILENAME

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

	write_to_file "$SYSTEMD_FILE" $SERVICE_FILENAME
	if [ "$IS_ROOT" != true ]; then
		sudo chown root:$ROOT_GROUP $SERVICE_FILENAME
	fi
	$SUDOX chmod 644 $SERVICE_FILENAME
	$SUDOX systemctl daemon-reload
	$SUDOX systemctl enable iobroker

	echo "Autostart enabled!"
	echo "Autostart: systemd" >> "$INSTALLER_INFO_FILE"

elif [ "$INITSYSTEM" = "rc.d" ]; then
	echo "Enabling autostart..."

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
		iobroker_pidfile=\${iobroker_pidfile-"$CONTROLLER_DIR/lib/iobroker.pid"}

		PIDF=$CONTROLLER_DIR/lib/iobroker.pid

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
	write_to_file "$RCD_FILE" $SERVICE_FILENAME
	set_root_permissions $SERVICE_FILENAME

	# Enable startup
	sysrc iobroker_enable=YES

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

print_bold "${green}Your installation was fixed successfully${normal}" "Run ${green}iobroker start${normal} to start ioBroker again!"
