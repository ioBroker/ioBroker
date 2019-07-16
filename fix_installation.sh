#!/bin/bash

# Increase this version number whenever you update the fixer
FIXER_VERSION="2019-07-03" # format YYYY-MM-DD

# Test if this script is being run as root or not
if [[ $EUID -eq 0 ]]; then
	IS_ROOT=true
else
	IS_ROOT=false
fi
ROOT_GROUP="root"
# Test which platform this script is being run on
unamestr=$(uname)
if [ "$unamestr" = "Linux" ]; then
	HOST_PLATFORM="linux"
elif [ "$unamestr" = "Darwin" ]; then
	# OSX and Linux are the same in terms of install procedure
	HOST_PLATFORM="osx"
	ROOT_GROUP="wheel"
elif [ "$unamestr" = "FreeBSD" ]; then
	HOST_PLATFORM="freebsd"
	ROOT_GROUP="wheel"
else
	echo "Unsupported platform!"
	exit 1
fi

# Directory where iobroker should be installed
IOB_DIR="/opt/iobroker"
if [ "$HOST_PLATFORM" = "osx" ]; then
	IOB_DIR="/usr/local/iobroker"
fi
CONTROLLER_DIR="$IOB_DIR/node_modules/iobroker.js-controller"
INSTALLER_INFO_FILE="$IOB_DIR/INSTALLER_INFO.txt"

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

# The user to run ioBroker as
IOB_USER="iobroker"
if [ "$HOST_PLATFORM" = "osx" ]; then
	IOB_USER="$USER"
fi

# Where the fixer script is located
FIXER_URL="https://iobroker.net/fix.sh"

# Test if we're running inside a docker container
running_in_docker() {
	awk -F/ '$2 == "docker"' /proc/self/cgroup | read
}

# Enable colored output
if test -t 1; then # if terminal
	ncolors=$(which tput > /dev/null && tput colors) # supports color
	if test -n "$ncolors" && test $ncolors -ge 8; then
		termcols=$(tput cols)
		bold="$(tput bold)"
		underline="$(tput smul)"
		standout="$(tput smso)"
		normal="$(tput sgr0)"
		black="$(tput setaf 0)"
		red="$(tput setaf 1)"
		green="$(tput setaf 2)"
		yellow="$(tput setaf 3)"
		blue="$(tput setaf 4)"
		magenta="$(tput setaf 5)"
		cyan="$(tput setaf 6)"
		white="$(tput setaf 7)"
	fi
fi

HLINE="=========================================================================="

print_step() {
	stepname="$1"
	stepnr="$2"
	steptotal="$3"

	echo
	echo "${bold}${HLINE}${normal}"
	echo "${bold}    ${stepname} ${blue}(${stepnr}/${steptotal})${normal}"
	echo "${bold}${HLINE}${normal}"
	echo
}

print_bold() {
	title="$1"
	echo
	echo "${bold}${HLINE}${normal}"
	echo
	echo "    ${bold}${title}${normal}"
	for text in "${@:2}"; do
		echo "    ${text}"
	done
	echo
	echo "${bold}${HLINE}${normal}"
	echo
}


print_msg() {
	text="$1"
	echo
	echo -e "${text}"
	echo
}

set_root_permissions() {
	file="$1"
	if [ "$IS_ROOT" = true ]; then
		chown root:$ROOT_GROUP $file
		chmod 755 $file
	else
		sudo chown root:$ROOT_GROUP $file
		sudo chmod 755 $file
	fi
}

make_executable() {
	file="$1"
	if [ "$IS_ROOT" = true ]; then
		chmod 755 $file
	else
		sudo chmod 755 $file
	fi
}

change_owner() {
	user="$1"
	file="$2"
	if [ "$HOST_PLATFORM" == "osx" ]; then
		owner="$user"
	else
		owner="$user:$user"
	fi
	cmdline="chown"
	if [ "$IS_ROOT" != true ]; then
		# use sudo as non-root
		cmdline="sudo $cmdline"
	fi
	if [ -d $file ]; then
		# recursively chown directories
		cmdline="$cmdline -R"
	elif [ -L $file ]; then
		# change ownership of symbolic links
		cmdline="$cmdline -h"
	fi
	$cmdline $owner $file
}

create_user_linux() {
	username="$1"
	id "$username" &> /dev/null;
	if [ $? -ne 0 ]; then
		# User does not exist
		if [ "$IS_ROOT" = true ]; then
			useradd -m -s /usr/sbin/nologin "$username"
		else
			sudo useradd -m -s /usr/sbin/nologin "$username"
		fi
		echo "User $username created"
	fi
	# Add the current non-root user to the iobroker group so he can access the iobroker dir
	if [ "$username" != "$USER" ] && [ "$IS_ROOT" = false ]; then
		sudo usermod -a -G $username $USER
	fi

	# Add the user to all groups we need and give him passwordless sudo privileges
	# Define which commands iobroker may execute as sudo without password
	declare -a iob_commands=(
		"shutdown -h now" "halt" "poweroff" "reboot"
		"systemctl start" "systemctl stop"
		"mount" "umount" "systemd-run"
		"apt-get" "apt" "dpkg" "make"
		"ping" "fping"
		"arp-scan"
		"setcap"
		"vcgencmd"
		"cat"
		"df"
	)

	SUDOERS_CONTENT="$username ALL=(ALL) ALL\n"
	for cmd in "${iob_commands[@]}"; do
		# Test each command if and where it is installed
		cmd_bin=$(echo $cmd | cut -d ' ' -f1)
		cmd_path=$(which $cmd_bin 2> /dev/null)
		if [ $? -eq 0 ]; then
			# Then add the command to SUDOERS_CONTENT
			full_cmd=$(echo "$cmd" | sed -e "s|$cmd_bin|$cmd_path|")
			SUDOERS_CONTENT+="$username ALL=(ALL) NOPASSWD: $full_cmd\n"
		fi
	done

	# Additionally, define which iobroker-related commands may be executed by every user
	declare -a all_user_commands=(
		"systemctl start iobroker"
		"systemctl stop iobroker"
		"systemctl restart iobroker"
	)
	for cmd in "${all_user_commands[@]}"; do
		# Test each command if and where it is installed
		cmd_bin=$(echo $cmd | cut -d ' ' -f1)
		cmd_path=$(which $cmd_bin 2> /dev/null)
		if [ $? -eq 0 ]; then
			# Then add the command to SUDOERS_CONTENT
			full_cmd=$(echo "$cmd" | sed -e "s|$cmd_bin|$cmd_path|")
			SUDOERS_CONTENT+="ALL ALL=NOPASSWD: $full_cmd\n"
		fi
	done

	# Furthermore, allow all users to execute node iobroker.js as iobroker
	if [ "$IOB_USER" != "$USER" ]; then
		cmd="node $CONTROLLER_DIR/iobroker.js"
		cmd_bin=$(echo $cmd | cut -d ' ' -f1)
		cmd_path=$(which $cmd_bin 2> /dev/null)
		if [ $? -eq 0 ]; then
			# Then add the command to SUDOERS_CONTENT
			full_cmd=$(echo "$cmd" | sed -e "s|$cmd_bin|$cmd_path|")
			SUDOERS_CONTENT+="ALL ALL=($IOB_USER) NOPASSWD: $full_cmd\n"
		fi
	fi
	# TODO: ^ Can we reduce code repetition in these 3 blocks? ^

	SUDOERS_FILE="/etc/sudoers.d/iobroker"
	if [ "$IS_ROOT" = true ]; then
		rm -f $SUDOERS_FILE
		echo -e "$SUDOERS_CONTENT" > ~/temp_sudo_file
		visudo -c -q -f ~/temp_sudo_file && \
			chown root:$ROOT_GROUP ~/temp_sudo_file &&
			chmod 440 ~/temp_sudo_file &&
			mv ~/temp_sudo_file $SUDOERS_FILE &&
			echo "Created $SUDOERS_FILE"
	else
		sudo rm -f $SUDOERS_FILE
		echo -e "$SUDOERS_CONTENT" > ~/temp_sudo_file
		sudo visudo -c -q -f ~/temp_sudo_file && \
			sudo chown root:$ROOT_GROUP ~/temp_sudo_file &&
			sudo chmod 440 ~/temp_sudo_file &&
			sudo mv ~/temp_sudo_file $SUDOERS_FILE &&
			echo "Created $SUDOERS_FILE"
	fi
	# Add the user to all groups if they exist
	declare -a groups=(
		audio
		bluetooth
		dialout
		gpio
		i2c
		redis
		tty
	)
	for grp in "${groups[@]}"; do
		if [ "$IS_ROOT" = true ]; then
			getent group $grp &> /dev/null && usermod -a -G $grp $username
		else
			getent group $grp &> /dev/null && sudo usermod -a -G $grp $username
		fi
	done
}

create_user_freebsd() {
	username="$1"
	id "$username" &> /dev/null
	if [ $? -ne 0 ]; then
		# User does not exist
		if [ "$IS_ROOT" = true ]; then
			pw useradd -m -s /usr/sbin/nologin -n "$username"
		else
			sudo pw useradd -m -s /usr/sbin/nologin -n "$username"
		fi
	fi
	# Add the user to all groups we need and give him passwordless sudo privileges
	# Define which commands may be executed as sudo without password
	# TODO: Find out the correct paths on FreeBSD
	# SUDOERS_FILE="/usr/local/etc/sudoers.d/iobroker"

	# Add the user to all groups if they exist
	declare -a groups=(
		audio
		bluetooth
		dialout
		gpio
		i2c
		redis
		tty
	)
	for grp in "${groups[@]}"; do
		if [ "$IS_ROOT" = true ]; then
			getent group $grp && pw group mod $grp -m $username
		else
			getent group $grp && sudo pw group mod $grp -m $username
		fi
	done
}

install_package_linux() {
	package="$1"
	# Test if the package is installed
	dpkg -s "$package" &> /dev/null
	if [ $? -ne 0 ]; then
		# Install it
		if [ "$IS_ROOT" = true ]; then
			apt-get install -yq --no-install-recommends $package > /dev/null
		else
			sudo apt-get install -yq --no-install-recommends $package > /dev/null
		fi
		echo "Installed $package"
	fi
}

install_package_freebsd() {
	package="$1"
	# check if package is installed (pkg is nice enough to provide us with a exitcode)
	if ! pkg info "$1" >/dev/null 2>&1; then
		# Install it
		if [ "$IS_ROOT" = true ]; then
			pkg install --yes --quiet "$1" > /dev/null
		else
			sudo pkg install --yes --quiet "$1" > /dev/null
		fi
		echo "Installed $package"
	fi
}

install_package_macos() {
	package="$1"
	# Test if the package is installed (Use brew to install essential tools)
	brew list | grep "$package" &> /dev/null
	if [ $? -ne 0 ]; then
		# Install it
		brew install $package &> /dev/null
		if [ $? -eq 0 ]; then
			echo "Installed $package"
		else
			echo "$package was not installed"
		fi
	fi
}


fix_dir_permissions() {
	# Give the user access to all necessary directories
	echo "Fixing directory permissions..."
	# ioBroker install dir
	change_owner $IOB_USER $IOB_DIR
	# and the npm cache dir
	if [ -d "/home/$IOB_USER/.npm" ]; then
		change_owner $IOB_USER "/home/$IOB_USER/.npm"
	fi
	if [ "$IS_ROOT" != true ]; then
		# To allow the current user to install adapters via the shell,
		# We need to give it access rights to the directory aswell
		sudo usermod -a -G $IOB_USER $USER
	fi
	# Give the iobroker group write access to all files by setting the default ACL
	if [ "$IS_ROOT" = true ]; then
		setfacl -Rdm g:$IOB_USER:rwx $IOB_DIR &> /dev/null && setfacl -Rm g:$IOB_USER:rwx $IOB_DIR &> /dev/null
	else
		sudo setfacl -Rdm g:$IOB_USER:rwx $IOB_DIR &> /dev/null && sudo setfacl -Rm g:$IOB_USER:rwx $IOB_DIR &> /dev/null
	fi
	if [ $? -ne 0 ]; then
		# We cannot rely on default permissions on this system
		echo "${yellow}This system does not support setting default permissions.${normal}"
		echo "${yellow}Do not use npm to manually install adapters unless you know what you are doing!${normal}"
		echo "ACL enabled: false" >> $INSTALLER_INFO_FILE
	else
		echo "ACL enabled: true" >> $INSTALLER_INFO_FILE
	fi
}

print_bold "Welcome to the ioBroker installation fixer!" "Script version: $FIXER_VERSION" "" "You might need to enter your password a couple of times."

NUM_STEPS=3

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"
# Determine the platform we operate on and select the installation routine/packages accordingly 
case "$HOST_PLATFORM" in
	"linux")
		declare -a packages=(
			"acl" # To use setfacl
			"sudo" # To use sudo (obviously)
			"libcap2-bin" # To give nodejs access to protected ports
			# These are used by a couple of adapters and should therefore exist:
			"build-essential"
			"libavahi-compat-libdnssd-dev"
			"libudev-dev"
			"libpam0g-dev"
			"pkg-config"
			"git"
			"curl"
			"unzip"
		)
		for pkg in "${packages[@]}"; do
			install_package_linux $pkg
		done

		# ==================
		# Configure packages

		# Give nodejs access to protected ports and raw devices like ble
		cmdline="setcap"
		if [ "$IS_ROOT" != true ]; then
			# use sudo as non-root
			cmdline="sudo $cmdline"
		fi
	
		if running_in_docker; then
			capabilities=$(grep ^CapBnd /proc/$$/status)
			if [[ $(capsh --decode=${capabilities:(-16)}) == *"cap_net_admin"* ]]; then
				$cmdline 'cap_net_admin,cap_net_bind_service,cap_net_raw+eip' $(eval readlink -f `which node`)
			else
				$cmdline 'cap_net_bind_service,cap_net_raw+eip' $(eval readlink -f `which node`)
				echo "${yellow}Docker detected!"
				echo "If you have any adapters that need the CAP_NET_ADMIN capability,"
				echo "you need to start the docker container with the option --cap-add=NET_ADMIN"
				echo "and manually add that capability to node${normal}"
			fi
		else
			$cmdline 'cap_net_admin,cap_net_bind_service,cap_net_raw+eip' $(eval readlink -f `which node`)
		fi
		;;
	"freebsd")
		declare -a packages=(
			"sudo"
			"git"
			"curl"
			"bash"
			"unzip"
			"avahi-libdns" # avahi gets installed along with this
			"dbus"
			"nss_mdns" # needed for the mdns host resolution 
			"gcc"
			"python" # Required for node-gyp compilation
		)
		for pkg in "${packages[@]}"; do
			install_package_freebsd $pkg
		done
		# we need to do some settting up things after installing the packages
		# ensure dns_sd.h is where node-gyp expect it 
		ln -s /usr/local/include/avahi-compat-libdns_sd/dns_sd.h /usr/include/dns_sd.h
		# enable dbus in the avahi configuration
		sed -i -e 's/#enable-dbus/enable-dbus/' /usr/local/etc/avahi/avahi-daemon.conf
		# enable mdns usage for host resolution
		sed -i -e 's/hosts: file dns/hosts: file dns mdns/' /etc/nsswitch.conf

		# enable services avahi/dbus
		sysrc -f /etc/rc.conf dbus_enable="YES"
		sysrc -f /etc/rc.conf avahi_daemon_enable="YES"

		# start services
		service dbus start
		service avahi-daemon start
		;;
	"osx")
		# Test if brew is installed. If it is, install some packages that are often used.
		brew -v &> /dev/null
		if [ $? -eq 0 ]; then
			declare -a packages=(
				# These are used by a couple of adapters and should therefore exist:
				"pkg-config"
				"git"
				"curl"
				"unzip"
			)
			for pkg in "${packages[@]}"; do
				install_package_macos $pkg
			done
		else
			echo "${yellow}Since brew is not installed, frequently-used dependencies could not be installed."
			echo "Before installing some adapters, you might have to install some packages yourself."
			echo "Please check the adapter manuals before installing them.${normal}"
		fi
		;;
	*)
		;;
esac

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

# Make sure that the app dir belongs to the correct user
# Don't do it on OSX, because we'll install as the current user anyways
if [ "$HOST_PLATFORM" != "osx" ]; then
	fix_dir_permissions
fi

# ########################################################
print_step "Checking autostart" 3 "$NUM_STEPS"

# First delete all possible remains of an old installation
INITD_FILE="/etc/init.d/iobroker.sh"
if [ -f "$INITD_FILE" ]; then
	if [ "$IS_ROOT" = true ]; then
		rm "$INITD_FILE"
	else
		sudo rm "$INITD_FILE"
	fi
fi

SYSTEMD_FILE="/lib/systemd/system/iobroker.service"
if [ -f "$SYSTEMD_FILE" ]; then
	if [ "$IS_ROOT" = true ]; then
		rm "$SYSTEMD_FILE"
		systemctl stop iobroker &> /dev/null
		systemctl daemon-reload
	else
		sudo rm "$SYSTEMD_FILE"
		systemctl stop iobroker &> /dev/null
		sudo systemctl daemon-reload
	fi
fi

RCD_FILE="/usr/local/etc/rc.d/iobroker"
if [ -f "$RCD_FILE" ]; then
	if [ "$IS_ROOT" = true ]; then
		rm "$RCD_FILE"
	else
		sudo rm "$RCD_FILE"
	fi
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
BASH_CMDLINE=$(which bash)
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
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js \$@
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
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js \$@
		fi
		EOF
	)
else
	IOB_EXECUTABLE=$(cat <<- EOF
		#!$BASH_CMDLINE
		if [ "\$1" = "fix" ]; then
			curl -sL $FIXER_URL | bash -
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js \$@
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
if [ "$IS_ROOT" = true ]; then
	rm -f $IOB_DIR/iobroker 
	rm -f $IOB_BIN_PATH/iobroker
	rm -f $IOB_DIR/iob
	rm -f $IOB_BIN_PATH/iob
else
	sudo rm -f $IOB_DIR/iobroker 
	sudo rm -f $IOB_BIN_PATH/iobroker
	sudo rm -f $IOB_DIR/iob
	sudo rm -f $IOB_BIN_PATH/iob
fi

# Symlink the global binaries iob and iobroker
if [ "$IS_ROOT" = true ]; then
	ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
	ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iob
else
	sudo ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
	sudo ln -sfn $IOB_DIR/iob $IOB_BIN_PATH/iob
fi
# Symlink the local binary iob
if [ "$IS_ROOT" = true ]; then
	ln -sfn $IOB_DIR/iobroker $IOB_DIR/iob
else
	sudo ln -sfn $IOB_DIR/iobroker $IOB_DIR/iob
fi
# Create executables in the ioBroker directory
echo "$IOB_EXECUTABLE" > $IOB_DIR/iobroker
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
	if [ "$IS_ROOT" = true ]; then
		echo "$INITD_FILE" > $SERVICE_FILENAME
		set_root_permissions $SERVICE_FILENAME
	else
		echo "$INITD_FILE" | sudo tee $SERVICE_FILENAME &> /dev/null
		set_root_permissions $SERVICE_FILENAME
	fi
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
		After=network.target redis.service
		Wants=redis.service
		
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
	if [ "$IS_ROOT" = true ]; then
		echo "$SYSTEMD_FILE" > $SERVICE_FILENAME
		chmod 644 $SERVICE_FILENAME

		systemctl daemon-reload
		systemctl enable iobroker
	else
		echo "$SYSTEMD_FILE" | sudo tee $SERVICE_FILENAME &> /dev/null
		sudo chown root:$ROOT_GROUP $SERVICE_FILENAME
		sudo chmod 644 $SERVICE_FILENAME

		sudo systemctl daemon-reload
		sudo systemctl enable iobroker
	fi
	echo "Autostart enabled!"
	echo "Autostart: systemd" >> "$INSTALLER_INFO_FILE"

elif [ "$INITSYSTEM" = "rc.d" ]; then
	echo "Enabling autostart..."

	# Write an rc.d service that automatically detects the correct node executable and runs ioBroker
	RCD_FILE=$(cat <<- EOF
		#!/bin/sh
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
		NODECMD=\`which node\`

		iobroker_start ()
		{
			su -m $IOB_USER -s "$BASH_CMDLINE" -c "\${NODECMD} ${CONTROLLER_DIR}/iobroker.js start"
		}

		iobroker_stop ()
		{
			su -m $IOB_USER -s "$BASH_CMDLINE" -c "\${NODECMD} ${CONTROLLER_DIR}/iobroker.js stop"
		}

		iobroker_status ()
		{
			su -m $IOB_USER -s "$BASH_CMDLINE" -c "\${NODECMD} ${CONTROLLER_DIR}/iobroker.js status"
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
	if [ "$IS_ROOT" = true ]; then
		echo "$RCD_FILE" > $SERVICE_FILENAME
	else
		echo "$RCD_FILE" | sudo tee $SERVICE_FILENAME &> /dev/null
	fi
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
