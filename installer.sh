#!/bin/bash

# Increase this version number whenever you update the installer
INSTALLER_VERSION="2019-01-15" # format YYYY-MM-DD

# Test if this script is being run as root or not
# TODO: To resolve #48, running this as root should be prohibited
if [[ $EUID -eq 0 ]]; then
	IS_ROOT=true
else
	IS_ROOT=false
fi
ROOT_GROUP="root"
# Test which platform this script is being run on
unamestr=$(uname)
if [ "$unamestr" = "Linux" ]; then
	platform="linux"
elif [ "$unamestr" = "Darwin" ]; then
	# OSX and Linux are the same in terms of install procedure
	platform="osx"
	ROOT_GROUP="wheel"
elif [ "$unamestr" = "FreeBSD" ]; then
	platform="freebsd"
	ROOT_GROUP="wheel"
else
	echo "Unsupported platform!"
	exit 1
fi

# Directory where iobroker should be installed
IOB_DIR="/opt/iobroker"
if [ "$platform" = "osx" ]; then
	IOB_DIR="/usr/local/iobroker"
fi
CONTROLLER_DIR="$IOB_DIR/node_modules/iobroker.js-controller"

# Which npm package should be installed (default "iobroker")
INSTALL_TARGET=${INSTALL_TARGET-"iobroker"}

# The user to run ioBroker as
IOB_USER="iobroker"
if [ "$platform" = "osx" ]; then
	IOB_USER="$USER"
fi

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
	fi
	# Add the user to all groups we need and give him passwordless sudo privileges
	# Define which commands may be executed as sudo without password
	# TODO: Do we need others?
	SUDOERS_CONTENT=$(cat <<- EOF
		$username	ALL=(ALL)	ALL
		$username	ALL=(ALL)	NOPASSWD: `which shutdown` -h now, `which halt`, `which poweroff`, `which reboot`
		$username	ALL=(ALL)	NOPASSWD: `which systemctl` start, `which systemctl` stop
		$username	ALL=(ALL)	NOPASSWD: `which mount` -o nosuid\,nodev\,noexec, `which umount`, `which mount`
		$username	ALL=(ALL)	NOPASSWD: `which apt-get`, `which apt`, `which dpkg`, `which make`
		$username	ALL=(ALL)	NOPASSWD: `which ping`, `which fping`, `which arp-scan`
		$username	ALL=(ALL)	NOPASSWD: `which setcap`
		EOF
	)
	SUDOERS_FILE="/etc/sudoers.d/iobroker"
	if [ "$IS_ROOT" = true ]; then
		echo "$SUDOERS_CONTENT" > ./temp_sudo_file
		visudo -c -q -f ./temp_sudo_file && \
			chown root:$ROOT_GROUP ./temp_sudo_file &&
			chmod 440 ./temp_sudo_file &&
			mv ./temp_sudo_file $SUDOERS_FILE
	else
		echo "$SUDOERS_CONTENT" > ./temp_sudo_file
		sudo visudo -c -q -f ./temp_sudo_file && \
			sudo chown root:$ROOT_GROUP ./temp_sudo_file &&
			sudo chmod 440 ./temp_sudo_file &&
			sudo mv ./temp_sudo_file $SUDOERS_FILE
	fi
	# Add the user to all groups if they exist
	declare -a groups=(
		bluetooth
		dialout
		gpio
		tty
	)
	for grp in "${groups[@]}"; do
		if [ "$IS_ROOT" = true ]; then
			getent group $grp && usermod -a -G $grp $username
		else
			getent group $grp && sudo usermod -a -G $grp $username
		fi
	done
}
create_user_freebsd() {
	username="$1"
	id "$username" &> /dev/null
	if [ $? -ne 0 ]; then
		# User does not exist
		if [ "$IS_ROOT" = true ]; then
			pw useradd -m -s /usr/sbin/nologin "$username"
		else
			sudo pw useradd -m -s /usr/sbin/nologin "$username"
		fi
	fi
	# Add the user to all groups we need and give him passwordless sudo privileges
	# Define which commands may be executed as sudo without password
	# TODO: Find out the correct paths on FreeBSD
	# SUDOERS_FILE="/usr/local/etc/sudoers.d/iobroker"

	# Add the user to all groups if they exist
	declare -a groups=(
		bluetooth
		dialout
		gpio
		tty
	)
	for grp in "${groups[@]}"; do
		if [ "$IS_ROOT" = true ]; then
			getent group $grp && pw usermod -a -G $grp $username
		else
			getent group $grp && sudo pw usermod -a -G $grp $username
		fi
	done
}

install_package() {
	package="$1"
	# Test if the package is installed
	dpkg -s "$package" &> /dev/null
	if [ $? -ne 0 ]; then
		# Install it
		if [ "$IS_ROOT" = true ]; then
			apt install -y $package
		else
			sudo apt install -y $package
		fi
	fi
}

print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION" "" "You might need to enter your password a couple of times."

export AUTOMATED_INSTALLER="true"
NUM_STEPS=5

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"
if [ "$platform" != "osx" ]; then
	install_package "acl"  # To use setfacl
	install_package "sudo" # To use sudo (obviously)
	# These are used by a couple of adapters and should therefore exist:
	install_package "build-essential"
	install_package "libavahi-compat-libdnssd-dev"
	install_package "libudev-dev"
	install_package "libpam0g-dev"
	install_package "pkg-config"
	install_package "git"
	install_package "curl"
	install_package "unzip"
fi
# TODO: Which other packages do we need by default?

# ########################################################
print_step "Creating ioBroker user and directory" 2 "$NUM_STEPS"
# Ensure the user "iobroker" exists and is in the correct groups
if [ "$platform" = "linux" ]; then
	create_user_linux $IOB_USER
elif [ "$platform" = "freebsd" ]; then
	create_user_freebsd $IOB_USER
fi

# Ensure the installation directory exists and take control of it
if [ "$IS_ROOT" = true ]; then
	mkdir -p $IOB_DIR
else
	sudo mkdir -p $IOB_DIR
	# During the installation we need to give the current user access to the install dir
	# On Linux, we'll fix this at the end. On OSX this is okay
	if [ "$platform" = "osx" ]; then
		sudo chown -R $USER $IOB_DIR
	else
		sudo chown -R $USER:$USER $IOB_DIR
	fi
fi
cd $IOB_DIR

# Log some information about the installer
touch INSTALLER_INFO.txt
chmod 777 INSTALLER_INFO.txt
echo "Installer version: $INSTALLER_VERSION" >> INSTALLER_INFO.txt
echo "Installation date $(date +%F)" >> INSTALLER_INFO.txt


# ########################################################
print_step "Downloading installation files" 3 "$NUM_STEPS"

# download the installer files and run them
# If this script is run as root, we need the --unsafe-perm option
if [ "$IS_ROOT" = true ]; then
	echo "Installed as root" >> INSTALLER_INFO.txt
	npm i $INSTALL_TARGET --loglevel error --unsafe-perm
else
	echo "Installed as non-root user $USER" >> INSTALLER_INFO.txt
	npm i $INSTALL_TARGET --loglevel error
fi


# ########################################################
print_step "Installing ioBroker" 4 "$NUM_STEPS"
npm i --production --loglevel error --unsafe-perm


print_step "Finalizing installation" 5 "$NUM_STEPS"

# #############################
# Create "iob" and "iobroker" executables
IOB_EXECUTABLE=$(cat <<- EOF
	#!/bin/bash
	node $CONTROLLER_DIR/iobroker.js \$1 \$2 \$3 \$4 \$5
	EOF
)
if [ "$platform" = "linux" ]; then
	IOB_BIN_PATH=/usr/bin
elif [ "$platform" = "freebsd" ] || [ "$platform" = "osx" ]; then
	IOB_BIN_PATH=/usr/local/bin
fi
# Create executables in the ioBroker directory
echo "$IOB_EXECUTABLE" > $IOB_DIR/iobroker
make_executable "$IOB_DIR/iobroker"
echo "$IOB_EXECUTABLE" > $IOB_DIR/iob
make_executable "$IOB_DIR/iob"
# Symlink the binaries there
if [ "$IS_ROOT" = true ]; then
	ln -s $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
	ln -s $IOB_DIR/iob $IOB_BIN_PATH/iob
else
	sudo ln -s $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
	sudo ln -s $IOB_DIR/iob $IOB_BIN_PATH/iob
fi


# #############################
# Enable autostart
# From https://unix.stackexchange.com/questions/18209/detect-init-system-using-the-shell/326213
	# if [[ `/sbin/init --version` =~ upstart ]]; then echo using upstart;
	# elif [[ `systemctl` =~ -\.mount ]]; then echo using systemd;
	# elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then echo using sysv-init;
	# else echo cannot tell; fi

# Test which init system is used:
INITSYSTEM="unknown"
if [[ "$platform" = "freebsd" && -d "/usr/local/etc/rc.d" ]]; then
	INITSYSTEM="rc.d"
elif [[ `systemctl` =~ -\.mount ]] &> /dev/null; then 
	INITSYSTEM="systemd"
elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
	INITSYSTEM="init.d"
fi
echo "init system: $INITSYSTEM" >> INSTALLER_INFO.txt

fix_dir_permissions() {
	# When autostart is enabled, we need to fix the permissions so that `iobroker` can access it
	echo "Fixing directory permissions..."
	if [ "$IS_ROOT" = true ]; then
		chown -R $IOB_USER:$IOB_USER $IOB_DIR
		# No need to give special permissions, root has access anyways
	else
		sudo chown -R $IOB_USER:$IOB_USER $IOB_DIR
		# To allow the current user to install adapters via the shell,
		# We need to give it access rights to the directory aswell
		sudo usermod -a -G $IOB_USER $USER
		# Give the iobroker group write access to all files by setting the default ACL
		sudo setfacl -Rdm g:$IOB_USER:rwx $IOB_DIR &> /dev/null && sudo setfacl -Rm g:$IOB_USER:rwx $IOB_DIR &> /dev/null
		if [ $? -ne 0 ]; then
			# We cannot rely on default permissions on this system
			echo "${yellow}This system does not support setting default permissions.${normal}"
			echo "${yellow}Do not use npm to manually install adapters unless you know what you are doing!${normal}"
			echo "ACL enabled: false" >> INSTALLER_INFO.txt
		else
			echo "ACL enabled: true" >> INSTALLER_INFO.txt
		fi
	fi
}

# Enable autostart
if [[ $IOB_FORCE_INITD && ${IOB_FORCE_INITD-x} || "$INITSYSTEM" = "init.d" ]]; then
	echo "Enabling autostart..."

	# Write a script into init.d that automatically detects the correct node executable and runs ioBroker
	INITD_FILE=$(cat <<- EOF
		#!/bin/bash
		### BEGIN INIT INFO
		# Provides:          iobroker.sh
		# Required-Start:    \$network \$local_fs \$remote_fs
		# Required-Stop::    \$network \$local_fs \$remote_fs
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
			su - $IOB_USER -s "/bin/bash" -c "\$NODECMD $CONTROLLER_DIR/iobroker.js start"
			RETVAL=\$?
		}

		stop() {
			echo -n "Stopping ioBroker"
			su - $IOB_USER -s "/bin/bash" -c "\$NODECMD $CONTROLLER_DIR/iobroker.js stop"
			RETVAL=\$?
		}
		case \$1 in
		start^\)
			start \;\;
		stop\)
			stop \;\;
		restart\)
			stop
			start \;\;
		*\)
			echo "Usage: iobroker \{start\|stop\|restart\}"
			exit 1 \;\;
		esac
		exit \$RETVAL
		EOF
	)

	# Create the startup file, give it the correct permissions and start ioBroker
	SERVICE_FILENAME="/etc/init.d/iobroker.sh"
	if [ "$IS_ROOT" = true ]; then
		echo "$INITD_FILE" > $SERVICE_FILENAME
		set_root_permissions $SERVICE_FILENAME
		bash $SERVICE_FILENAME
	else
		echo "$INITD_FILE" | sudo tee $SERVICE_FILENAME &> /dev/null
		set_root_permissions $SERVICE_FILENAME
		sudo bash $SERVICE_FILENAME
	fi
	# Remember what we did
	if [ -z ${IOB_FORCE_INITD+x} ]; then
		echo "Autostart: init.d (forced)" >> INSTALLER_INFO.txt
	else
		echo "Autostart: init.d" >> INSTALLER_INFO.txt
	fi
elif [ "$INITSYSTEM" = "systemd" ]; then
	echo "Enabling autostart..."

	# Write an systemd service that automatically detects the correct node executable and runs ioBroker
	SYSTEMD_FILE=$(cat <<- EOF
		[Unit]
		Description=ioBroker Server
		Documentation=http://iobroker.net
		After=network.target
		
		[Service]
		Type=simple
		User=$IOB_USER
		Environment="NODE=\$(which node)"
		ExecStart=/bin/bash -c '\${NODE} $CONTROLLER_DIR/controller.js'
		Restart=on-failure
		
		[Install]
		WantedBy=multi-user.target
		EOF
	)

	# Create the startup file and give it the correct permissions
	SERVICE_FILENAME="/lib/systemd/system/iobroker.service"
	if [ "$IS_ROOT" = true ]; then
		echo "$SYSTEMD_FILE" > $SERVICE_FILENAME
		chmod 644 $SERVICE_FILENAME

		systemctl daemon-reload
		systemctl enable iobroker
		systemctl start iobroker
	else
		echo "$SYSTEMD_FILE" | sudo tee $SERVICE_FILENAME &> /dev/null
		sudo chown root:$ROOT_GROUP $SERVICE_FILENAME
		sudo chmod 644 $SERVICE_FILENAME

		sudo systemctl daemon-reload
		sudo systemctl enable iobroker
		sudo systemctl start iobroker
	fi
	echo "Autostart enabled!"
	echo "Autostart: systemd" >> INSTALLER_INFO.txt

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
		NODECMD=\$(which node)

		iobroker_start ()
		{
			su -m $IOB_USER -s "/bin/bash" -c "\${NODECMD} ${CONTROLLER_DIR}/iobroker.js start"
		}

		iobroker_stop ()
		{
			su -m $IOB_USER -s "/bin/bash" -c "\${NODECMD} ${CONTROLLER_DIR}/iobroker.js stop"
		}

		iobroker_status ()
		{
			su -m $IOB_USER -s "/bin/bash" -c "\${NODECMD} ${CONTROLLER_DIR}/iobroker.js status"
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
	if [ "$IS_ROOT" = true ]; then
		echo "$RCD_FILE" > $SERVICE_FILENAME
	else
		echo "$RCD_FILE" | sudo tee $SERVICE_FILENAME &> /dev/null
	fi
	set_root_permissions $SERVICE_FILENAME

	# Enable startup and start the service
	sysrc iobroker_enable=YES
	service iobroker start

else
	echo "${yellow}Unsupported init system, cannot enable autostart!${normal}"
	echo "Autostart: false" >> INSTALLER_INFO.txt
fi

# Make sure that the app dir belongs to the correct user
# Don't do it on OSX, because we'll install as the current user anyways
if [ "$platform" != "osx" ]; then
	fix_dir_permissions
fi

unset AUTOMATED_INSTALLER

# Detect IP address
IP_COMMAND=$(type "ip" 2> /dev/null && echo "ip addr show" || echo "ifconfig")
IP=$($IP_COMMAND | grep inet | grep -v inet6 | grep -v 127.0.0.1 | cut -d " " -f2 | cut -d "/" -f1)
print_bold "${green}ioBroker was installed successfully${normal}" "Open http://$IP:8081 in a browser and start configuring!"

print_msg "${yellow}You need to re-login before doing anything else on the console!${normal}"
exit 0
