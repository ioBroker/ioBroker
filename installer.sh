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

HLINE="================================================================"

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

print_bold "Welcome to the ioBroker installer!" "You might need to enter your password a couple of times."

NUM_STEPS=4

print_step "Creating ioBroker directory" 1 "$NUM_STEPS"
# ensure the directory exists and take control of it
sudo mkdir -p /opt/iobroker
sudo chown $USER -R /opt/iobroker
cd /opt/iobroker

# suppress messages with manual installation steps
export AUTOMATED_INSTALLER="true"

print_step "Downloading installation files" 2 "$NUM_STEPS"

# download the installer files and run them
npm i https://github.com/AlCalzone/ioBroker/tarball/install-v2

print_step "Installing ioBroker" 3 "$NUM_STEPS"

# TODO: GH#48 Make sure we don't need sudo, so we can remove that and --unsafe-perm
sudo npm i --production --unsafe-perm
# npm i --production # this is how it should be
# Because we used sudo, we now need to take control again
sudo chown $USER -R /opt/iobroker

print_step "Finalizing installation" 4 "$NUM_STEPS"

# If we want to autostart ioBroker with systemd, enable that
if [ -f /lib/systemd/system/iobroker.service ];
then
	# We cannot use sudo here because it will fail silently otherwise
	echo "Enabling autostart..."
	systemctl daemon-reload
	systemctl enable iobroker
	systemctl start iobroker
	echo "Autostart enabled!"
fi

print_msg "ioBroker was installed successfully"