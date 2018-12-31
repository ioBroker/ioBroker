#!/bin/bash

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
	text="$2"
	echo
	echo "${bold}${HLINE}${normal}"
	echo
	echo "    ${bold}${title}${normal}"
	echo "    ${text}"
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

# Test if this script is being run as root or not
# TODO: To resolve #48, running this as root should be prohibited
if [[ $EUID -eq 0 ]]; then
	IS_ROOT=true
else
	IS_ROOT=false
fi

print_bold "Welcome to the ioBroker installer!" "You might need to enter your password a couple of times."

NUM_STEPS=4

print_step "Creating ioBroker directory" 1 "$NUM_STEPS"
# ensure the directory exists and take control of it
if [ "$IS_ROOT" = true ]; then
	mkdir -p /opt/iobroker
else
	sudo mkdir -p /opt/iobroker
	sudo chown $USER:$USER -R /opt/iobroker
fi
cd /opt/iobroker

# suppress messages with manual installation steps
touch AUTOMATED_INSTALLER

print_step "Downloading installation files" 2 "$NUM_STEPS"

# download the installer files and run them
# If this script is run as root, we need the --unsafe-perm option
if [ "$IS_ROOT" = true ]; then
	npm i iobroker --loglevel error --unsafe-perm
else
	npm i iobroker --loglevel error
fi

print_step "Installing ioBroker" 3 "$NUM_STEPS"

# TODO: GH#48 Make sure we don't need sudo/root, so we can remove that and --unsafe-perm
# For now we need to run the 2nd part of the installation as root
if [ "$IS_ROOT" = true ]; then
	npm i --production --unsafe-perm
else
	sudo -H npm i --production --unsafe-perm
fi
# npm i --production # this is how it should be

print_step "Finalizing installation" 4 "$NUM_STEPS"

# Remove the file we used to suppress messages during installation
rm AUTOMATED_INSTALLER

# If we want to autostart ioBroker with systemd, enable that
if [ -f /lib/systemd/system/iobroker.service ]; then
	echo "Enabling autostart..."

	# systemd executes js-controller as the user "iobroker", 
	# so we need to give it the ownershop of /opt/iobroker
	if [ "$IS_ROOT" = true ]; then
		chown iobroker:iobroker -R /opt/iobroker
	else
		sudo chown iobroker:iobroker -R /opt/iobroker
		# To allow the current user to install adapters via the shell,
		# We need to give it access rights to the directory aswell
		sudo usermod -a -G iobroker $USER
		sudo chmod g+w /opt/iobroker
	fi

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
