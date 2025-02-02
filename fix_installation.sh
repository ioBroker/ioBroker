#!/usr/bin/env bash

# Increase this version number whenever you update the fixer
FIXER_VERSION="205-02-02" # format YYYY-MM-DD

export DEBIAN_FRONTEND=noninteractive

compress_jsonl_databases() {
    echo "Checking for uncompressed JSONL databases... This might take a while!"
    echo ""

    NPMV=$(npm -v | cut -d. -f1);
    # depending on the npm version the npx call needs to be different
    if [ $NPMV -lt 7 ]; then
        (cd "$IOB_DIR/iobroker-data" && sudo -H -u iobroker npx @iobroker/jsonltool@latest)
        (cd "$IOB_DIR")
    else
        (sudo -H -u iobroker npm x --yes @iobroker/jsonltool@latest "$IOB_DIR/iobroker-data")
    fi;
}

# Test if this script is being run as root or not
if [[ $EUID -eq 0 ]];
then IS_ROOT=true;  SUDOX=""
else IS_ROOT=false; SUDOX="sudo "; fi
ROOT_GROUP="root"
USER_GROUP="$USER"

# Check for user names and create a default user if necessary
if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then
    # Prompt for username
    echo "It seems you run ioBroker as root or the iobroker user. This is not recommended."
    echo "For security reasons a default user should be created. This user will be enabled to temporarily switch to root via 'sudo'."
    echo "A root login is not required in most Linux Distributions."
    echo "Do you want to setup a user now? (y/N)"
    read -r -s -n 1 char;
    if [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]; then
        read -p "Enter the username for a new user (Not 'root' and not 'iobroker'!): " USERNAME

        # Check if the user already exists
        if id "$USERNAME" &>/dev/null; then
            echo "User '$USERNAME' already exists. Please login as this user and restart the fixer."
            exit 1;
        else
            # Prompt for password
            read -s -p "Enter the password for the new user: " PASSWORD
            echo
            read -s -p "Confirm the password for the new user: " PASSWORD_CONFIRM
            echo

            # Check if passwords match
            if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                echo "Passwords do not match. Exiting."
                exit 1
            fi

            # Add a new user account with sudo access, set the password and grant iobroker group access to ~/iobroker
            echo "Adding new user account...";
            $SUDOX /usr/sbin/useradd -m -s /bin/bash -G adm,dialout,sudo,audio,video,plugdev,users,iobroker "$USERNAME";
            echo "$USERNAME:$PASSWORD" | $SUDOX /usr/sbin/chpasswd;
            $SUDOX chmod 750 /home/iobroker
            echo "Please login with this newly created user account and restart the fixer.";
            exit 1;
        fi;
    fi;
fi;

# Check and fix boot.target on systemd

if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
	if [[ $(systemctl get-default) == "graphical.target" ]]; then
        echo -e "\nYour system is booting into 'graphical.target', which means that a user interface or desktop is available. Usually a server is running without a desktop to have more RAM available. Do you want to switch to 'multi-user.target'? (y/N)";
        read -r -s -n 1 char;
		if [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]; then
			# Set up multi-user.target
            echo "New boot target is multi-user now! The system needs to be restarted. Please restart the fixer afterwards.";
			sudo systemctl set-default multi-user.target;
		fi;
	fi;
fi;

# Check and fix timezone

TIMEZONE=$(timedatectl show --property=Timezone --value)
if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then

    if [[ $TIMEZONE == *Etc/UTC* ]] || [[ $TIMEZONE == *Europe/London* ]]; then
        echo "Timezone '$TIMEZONE' is probably wrong. Do you want to reconfigure it? (y/N)"
        read -r -s -n 1 char;
        if [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]; then
            if [[ -f "/usr/sbin/dpkg-reconfigure" ]]; then
                sudo dpkg-reconfigure tzdata;
            else
                # Setup the timezone for the server (Default value is "Europe/Berlin")
                echo "Setting up timezone";
                read -r -p "Enter the timezone for the server (default is Europe/Berlin): " TIMEZONE;
                TIMEZONE=${TIMEZONE:-"Europe/Berlin"};
                $(sudo timedatectl set-timezone "$TIMEZONE");
            fi;
            # Set up time synchronization with systemd-timesyncd
            echo "Setting up time synchronization with systemd-timesyncd"
            $(sudo systemctl enable systemd-timesyncd);
            $(sudo systemctl start systemd-timesyncd);
        fi;
    fi;
fi;

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
if pgrep "^io(broker\.|\.)" &> /dev/null ; then
	echo "ioBroker or some processes are still running:"
	pgrep -l "^io(broker\.|\.)";
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

NUM_STEPS=5

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"

# update repos
$SUDOX $INSTALL_CMD $INSTALL_CMD_UPD_ARGS update

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

cd $IOB_DIR || exit;

# Disable any warnings related to "npm audit fix"
disable_npm_audit

# Disable any information related to npm updates
disable_npm_updatenotifier

# Enable auto-completion for ioBroker commands
enable_cli_completions

# Enforce strict version checks before installing new packages
force_strict_npm_version_checks

# Force npm to run as iobroker when inside IOB_DIR
if [[ "$IS_ROOT" != true && "$USER" != "$IOB_USER" ]]; then
	change_npm_command_user
fi
change_npm_command_root

# Make sure that the app dir belongs to the correct user
fix_dir_permissions

# ########################################################
print_step "Check and cleanup npm temporary directories" 3 "$NUM_STEPS"

# check for npm left over temporary directories
$SUDOX find "$IOB_DIR/node_modules" -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \; &> /dev/null
echo "Done."

# ########################################################
print_step "Database maintenance" 4 "$NUM_STEPS"

# Compress the JSONL database - if needed
compress_jsonl_databases

# ########################################################
print_step "Checking autostart" 5 "$NUM_STEPS"

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
elif [[ $(systemctl) =~ -\.mount ]] &> /dev/null; then
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
            if [ "\$(id -u)" = 0 ] && [[ "\$*" != *--allow-root* ]]; then
                echo -e "\n***For security reasons ioBroker should not be run or administrated as root.***\nBy default only a user that is member of "iobroker" group can execute ioBroker commands.\nPlease execute 'iob fix'to create an appropriate setup!"
            fi;
			sudo systemctl \$1 iobroker
			exit \$?
		fi
		if [ "\$(id -u)" = 0 ] && [[ "\$*" != *--allow-root* ]]; then
			echo -e "\n***For security reasons ioBroker should not be run or administrated as root.***\nBy default only a user that is member of "iobroker" group can execute ioBroker commands.\nPlease read the Documentation on how to set up such a user, if not done yet.\nOnly in very special cases you can run iobroker commands by adding the "--allow-root" option at the end of the command line.\nPlease note that this option may be disabled in the future, so please change your setup accordingly now."
			exit 1;
		elif [ "\$(id -u)" -gt 0 ] && [ "\$*" = "*--allow-root*" ]; then
            echo "Invalid option --allow-root";
            exit 1;
        fi;
		if [ "\$1" = "fix" ]; then
			sudo -u $IOB_USER curl -sLf $FIXER_URL --output /home/$IOB_USER/.fix.sh && bash /home/$IOB_USER/.fix.sh "\$2"
		elif [ "\$1" = "nodejs-update" ]; then
			sudo -u $IOB_USER curl -sLf $NODE_UPDATER_URL --output /home/$IOB_USER/.nodejs-update.sh && bash /home/$IOB_USER/.nodejs-update.sh "\$2"
		elif [ "\$1" = "diag" ]; then
		  sudo -u $IOB_USER curl -sLf $DIAG_URL --output /home/$IOB_USER/.diag.sh && bash /home/$IOB_USER/.diag.sh "\$2" | sudo -u $IOB_USER tee /home/$IOB_USER/iob_diag.log
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
			sudo -u $IOB_USER curl -sLf $FIXER_URL --output /Users/$IOB_USER/.fix.sh && bash /Users/$IOB_USER/.fix.sh "\$2"
		elif [ "\$1" = "nodejs-update" ]; then
			sudo -u $IOB_USER curl -sLf $NODE_UPDATER_URL --output /Users/$IOB_USER/.nodejs-update.sh && bash /Users/$IOB_USER/.nodejs-update.sh "\$2"
		elif [ "\$1" = "diag" ]; then
		  sudo -u $IOB_USER curl -sLf $DIAG_URL --output /Users/$IOB_USER/.diag.sh && bash /Users/$IOB_USER/.diag.sh "\$2" | sudo -u $IOB_USER tee /Users/$IOB_USER/iob_diag.log
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
	)
else
	IOB_EXECUTABLE=$(cat <<- EOF
		#!$BASH_CMDLINE
        if [ "\$1" = "fix" ]; then
			sudo -u $IOB_USER curl -sLf $FIXER_URL --output /home/$IOB_USER/.fix.sh && bash /home/$IOB_USER/.fix.sh "\$2"
		elif [ "\$1" = "nodejs-update" ]; then
			sudo -u $IOB_USER curl -sLf $NODE_UPDATER_URL --output /home/$IOB_USER/.nodejs-update.sh && bash /home/$IOB_USER/.nodejs-update.sh "\$2"
		elif [ "\$1" = "diag" ]; then
		  sudo -u $IOB_USER curl -sLf $DIAG_URL --output /home/$IOB_USER/.diag.sh && bash /home/$IOB_USER/.diag.sh "\$2" | sudo -u $IOB_USER tee /home/$IOB_USER/iob_diag.log
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
		RestartSec=3s

		[Install]
		WantedBy=multi-user.target
		EOF
	)

	# Create the startup file and give it the correct permissions

	write_to_file "$SYSTEMD_FILE" $SERVICE_FILENAME
	if [ "$IS_ROOT" != true ]; then
		$SUDOX chown root:$ROOT_GROUP $SERVICE_FILENAME
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
