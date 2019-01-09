#!/bin/bash

# Increase this version number whenever you update the installer
INSTALLER_VERSION="2019-01-02" # format YYYY-MM-DD

# Test if this script is being run as root or not
# TODO: To resolve #48, running this as root should be prohibited
if [[ $EUID -eq 0 ]]; then
	IS_ROOT=true
else
	IS_ROOT=false
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

create_user() {
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
	# Add the user to all groups we need
	# and give him passwordless sudo privileges
	# TODO: replace NOPASSWD:ALL with a list of commands iobroker may execute
	if [ "$IS_ROOT" = true ]; then
		usermod -a -G bluetooth,dialout,gpio,tty "$username"
		echo "$username ALL=(ALL) NOPASSWD:ALL" | (EDITOR="tee" visudo -f /etc/sudoers.d/iobroker)
	else
		sudo usermod -a -G bluetooth,dialout,gpio,tty "$username"
		echo "$username ALL=(ALL) NOPASSWD:ALL" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/iobroker')
	fi
}

install_package() {
	package="$1"
	# Test if the package is installed
	dpkg -s "$package" &> /dev/null
	if [ $? -ne 0 ]; then
		# Install it
		if [ "$IS_ROOT" = true ]; then
			apt install -y package
		else
			sudo apt install -y package
		fi
	fi
}

print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION" "" "You might need to enter your password a couple of times."

NUM_STEPS=5

print_step "Installing prerequisites" 1 "$NUM_STEPS"
install_package "acl"  # To use setfacl
install_package "sudo" # To use sudo (obviously)
# TODO: Which other packages do we need by default?

print_step "Creating ioBroker directory" 2 "$NUM_STEPS"
# Ensure the user "iobroker" exists and is in the correct groups
create_user "iobroker"
# ensure the directory exists and take control of it
if [ "$IS_ROOT" = true ]; then
	mkdir -p /opt/iobroker
else
	sudo mkdir -p /opt/iobroker
	sudo chown $USER:$USER -R /opt/iobroker
fi
cd /opt/iobroker

# Log some information about the installer
echo "Installer version: $INSTALLER_VERSION" >> INSTALLER_INFO.txt
echo "Installation date $(date +%F)" >> INSTALLER_INFO.txt

# suppress messages with manual installation steps
touch AUTOMATED_INSTALLER

print_step "Downloading installation files" 3 "$NUM_STEPS"

# download the installer files and run them
# If this script is run as root, we need the --unsafe-perm option
if [ "$IS_ROOT" = true ]; then
	echo "Installed as root" >> INSTALLER_INFO.txt
	npm i iobroker --loglevel error --unsafe-perm
else
	echo "Installed as non-root user $USER" >> INSTALLER_INFO.txt
	npm i iobroker --loglevel error
fi

print_step "Installing ioBroker" 4 "$NUM_STEPS"

# TODO: GH#48 Make sure we don't need sudo/root, so we can remove that and --unsafe-perm
# For now we need to run the 2nd part of the installation as root
if [ "$IS_ROOT" = true ]; then
	npm i --production --unsafe-perm
else
	sudo -H npm i --production --unsafe-perm
fi
# npm i --production # this is how it should be

print_step "Finalizing installation" 5 "$NUM_STEPS"

# Remove the file we used to suppress messages during installation
rm AUTOMATED_INSTALLER

# If we want to autostart ioBroker with systemd, enable that
if [ -f /lib/systemd/system/iobroker.service ]; then
	# systemd executes js-controller as the user "iobroker", 
	# so we need to give it the ownershop of /opt/iobroker
	echo "Fixing directory permissions..."
	if [ "$IS_ROOT" = true ]; then
		chown iobroker:iobroker -R /opt/iobroker
		# No need to give special permissions, root has access anyways
	else
		sudo chown iobroker:iobroker -R /opt/iobroker
		# To allow the current user to install adapters via the shell,
		# We need to give it access rights to the directory aswell
		sudo usermod -a -G iobroker $USER
		# Give the iobroker group write access to all files by setting the default ACL
		sudo setfacl -Rdm g:iobroker:rwx /opt/iobroker &> /dev/null && sudo setfacl -Rm g:iobroker:rwx /opt/iobroker &> /dev/null
		if [ $? -ne 0 ]; then
			# We cannot rely on default permissions on this system
			echo "${yellow}This system does not support setting default permissions."
			echo "${yellow}Do not use npm to manually install adapters unless you know what you are doing!"
			echo "ACL enabled: false" >> INSTALLER_INFO.txt
		fi
	fi

	echo "Enabling autostart..."
	if [ "$IS_ROOT" = true ]; then
		systemctl daemon-reload
		systemctl enable iobroker
		systemctl start iobroker
	else
		sudo systemctl daemon-reload
		sudo systemctl enable iobroker
		sudo systemctl start iobroker
	fi
	echo "Autostart enabled!"
else
	# After sudo npm i, this directory now belongs to root. 
	# Give it back to the current user
	# TODO: remove this step when GH#48 is resolved
	sudo chown $USER:$USER -R /opt/iobroker
fi

print_bold "${green}ioBroker was installed successfully${normal}" "Open http://localhost:8081 in a browser and start configuring!"

print_msg "${yellow}You need to re-login before doing anything else on the console!"
