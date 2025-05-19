#!/bin/bash
# iobroker nodejs-update
# written to help updating and fixing nodejs on linux (Debian based Distros)

#To be manually changed:
VERSION="2025-02-23"
NODE_MAJOR=20 #recommended major nodejs version for ioBroker, please adjust if the recommendation changes. This is only the target for fallback.

# Check if version option is a valid one
if [[ -z "$1" ]]; then
    echo "No specific version given, installing recommended version $NODE_MAJOR"
elif [ "$1" -ge 18 ]; then
    echo "Valid major version"
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
    echo -e "Debian 10 'Buster' has reached End of Life and is not supported anymore.\nRecent versions of nodejs won't install.\nPlease install the current Debian Stable"
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

if [[ -f /usr/bin/corepack ]]; then
    echo -e "$(type -p corepack) \t$(corepack -v)"
fi

PATHNODEJS=$(type -p nodejs)
PATHNODE=$(type -p node)
PATHNPM=$(type -p npm)
PATHNPX=$(type -p npx)

if [[ -f /usr/bin/corepack ]]; then
    PATHCOREPACK=$(type -p corepack)
fi

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
elif
    [[ -f /usr/bin/corepack && "$PATHCOREPACK" != "/usr/bin/corepack" ]]
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
        if
            [[ -f /usr/bin/corepack && "$PATHCOREPACK" != "/usr/bin/corepack" ]]
        then
            echo -e "*** Deleting $PATHCOREPACK ***"
            $SUDOX rm "$(type -p corepack)"
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
if [[ "$VERNODE" = "v$NODERECOM" ]]; then
    echo -e "\033[32mNothing to do\033[0m - Your version is the recommended one."
    echo -e "\n***You can now keep your whole system up-to-date using the usual 'sudo apt update && sudo apt full-upgrade' commands. ***"
    echo "*** DO NOT USE node version managers like 'nvm', 'n' and others in parallel. They will break your current installation! ***"
    echo -e "\n *** DO NOT use 'nodejs-update' as part of a regular update process! ***"
    unset LC_ALL
    if [[ -f "/var/run/reboot-required" ]]; then
        echo ""
        echo "This system needs to be REBOOTED NOW!"
        echo ""
    fi
    exit
fi
if [[ "$VERNODE" != "v$NODERECOM" ]] && [[ "$NODERECOM" == [[:digit:]]*.[[:digit:]]*.[[:digit:]]* ]]; then
    echo -e "\nYou are running nodejs $VERNODE. Do you want to install recommended version $NODERECOM? "
    echo -e "\nPress <y> to continue or any other key to quit"
    read -r -s -n 1 char
    if
        [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]
    then
        echo "Trying to fix your installation now. Please be patient."
        # Finding nodesource.gpg or nodesource.key and deleting. Current key is pulled in later.
        $SUDOX rm "$($SUDOX find / \( -path /proc -o -path /dev -o -path /sys -o -path /lost+found -o -path /mnt -o -path /run \) -prune -false -o -name nodesource.[gk]* -print) 2> /dev/null"
        # Deleting nodesource.list Will be recreated later.
        $SUDOX rm /etc/apt/sources.list.d/nodesource.lis* 2>/dev/null
    else
        echo "We are not fixing your installation. Exiting."
        if [[ -f "/var/run/reboot-required" ]]; then
            echo ""
            echo "This system needs to be REBOOTED NOW!"
            echo ""
        fi
        exit
    fi
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
        $SUDOX rm "$($SUDOX find / \( -path /proc -o -path /dev -o -path /sys -o -path /lost+found -o -path /mnt \) -prune -false -o -name nodesource.[gk]* -print) 2> /dev/null"
        # Deleting nodesource.list Will be recreated later.
        $SUDOX rm /etc/apt/sources.list.d/nodesource.lis* 2>/dev/null
    else
        echo "We are not fixing your installation. Exiting."

        if [[ -f "/var/run/reboot-required" ]]; then
            echo ""
            echo "This system needs to be REBOOTED NOW!"
            echo ""
        fi
        exit

    fi
fi

if [ "$SYSTDDVIRT" != "none" ]; then
    echo -e "\nVirtualization: $SYSTDDVIRT"
    iob stop &
    # sudo pkill ^io;
else
    iob stop &
fi

echo "Waiting for ioBroker to shut down - Give me a minute..."
BAR='############################################################' # this is full bar, e.g. 60 chars
for i in {1..60}; do
    echo -ne "\r${BAR:0:$i}" # print $i chars of $BAR from 0 position
    sleep 1                  # wait 1s between "frames"
done
echo ""
echo ""
echo "Removing dfsg-nodejs"
eval "$DFSGREM"
echo ""

echo -e "\n*** These repos are active on your system:"
$SUDOX "$INSTALL_CMD" update
echo -e "\n*** Installing ca-certificates, curl and gnupg, just in case they are missing."
$SUDOX "$INSTALL_CMD" install -qq ca-certificates curl gnupg
# Installing the key for nodesource repository
$SUDOX mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | $SUDOX gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
# Setting up a fresh & clean nodesource.list
echo -e "\n*** Creating new /etc/apt/sources.list.d/nodesource.list and pinning source"
echo ""
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | $SUDOX tee /etc/apt/sources.list.d/nodesource.list
echo -e "Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 1001" | sudo tee /etc/apt/preferences.d/nodejs.pref
echo -e "\n*** These repos are active after the adjustments:"
$SUDOX "$INSTALL_CMD" update

echo ""
echo "Installing nodejs now!"
echo ""
if [ "$NODEINSTMAJOR" -gt "$NODE_MAJOR" ] && [[ "$NODERECOM" == [[:digit:]]*.[[:digit:]]*.[[:digit:]]* ]]; then
    $SUDOX $INSTALL_CMD install --reinstall --allow-downgrades -qq nodejs="$NODERECOM"-1nodesource1
elif
    [[ "$NODERECOMNF" -eq 1 ]]
then
    NODERECOM=$NODE_MAJOR.0.0

    echo "Exact recommended version unknown, installing a fallback!"
    $SUDOX $INSTALL_CMD install --reinstall --allow-downgrades -qq nodejs="$NODERECOM"-1nodesource1
    echo -e "\nUpdating fallback to latest nodejs v$NODE_MAJOR release"
    $SUDOX $INSTALL_CMD -qq update
    $SUDOX $INSTALL_CMD -qq --allow-downgrades upgrade nodejs
    VERNODE=$(node -v)
    echo -e "$VERNODE has been installed! You are using the latest version now!"
fi

if [ "$NODEINSTMAJOR" -lt "$NODE_MAJOR" ]; then
    $SUDOX $INSTALL_CMD -qq update
    $SUDOX $INSTALL_CMD -qq --allow-downgrades upgrade nodejs
fi

if [ "$SYSTDDVIRT" != "none" ]; then
    echo "Installing nodejs now!"
    $SUDOX $INSTALL_CMD update -qq
    $SUDOX $INSTALL_CMD -qq --allow-downgrades upgrade nodejs
    echo -e "\n*** You need to manually restart your container/virtual machine now! *** "
    echo -e "\nWe tried our best to fix your nodejs. Please run 'iob diag' again to verify."
    unset LC_ALL
    if [[ -f "/var/run/reboot-required" ]]; then
        echo ""
        echo "This system needs to be REBOOTED NOW!"
        echo ""
    fi
    exit
else
    echo "Installing the nodejs!"
    $SUDOX $INSTALL_CMD update -qq
    $SUDOX $INSTALL_CMD -qq --allow-downgrades upgrade nodejs
    echo -e "\nWe tried our best to fix your nodejs. Please run iob diag again to verify."
    echo -e "\n*** RESTARTING ioBroker NOW! *** \n Please refresh or restart your browser in a few moments."
    iob restart
fi

echo ""

if [[ -f "/var/run/reboot-required" ]]; then
    echo ""
    echo "This system needs to be REBOOTED NOW!"
    echo ""
fi
unset LC_ALL
exit
