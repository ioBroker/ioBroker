#!/bin/bash

# Increase this version number whenever you update the installer
INSTALLER_VERSION="2019-11-03" # format YYYY-MM-DD

# Test if this script is being run as root or not
if [[ $EUID -eq 0 ]];
then IS_ROOT=true;  SUDOX=""
else IS_ROOT=false; SUDOX="sudo "; fi
ROOT_GROUP="root"
USER_GROUP="$USER"

get_platform_params() {
	# Test which platform this script is being run on
	# When adding another supported platform, also add detection for the install command
	# HOST_PLATFORM:  Name of the platform
	# INSTALL_CMD:	  comand for package installation
	# IOB_DIR:	  Directory where iobroker should be installed
	# IOB_USER:	  The user to run ioBroker as
	unamestr=$(uname)
	case "$unamestr" in
	"Linux")
		HOST_PLATFORM="linux"
		INSTALL_CMD="apt-get"
		if [[ $(which "yum" 2>/dev/null) == *"/yum" ]]; then
			INSTALL_CMD="yum"
		fi
		IOB_DIR="/opt/iobroker"
		IOB_USER="iobroker"
		;;
	"Darwin")
		# OSX and Linux are the same in terms of install procedure
		HOST_PLATFORM="osx"
		ROOT_GROUP="wheel"
		INSTALL_CMD="brew"
		IOB_DIR="/usr/local/iobroker"
		IOB_USER="$USER"
		;;
	"FreeBSD")
		HOST_PLATFORM="freebsd"
		ROOT_GROUP="wheel"
		INSTALL_CMD="pkg"
		IOB_DIR="/opt/iobroker"
		IOB_USER="iobroker"
		;;
	*)
		# The following should never happen, but better be safe than sorry
		echo "Unsupported platform $unamestr"
		exit 1
		;;
	esac
	if [ "$IS_ROOT" = true ]; then
		USER_GROUP="$ROOT_GROUP"
	fi
}

install_package_linux() {
	package="$1"
	# Test if the package is installed
	dpkg -s "$package" &> /dev/null
	if [ $? -ne 0 ]; then
		if [ "$INSTALL_CMD" = "yum" ]; then
			# Install it
			errormessage=$( $SUDOX yum install -q -y $package > /dev/null 2>&1)
		else
			# Install it
			errormessage=$( $SUDOX $INSTALL_CMD install -yq --no-install-recommends $package > /dev/null 2>&1)
		fi

		# Hide "Error: Nothing to do"
		if [ "$errormessage" != "Error: Nothing to do" ]; then
			if [ "$errormessage" != "" ]; then
				echo $errormessage
			fi
			echo "Installed $package"
		fi
	fi
}

install_package_freebsd() {
	package="$1"
	# check if package is installed (pkg is nice enough to provide us with a exitcode)
	if ! $INSTALL_CMD info "$1" >/dev/null 2>&1; then
		# Install it
		$SUDOX $INSTALL_CMD install --yes --quiet "$1" > /dev/null
		echo "Installed $package"
	fi
}

install_package_macos() {
	package="$1"
	# Test if the package is installed (Use brew to install essential tools)
	$INSTALL_CMD list | grep "$package" &> /dev/null
	if [ $? -ne 0 ]; then
		# Install it
		$INSTALL_CMD install $package &> /dev/null
		if [ $? -eq 0 ]; then
			echo "Installed $package"
		else
			echo "$package was not installed"
		fi
	fi
}

install_package() {
	case "$HOST_PLATFORM" in
		"linux")
			install_package_linux $1
		;;
		"osx")
			install_package_macos $1
		;;
		"freebsd")
			install_package_freebsd $1
		;;
		# The following should never happen, but better be safe than sorry
		*)
			echo "Unsupported platform $HOST_PLATFORM"
		;;
	esac
}

disable_npm_audit() {
	# Make sure the npmrc file exists
	$SUDOX touch .npmrc
	# If .npmrc does not contain "audit=false", we need to change it
	$SUDOX grep -q -E "^audit=false" .npmrc &> /dev/null
	if [ $? -ne 0 ]; then
		# Remember its contents (minus any possible audit=true)
		NPMRC_FILE=$($SUDOX grep -v -E "^audit=true" .npmrc)
		# And write it back
		write_to_file "$NPMRC_FILE" .npmrc
		# Append the line to disable audit
		append_to_file "# disable npm audit warnings" .npmrc
		append_to_file "audit=false" .npmrc
	fi
	# Make sure that npm can access the .npmrc
	if [ "$HOST_PLATFORM" = "osx" ]; then
		$SUDOX chown -R $USER .npmrc
	else
		$SUDOX chown -R $USER:$USER_GROUP .npmrc
	fi
}

set_npm_python() {
	# Make sure the npmrc file exists
	$SUDOX touch .npmrc
	# If .npmrc does not contain "python=", we need to change it
	$SUDOX grep -q -E "^python=" .npmrc &> /dev/null
	if [ $? -ne 0 ]; then
		# Remember its contents (minus any possible audit=true)
		NPMRC_FILE=$($SUDOX grep -v -E "^python=" .npmrc)
		# And write it back
		write_to_file "$NPMRC_FILE" .npmrc
		# Append the line to change the python binary
		append_to_file "# change link from python3 to python2.7 (needed for gyp)" .npmrc
		append_to_file "python=/usr/local/bin/python2.7" .npmrc
	fi
	# Make sure that npm can access the .npmrc
	if [ "$HOST_PLATFORM" = "osx" ]; then
		$SUDOX chown -R $USER .npmrc
	else
		$SUDOX chown -R $USER:$USER_GROUP .npmrc
	fi
}

enable_colored_output() {
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
}

HLINE="=========================================================================="
enable_colored_output

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

install_nodejs() {
	print_bold "Node.js not found. Installing..."
	install_package gcc-c++
	install_package make
	install_package build-essential
	install_package curl

	if [ "$INSTALL_CMD" = "yum" ]; then
		if [ "$IS_ROOT" = true ]; then
			curl -sL https://rpm.nodesource.com/setup_10.x | bash -
		else
			curl -sL https://rpm.nodesource.com/setup_10.x | sudo -E bash -
		fi
	elif [ "$INSTALL_CMD" = "pkg" ]; then
		$SUDOX pkg install -y node
	elif [ "$INSTALL_CMD" = "brew" ]; then
		echo "${red}Cannot install Node.js using brew.${normal}"
		echo "Please download Node.js from https://nodejs.org/dist/v10.16.3/node-v10.16.3.pkg"
		echo "Then try to install ioBroker again!"
		exit 1
	else
		if [ "$IS_ROOT" = true ]; then
			curl -sL https://deb.nodesource.com/setup_10.x | bash -
		else
			curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
		fi
	fi
	install_package nodejs

	# Check if nodejs is now installed
	if [[ $(which "node" 2>/dev/null) != *"/node" ]]; then
		echo "${red}Cannot install Node.js! Please install it manually.${normal}"
		exit 1
	else
		echo "${bold}Node.js Installed successfully!${normal}"
	fi
}

detect_ip_address() {
	# Detect IP address
	local IP
	IP_COMMAND=$(type "ip" &> /dev/null && echo "ip addr show" || echo "ifconfig")
	if [ "$HOST_PLATFORM" = "osx" ]; then
		IP=$($IP_COMMAND | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -Eo "([0-9]+\.){3}[0-9]+" | head -1)
	else
		IP=$($IP_COMMAND | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -Eo "([0-9]+\.){3}[0-9]+\/[0-9]+" | cut -d "/" -f1)
	fi
	return $IP
}

# Adds dirs to the PATH variable without duplicating entries
add_to_path() {
	case ":$PATH:" in
		*":$1:"*) :;; # already there
		*) PATH="$1:$PATH";;
	esac
}

function write_to_file()  {
	echo "$1" | $SUDOX tee "$2" &> /dev/null
}
function append_to_file() {
	echo "$1" | $SUDOX tee -a "$2" &> /dev/null
}

# Test which platform this script is being run on
get_platform_params

# Check if "sudo" command is available (in case we're not root)
if [ "$IS_ROOT" != true ]; then
	if [[ $(which "sudo" 2>/dev/null) != *"/sudo" ]]; then
		echo "${red}Cannot continue because the \"sudo\" command is not available!${normal}"
		echo "Please install it first using \"$INSTALL_CMD install sudo\""
		exit 1
	fi
fi

if [ "$IS_ROOT" = "true" ]; then
	print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION"
else
	print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION" "" "You might need to enter your password a couple of times."
fi

# Starting with Debian 10 (Buster), we need to add the [/usr[/local]]/sbin
# directories to PATH for non-root users
if [ -d "/sbin" ]; then add_to_path "/sbin"; fi
if [ -d "/usr/sbin" ]; then add_to_path "/usr/sbin"; fi
if [ -d "/usr/local/sbin" ]; then add_to_path "/usr/local/sbin"; fi

CONTROLLER_DIR="$IOB_DIR/node_modules/iobroker.js-controller"
INSTALLER_INFO_FILE="$IOB_DIR/INSTALLER_INFO.txt"

# Which npm package should be installed (default "iobroker")
INSTALL_TARGET=${INSTALL_TARGET-"iobroker"}

# Where the fixer script is located
FIXER_URL="https://iobroker.net/fix.sh"

# Remember the full path of bash
BASH_CMDLINE=$(which bash)

# Test if we're running inside a docker container
running_in_docker() {
	awk -F/ '$2 == "docker"' /proc/self/cgroup | read
}


# Catch the case where a user
#	- installs ioBroker as NOT root,
#	- but later runs npm install as root
#
# The way this is handled, makes sure that both "npm install" AND "sudo npm install"
# get patched to run "npm" as the user iobroker.
# For      npm install to work, we need to patch the command for non-root, hence       ~/.bashrc.
# For sudo npm install to work, we need to patch the command for     root, hence   /root/.bashrc.

# Changes the user's npm command so it is always executed as `iobroker`
# when inside the iobroker directory
change_npm_command_user() {
	NPM_COMMAND_FIX_PATH=~/.iobroker/npm_command_fix
	NPM_COMMAND_FIX=$(cat <<- EOF
		# While inside the iobroker directory, execute npm as iobroker
		function npm() {
			__real_npm=\$(which npm)
			if [[ \$(pwd) == "$IOB_DIR"* ]]; then
				sudo -H -u $IOB_USER \$__real_npm \$*
			else
				eval \$__real_npm \$*
			fi
		}
		EOF
	)
	BASHRC_LINES=$(cat <<- EOF

		# Forces npm to run as $IOB_USER when inside the iobroker installation dir
		source ~/.iobroker/npm_command_fix
		EOF
	)

	mkdir -p ~/.iobroker
	echo "$NPM_COMMAND_FIX" > "$NPM_COMMAND_FIX_PATH"
	# Activate the change
	source "$NPM_COMMAND_FIX_PATH"

	# Make sure the bashrc file exists - it should, but you never know...
	touch ~/.bashrc
	# If .bashrc does not contain the source command, we need to add it
	sudo grep -q -E "^source ~/\.iobroker/npm_command_fix" ~/.bashrc &> /dev/null
	if [ $? -ne 0 ]; then
		echo "$BASHRC_LINES" >> ~/.bashrc
	fi
}

# Changes the root's npm command so it is always executed as `iobroker`
# when inside the iobroker directory
change_npm_command_root() {
	NPM_COMMAND_FIX_PATH=/root/.iobroker/npm_command_fix
	NPM_COMMAND_FIX=$(cat <<- EOF
		# While inside the iobroker directory, execute npm as iobroker
		function npm() {
			__real_npm=\$(which npm)
			if [[ \$(pwd) == "$IOB_DIR"* ]]; then
				sudo -H -u $IOB_USER \$__real_npm \$*
			else
				eval \$__real_npm \$*
			fi
		}
		EOF
	)
	BASHRC_LINES=$(cat <<- EOF

		# Forces npm to run as $IOB_USER when inside the iobroker installation dir
		source /root/.iobroker/npm_command_fix
		EOF
	)

	sudo mkdir -p /root/.iobroker
	write_to_file "$NPM_COMMAND_FIX" "$NPM_COMMAND_FIX_PATH"
	# Activate the change
	if [ "$IS_ROOT" = "true" ]; then
		source "$NPM_COMMAND_FIX_PATH"
	fi

	# Make sure the bashrc file exists - it should, but you never know...
	sudo touch /root/.bashrc
	# If .bashrc does not contain the source command, we need to add it
	sudo grep -q -E "^source /root/\.iobroker/npm_command_fix" /root/.bashrc &> /dev/null
	if [ $? -ne 0 ]; then
		append_to_file "$BASHRC_LINES" /root/.bashrc
	fi
}

set_root_permissions() {
	file="$1"
	$SUDOX chown root:$ROOT_GROUP $file
	$SUDOX chmod 755 $file
}

make_executable() {
	file="$1"
	$SUDOX chmod 755 $file
}

function add2sudoers() {
	local xsudoers=$1
	shift
	xarry=("$@")
	for cmd in "${xarry[@]}"; do
		# Test each command if and where it is installed
		cmd_bin=$(echo $cmd | cut -d ' ' -f1)
		cmd_path=$(which $cmd_bin 2> /dev/null)
		if [ $? -eq 0 ]; then
			# Then add the command to SUDOERS_CONTENT
			full_cmd=$(echo "$cmd" | sed -e "s|$cmd_bin|$cmd_path|")
			SUDOERS_CONTENT+=$xsudoers"NOPASSWD: $full_cmd\n"
		fi
	done
}

create_user_linux() {
	username="$1"
	id "$username" &> /dev/null;
	if [ $? -ne 0 ]; then
		# User does not exist
		$SUDOX useradd -m -s /usr/sbin/nologin "$username"
		echo "User $username created"
	fi
	# Add the current non-root user to the iobroker group so he can access the iobroker dir
	if [ "$username" != "$USER" ] && [ "$IS_ROOT" = false ]; then
		sudo usermod -a -G $username $USER
	fi

	SUDOERS_CONTENT="$username ALL=(ALL) ALL\n"
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
		"mysqldump"
		"ldconfig"
	)
	add2sudoers "$username ALL=(ALL) " "${iob_commands[@]}"

	# Additionally, define which iobroker-related commands may be executed by every user
	declare -a all_user_commands=(
		"systemctl start iobroker"
		"systemctl stop iobroker"
		"systemctl restart iobroker"
	)
	add2sudoers "ALL ALL=" "${all_user_commands[@]}"

	# Furthermore, allow all users to execute node iobroker.js as iobroker
	if [ "$IOB_USER" != "$USER" ]; then
		add2sudoers "ALL ALL=($IOB_USER) " "node $CONTROLLER_DIR/iobroker.js"
	fi

	SUDOERS_FILE="/etc/sudoers.d/iobroker"
	echo -e "$SUDOERS_CONTENT" > ~/temp_sudo_file
	$SUDOX visudo -c -q -f ~/temp_sudo_file && \
		$SUDOX chown root:$ROOT_GROUP ~/temp_sudo_file &&
		$SUDOX chmod 440 ~/temp_sudo_file &&
		$SUDOX mv ~/temp_sudo_file $SUDOERS_FILE &&
		echo "Created $SUDOERS_FILE"
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
		getent group $grp &> /dev/null && $SUDOX usermod -a -G $grp $username
	done
}

create_user_freebsd() {
	username="$1"
	id "$username" &> /dev/null
	if [ $? -ne 0 ]; then
		# User does not exist
		$SUDOX pw useradd -m -s /usr/sbin/nologin -n "$username"
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
		getent group $grp && $SUDOX pw group mod $grp -m $username
	done
}

fix_dir_permissions() {
	# When autostart is enabled, we need to fix the permissions so that `iobroker` can access it
	echo "Fixing directory permissions..."
	$SUDOX chown -R $IOB_USER:$IOB_USER $IOB_DIR
	if [ "$IS_ROOT" != true ]; then
		sudo usermod -a -G $IOB_USER $USER
	fi
	# Give the iobroker group write access to all files by setting the default ACL
	$SUDOX setfacl -Rdm g:$IOB_USER:rwx $IOB_DIR &> /dev/null && $SUDOX setfacl -Rm g:$IOB_USER:rwx $IOB_DIR &> /dev/null
	if [ $? -ne 0 ]; then
		# We cannot rely on default permissions on this system
		echo "${yellow}This system does not support setting default permissions.${normal}"
		echo "${yellow}Do not use npm to manually install adapters unless you know what you are doing!${normal}"
		echo "ACL enabled: false" >> $INSTALLER_INFO_FILE
	else
		echo "ACL enabled: true" >> $INSTALLER_INFO_FILE
	fi
}


export AUTOMATED_INSTALLER="true"
NUM_STEPS=4

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"

# update repos
$SUDOX $INSTALL_CMD update

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
# TODO: Which other packages do we need by default?
install_necessary_packages() {
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
			"python-dev" # To fix npm error: ImportError: No module named compiler.ast
		)
		for pkg in "${packages[@]}"; do
			install_package $pkg
		done

		# ==================
		# Configure packages

		# Give nodejs access to protected ports and raw devices like ble
		cmdline="$SUDOX setcap"

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
			install_package $pkg
		done
		# we need to do some setting up things after installing the packages
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
		$INSTALL_CMD -v &> /dev/null
		if [ $? -eq 0 ]; then
			declare -a packages=(
				# These are used by a couple of adapters and should therefore exist:
				"pkg-config"
				"git"
				"curl"
				"unzip"
			)
			for pkg in "${packages[@]}"; do
				install_package $pkg
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
}
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

if [ "$HOST_PLATFORM" = "freebsd" ]; then
	# Make sure we use the correct python binary
	set_npm_python
fi

# download the installer files and run them
# If this script is run as root, we need the --unsafe-perm option
if [ "$IS_ROOT" = true ]; then
	echo "Installed as root" >> $INSTALLER_INFO_FILE
	npm i $INSTALL_TARGET --loglevel error --unsafe-perm > /dev/null
else
	echo "Installed as non-root user $USER" >> $INSTALLER_INFO_FILE
	npm i $INSTALL_TARGET --loglevel error > /dev/null
fi

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
