#!/bin/bash
# iobroker nodejs-update
# written to help updating and fixing nodejs on linux (Debian based Distros)

#To be manually changed:
VERSION="2026-01-23"
NODE_MAJOR=22 #recommended major nodejs version for ioBroker, please adjust if the recommendation changes. This the target when no other option is set.

# Check if version option is a valid one
if [[ -z "$1" ]]; then
    echo "No specific version given, installing recommended version from nodejs v.$NODE_MAJOR tree"
    sleep 2
elif [ "$1" -ge 18 ]; then
    echo "Valid major version. CUSTOM installation of nodejs v$1"
    sleep 2
else
    echo -e "Only give a major nodejs version number like this: \niob nodejs-update $NODE_MAJOR"
    exit 1
fi

## Excluding systems:
SYSTDDVIRT=$(systemd-detect-virt 2>/dev/null)
DOCKER=/opt/scripts/.docker_config/.thisisdocker #used to identify docker
DEBIANRELEASE=$(cat /etc/debian_version)

if [ -f "$DOCKER" ]; then
    echo "Updating Node.js in Docker is not supported, please update your Docker Container"
    unset LC_ALL
    exit 1
elif [ "$(id -u)" -eq 0 ]; then
    echo -e "This script must not be run as root! \nPlease use your standard user!"
    unset LC_ALL
    exit 1
fi

if [[ $SYSTDDVIRT = "wsl" ]]; then
    echo "WSL is not supported."
    unset LC_ALL
    exit 1
fi

if [ -z "$(type -P apt-get)" ]; then
    echo "Only a Debian-based Linux is supported"
    unset LC_ALL
    exit 1
fi

if [[ $DEBIANRELEASE = *buster* ]] || [[ $DEBIANRELEASE = 10.* ]] && [[ $1 -ne 18 ]]; then
    echo -e "Debian 10 'Buster' has reached End of Life and is not supported anymore.\nRecent versions of nodejs won't run.\nPlease install the current Debian Stable"
    unset LC_ALL
    exit 1
fi

### Starting the skript
echo -e "ioBroker nodejs-update v$VERSION is starting. Please be patient!"
HOST=$(hostname)
NODERECOM=$(iobroker state getValue system.host."$HOST".versions.nodeNewestNext) #reading node version from iob states. If successful, no fallback required.
if [[ $NODERECOM != [[:digit:]]*.[[:digit:]]*.[[:digit:]]* ]]; then              #check if a semvered nodejs installation is found
    NODERECOMNF=1                                                                #marker for 'no recommended version found'
fi
NODEINSTMAJOR=$(nodejs -v | cut -d. -f1 | cut -c 2-3) #truncating installed nodejs version to major version
export LC_ALL=C                                       #setting LOCALES temporary to english

#CUSTOM INSTALLATION
if [[ -n $1 ]]; then
    NODE_MAJOR=$1
    NODERECOM=CUSTOM
fi
# ------------------------------
# functions for ioBroker nodejs-update - Code borrowed from 'iob installer' ;-)
# ------------------------------

# Error handler function
handle_error() {
  local exit_code=$1
  local error_message="$2"
  log "Error: $error_message (Exit Code: $exit_code)" "error"
  exit "$exit_code"
}

# Function to check for command availability
command_exists() {
  command -v "$1" &> /dev/null
}

check_os() {
    if ! [ -f "/etc/debian_version" ]; then
        echo "Error: This script is only supported on Debian-based systems."
        exit 1
    fi
}

# INSTALL NODEJS
nodejs_installation() {
    echo -e "\nInstalling latest nodejs v$NODE_MAJOR release"
    $SUDOX $INSTALL_CMD -qq update
    $SUDOX $INSTALL_CMD -qq --allow-downgrades upgrade nodejs
    VERNODE=$(node -v)
    echo -e "\n\033[32mSUCCESS!\033[0m"
    echo -e "$VERNODE has been installed! You are using the latest nodejs@$NODE_MAJOR release now!"
}

# COMPATIBILITY CHECK
compatibility_check() {
    echo -e "\nCOMPATIBILITY CHECK IN PROGRESS (Only a --dry-run! No modules are really changed or added!)"
    cd /opt/iobroker || exit
    npm i --dry-run
}

# RESTART IOBROKER
restart_iob() {
    echo -e "\n\nWe tried our best to fix your nodejs. Please run iob diag again to verify."
    echo -e "\n*** RESTARTING ioBroker NOW! *** \n Please refresh or restart your browser in a few moments."
    iob restart
}

# Test which platform this script is being run on
# When adding another supported platform, also add detection for the install command
# HOST_PLATFORM:  Name of the platform
# INSTALL_CMD:      comand for package installation
# INSTALL_CMD_ARGS: arguments for $INSTALL_CMD to install something
# INSTALL_CMD_UPD_ARGS: arguments for $INSTALL_CMD to update something
# IOB_DIR:        Directory where iobroker should be installed
# IOB_USER:       The user to run ioBroker as

unamestr=$(uname)
case "$unamestr" in
"Linux")
    HOST_PLATFORM="linux"
    INSTALL_CMD="apt-get"
    INSTALL_CMD_ARGS="install"
    if [[ $(which "yum" 2>/dev/null) == *"/yum" ]]; then
        INSTALL_CMD="yum"
        # The args -y and -q have to be separate
        INSTALL_CMD_ARGS="install -q -y"
    fi
    IOB_DIR="/opt/iobroker"
    IOB_USER="iobroker"
    ;;
"Darwin")
    # OSX and Linux are the same in terms of install procedure
    HOST_PLATFORM="osx"
    ROOT_GROUP="wheel"
    INSTALL_CMD="brew"
    INSTALL_CMD_ARGS="install"
    IOB_DIR="/usr/local/iobroker"
    IOB_USER="$USER"
    ;;
"FreeBSD")
    HOST_PLATFORM="freebsd"
    ROOT_GROUP="wheel"
    INSTALL_CMD="pkg"
    INSTALL_CMD_ARGS="install"
    IOB_DIR="/opt/iobroker"
    IOB_USER="iobroker"
    ;;
*)
    # The following should never happen, but better be safe than sorry
    echo "Unsupported platform $unamestr"
    exit 1
    ;;
esac

if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
    SUDOX=""
else
    IS_ROOT=false
    SUDOX="sudo "
    ROOT_GROUP="root"
    USER_GROUP="$USER"
fi

if
    [[ "$INSTALL_CMD" != "apt-get" ]]
then
    echo "Non-Debian-based Systems are not supported, exiting"
    unset LC_ALL
    exit
fi

DFSGREM="$SUDOX $INSTALL_CMD remove libnode* node-* nodejs-doc npm -qqy" #Deinstall DFSG-Version

clear
echo -e "ioBroker nodejs fixer $VERSION"

if [[ -n "$NODERECOM" ]] && [[ "$NODERECOM" = [[:digit:]]*.[[:digit:]]*.[[:digit:]]* ]]; then
    echo -e "\nRecommended nodejs-version is: $NODERECOM"
    echo "Checking your installation now. Please be patient!"
elif
    [[ "$NODERECOM" == CUSTOM ]]
then
    echo -e "You requested to install latest version from nodejs v$1 tree."
else
    NODERECOMNF=1
    echo -e "No recommendation for a nodejs version found on your system. We recommend to install latest version from nodejs v$NODE_MAJOR tree."
fi
echo ""
echo "Your current setup is:"

if [[ -f /usr/bin/nodejs ]]; then
    echo -e "$(type -p nodejs) \t$(nodejs -v)"
fi
echo -e "$(type -p node) \t\t$(node -v)"
echo -e "$(type -p npm) \t\t$(npm -v)"
echo -e "$(type -p npx) \t\t$(npx -v)"

PATHNODEJS=$(type -p nodejs)
PATHNODE=$(type -p node)
PATHNPM=$(type -p npm)
PATHNPX=$(type -p npx)

if [[ -f /usr/bin/nodejs ]]; then
    VERNODEJS=$(nodejs -v)
fi

VERNODE=$(node -v)
VERNPM=$(npm -v)
VERNPX=$(npx -v)
NOTCORRSTRG="\n\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
if
    [[ -f /usr/bin/nodejs && "$PATHNODEJS" != "/usr/bin/nodejs" ]]
then
    NODENOTCORR=1
    echo -e "$NOTCORRSTRG"
elif
    [[ "$PATHNODE" != "/usr/bin/node" ]]
then
    NODENOTCORR=1
    echo -e "$NOTCORRSTRG"
elif
    [[ "$PATHNPM" != "/usr/bin/npm" ]]
then
    NODENOTCORR=1
    echo -e "$NOTCORRSTRG"
elif
    [[ "$PATHNPX" != "/usr/bin/npx" ]]
then
    NODENOTCORR=1
    echo -e "$NOTCORRSTRG"
elif
    [[ -f /usr/bin/nodejs && "$VERNODEJS" != "$VERNODE" ]]
then
    NODENOTCORR=1
    echo -e "$NOTCORRSTRG"
elif
    [[ "$VERNPM" != "$VERNPX" ]]
then
    NODENOTCORR=1
    echo -e "$NOTCORRSTRG"
else
    echo ""
fi
echo "We found these nodejs versions available for installation:"
echo ""
apt-cache policy nodejs
echo ""

# DETECTING WRONG PATHS
if
    [[ "$NODENOTCORR" -eq 1 ]]
then
    echo -e "\n\nYour nodejs-Installation seems to be faulty. Shall we try to fix it?"
    echo "Press <y> to continue or any other key to quit"
    read -r -s -n 1 charpaths
    if
        [[ "$charpaths" = "y" ]] || [[ "$charpaths" = "Y" ]]
    then
        echo -e "\nFixing your nodejs setup"
        if
            [[ -f /usr/bin/nodejs && "$PATHNODEJS" != "/usr/bin/nodejs" ]]
        then
            echo -e "*** Deleting $PATHNODEJS ***"
            $SUDOX rm "$(type -p nodejs)"
        fi
        if
            [[ "$PATHNODE" != "/usr/bin/node" ]]
        then
            echo -e "*** Deleting $PATHNODE ***"
            $SUDOX rm "$(type -p node)"
        fi
        if
            [[ "$PATHNPM" != "/usr/bin/npm" ]]
        then
            echo -e "*** Deleting $PATHNPM ***"
            $SUDOX rm "$(type -p npm)"
        fi
        if
            [[ "$PATHNPX" != "/usr/bin/npx" ]]
        then
            echo -e "*** Deleting $PATHNPX ***"
            $SUDOX rm "$(type -p npx)"
        fi
        echo -e "\nWrong paths have been fixed. Run 'iob diag' or 'iob nodejs-update' again to check if your installation is fine now"
    fi
else
    echo -e "\n\n\033[32mNothing to do\033[0m - Your installation is using the correct paths."
fi

if
    [[ "$INSTALL_CMD" != "apt-get" ]]
then
    echo "Non-Debian-based Systems are not supported, exiting"
    unset LC_ALL
    exit
fi
VERNODE=$(node -v)
if [[ "$VERNODE" = "v$NODERECOM" ]] && [ -f /etc/apt/sources.list.d/nodesource.list ]; then
    echo -e "\033[32mNothing to do\033[0m - Your version is the recommended one."
    echo -e "\n*** You can now keep your whole system up-to-date using the usual 'sudo apt update && sudo apt full-upgrade' commands. ***"
    echo "*** DO NOT USE node version managers like 'nvm', 'n' and others in parallel. They will break your current installation! ***"
    echo -e "\n*** DO NOT use 'nodejs-update' as part of your regular update process! ***"
    unset LC_ALL
    if [[ -f "/var/run/reboot-required" ]]; then
        echo ""
        echo "This system needs to be REBOOTED NOW!"
        echo ""
    fi
    exit
fi


if [[ "$VERNODE" != "v$NODERECOM" ]] && [[ "$NODERECOM" == [[:digit:]]*.[[:digit:]]*.[[:digit:]]* ]] || [ ! -f /etc/apt/sources.list.nodesource.list ]; then
    echo -e "\nYou are missinng the nodesource.list or"
    echo -e "you want to change your current nodejs version: $VERNODE ?"

    elif [[ $1 -gt 18 ]]; then
    echo "Do you want to install nodejs $1 or fix the source?"
    else
    echo "Do you want to intall nodejs v$NODERECOM ?"
fi

    echo -e "\nPress <y> to continue or any other key to quit"
    read -r -s -n 1 char
    if
        [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]
    then
        echo "Trying to fix your installation now. Please be patient."
        # Finding nodesource.gpg or nodesource.key and deleting. Current key is pulled in later.
        $SUDOX rm "$($SUDOX find / \( -path /usr/share -o -path /etc/apt \) -prune -false -o -name nodesource.[gk]* -print)"
        # Deleting nodesource.list and nodesource.sources - Will be recreated later.
        $SUDOX rm /etc/apt/sources.list.d/nodesource.*
    else
        echo "We are not fixing your installation. Exiting."
        if [[ -f "/var/run/reboot-required" ]]; then
            echo ""
            echo "This system needs to be REBOOTED NOW!"
            echo ""
        fi
        exit
    fi

if
    [[ "$VERNODE" != "v$NODERECOM" ]] && [[ "$NODERECOM" != [[:digit:]]*.[[:digit:]]*.[[:digit:]]* ]]
then
    echo -e "\nYou are running nodejs $VERNODE. Do you want to install latest version from nodejs v.$NODE_MAJOR tree? "
    echo -e "\nPress <y> to continue or any other key to quit"
    read -r -s -n 1 char
    if
        [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]
    then
        echo "Trying to fix your installation now. Please be patient."
        # Finding nodesource.gpg or nodesource.key and deleting. Current key is pulled in later.
        $SUDOX rm "$($SUDOX find / \( -path /usr/share -o -path /etc/apt \) -prune -false -o -name nodesource.[gk]* -print)"
        # Deleting nodesource.list and nodesource.sources - Will be recreated later.
        $SUDOX rm /etc/apt/sources.list.d/nodesource.*
    else
        echo "Not fixing your installation. Exiting."

        if [[ -f "/var/run/reboot-required" ]]; then
            echo ""
            echo "This system needs to be REBOOTED NOW!"
            echo ""
        fi
        exit

    fi
fi


# Function for the progress bar
progress_bar() {
    while kill -0 "$1" 2>/dev/null; do
        echo -n "#"
        sleep 1
    done
    echo ""
}

# Excecute in the background
echo "Stopping ioBroker now"
iob stop &

# Save the PID of the background process
command_pid=$!

# Check if process is running
if ! kill -0 "$command_pid" 2>/dev/null; then
    echo "ioBroker is not running or could not be stopped."
    else
    # Start progressbar with PID
    progress_bar $command_pid &

    # Wait until iobroker had been shutdown
    wait $command_pid

    echo -e "\nioBroker has been stopped"
fi





echo ""
echo ""
echo "Removing dfsg-nodejs"
eval "$DFSGREM"
echo ""

echo -e "\n\n*** These repos are active on your system:"
$SUDOX "$INSTALL_CMD" update
echo -e "\n*** Installing ca-certificates, curl and gnupg, just in case they are missing."
if ! $SUDOX "$INSTALL_CMD" install -y -qq ca-certificates curl gnupg; then
    handle_error "$?" "Failed to install packages"
fi
# Installing the key for nodesource repository

if ! $SUDOX mkdir -p /usr/share/keyrings; then
    handle_error "$?" "Makes sure the path /usr/share/keyrings exist or run ' mkdir -p /usr/share/keyrings' with sudo"
fi

$SUDOX rm -f /usr/share/keyrings/nodesource.gpg || true
$SUDOX rm -f /etc/apt/keyrings/nodesource.gpg || true
$SUDOX rm -f /etc/apt/sources.list.d/nodesource.* || true

    # Run 'curl' and 'gpg' to download and import the NodeSource signing key
    if ! curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | $SUDOX gpg --dearmor -o /usr/share/keyrings/nodesource.gpg; then
      handle_error "$?" "Failed to download and import the NodeSource signing key"
    fi

    # Explicitly set the permissions to ensure the file is readable by all
    if ! $SUDOX chmod 644 /usr/share/keyrings/nodesource.gpg; then
        handle_error "$?" "Failed to set correct permissions on /usr/share/keyrings/nodesource.gpg"
    fi

# Setting up a fresh & clean nodesource.list
echo -e "\n*** Creating new /etc/apt/sources.list.d/nodesource.list and pinning source"
echo ""

    arch=$(dpkg --print-architecture)
    if [ "$arch" != "amd64" ] && [ "$arch" != "arm64" ] && [ "$arch" != "armhf" ]; then
      handle_error "1" "Unsupported architecture: $arch. Only amd64, arm64, and armhf are supported."
    fi

    echo "deb [arch=$arch signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | $SUDOX tee /etc/apt/sources.list.d/nodesource.list > /dev/null




#echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | $SUDOX tee /etc/apt/sources.list.d/nodesource.list


echo -e "Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 1001" | sudo tee /etc/apt/preferences.d/nodejs
echo -e "\n*** These repos are active after the adjustments:"
$SUDOX "$INSTALL_CMD" update

echo -e "\nInstalling nodejs now!"

if [ "$SYSTDDVIRT" != "none" ]; then
    nodejs_installation
    compatibility_check
    echo -e "\n\n*** You need to manually restart your container/virtual machine now! *** "
    echo -e "\nWe tried our best to fix your nodejs. Please run 'iob diag' again to verify."
    unset LC_ALL
    if [[ -f "/var/run/reboot-required" ]]; then
        echo ""
        echo "This system needs to be REBOOTED NOW!"
        echo ""
    fi
    exit
else
    nodejs_installation
    compatibility_check
    restart_iob
fi

exit
