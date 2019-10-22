
# ------------------------------
# Increase this version number whenever you update the fixer
# ------------------------------
INSFIX_LIB_VERSION="2019-10-22" # format YYYY-MM-DD

# ------------------------------
# test function of the library
# ------------------------------
function libloaded() { echo "$INSFIX_LIB_VERSION"; }

# ------------------------------
# functions for ioBroker Installer/Fixer
# ------------------------------

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

HLINE="=========================================================================="
enable_colored_output

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

#ADOE: IF (INSTALLER) THEN ...
	# Make sure that npm can access the .npmrc
	if [ "$HOST_PLATFORM" = "osx" ]; then
		$SUDOX chown -R $USER .npmrc
	else
		$SUDOX chown -R $USER:$USER .npmrc
	fi
#ADOE: ELSE IF (FIXER) THEN ...
	# No need to change the permissions, since we're doing that soon anyways
#ADOE: ENDIF

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

running_in_docker() {
	# Test if we're running inside a docker container
	awk -F/ '$2 == "docker"' /proc/self/cgroup | read
}

change_npm_command_user() {
	# patches the npm command for the current user (if iobroker was installed as non-root),
	# so that it is executed as `iobroker` when inside the iobroker directory
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

change_npm_command_root() {
	# patches the npm command for the ROOT user (always! (independent of which user installed iobroker)),
	# so that it is executed as `iobroker` when inside the iobroker directory
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

change_owner() {
	user="$1"
	file="$2"
	if [ "$HOST_PLATFORM" == "osx" ]; then
		owner="$user"
	else
		owner="$user:$user"
	fi
	cmdline="$SUDOX chown"
	if [ -d $file ]; then
		# recursively chown directories
		cmdline="$cmdline -R"
	elif [ -L $file ]; then
		# change ownership of symbolic links
		cmdline="$cmdline -h"
	fi
	$cmdline $owner $file
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

#ADOE: IF (INSTALLER) THEN ...
	$SUDOX rm -f $SUDOERS_FILE
#ADOE: ENDIF

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
	# Give the user access to all necessary directories
	# When autostart is enabled, we need to fix the permissions so that `iobroker` can access it
	echo "Fixing directory permissions..."

#ADOE: IF (INSTALLER) THEN ...
	$SUDOX chown -R $IOB_USER:$IOB_USER $IOB_DIR
#ADOE: ELSE IF (FIXER) THEN ...
	# ioBroker install dir
	change_owner $IOB_USER $IOB_DIR
	# and the npm cache dir
	if [ -d "/home/$IOB_USER/.npm" ]; then
		change_owner $IOB_USER "/home/$IOB_USER/.npm"
	fi
#ADOE: ENDIF

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





echo "library: loaded"
