#!/bin/bash
# iobroker diagnostics
# written to help getting information about the environment the ioBroker installation is running in
DOCKER=/opt/scripts/.docker_config/.thisisdocker
#if [[ -f "/opt/scripts/.docker_config/.thisisdocker" ]]
if [ -f "$DOCKER" ]
then
        echo "";
        elif [ "$(id -u)" = 0 ];
                then
                        echo -e "You should not be root on your system!\nBetter use your standard user!\n\n";
                        sleep 15;

fi
clear;
echo "*** iob diag is starting up, please wait ***";
# VARIABLES
export LC_ALL=C;
SKRIPTV="2024-08-17";      #version of this script
#NODE_MAJOR=20           this is the recommended major nodejs version for ioBroker, please adjust accordingly if the recommendation changes

HOST=$(hostname)
source /etc/os-release
NODERECOM=$(iobroker state getValue system.host."$HOST".versions.nodeNewestNext);  #recommended node version
NPMRECOM=$(iobroker state getValue system.host."$HOST".versions.npmNewestNext);    #recommended npm version
#NODEUSED=$(iobroker state getValue system.host."$HOST".versions.nodeCurrent);      #current node version in use
#NPMUSED=$(iobroker state getValue system.host."$HOST".versions.npmCurrent);        #current npm version in use
XORGTEST=0;      #test for GUI
APT=0;
INSTENV=0;
INSTENV2=0;
SYSTDDVIRT="";
NODENOTCORR=0;
IOBLISTINST=$(iobroker list instances);
NPMLS=$(cd /opt/iobroker && npm ls -a)

#Debian and Ubuntu releases and their status
EOLDEB="buzz rex bo hamm slink potato woody sarge etch lenny squeeze wheezy jessie stretch buster";
EOLUBU="bionic xenial trusty mantic lunar kinetic impish hirsute groovy eoan disco cosmic artful zesty yakkety wily vivid utopic saucy raring quantal precise oneiric natty maverick lucid karmic jaunty intrepid hardy gutsy feisty edgy dapper breezy hoary warty";
DEBSTABLE="bookworm";
UBULTS="noble"
OLDLTS="jammy focal";
TESTING="trixie oracular"
OLDSTABLE="bullseye";
CODENAME=$(lsb_release -sc);
UNKNOWNRELEASE=1

clear;
echo "";
echo -e "\033[34;107m*** ioBroker Diagnosis ***\033[0m";
echo "";
echo "Please stretch the window of your terminal programm (puTTY) as wide as possible or switch to full screen";
echo "";
echo "The following checks may give hints to potential malconfigurations or errors, please post them in our forum:";
echo "";
echo "https://forum.iobroker.net";
echo "";
echo "Just copy and paste the Summary Page, including the \`\`\` characters at start and end.";
echo "It helps us to help you!"
echo "";
     # read -p "Press <Enter> to continue";
echo "Press any key to continue";
read -r -n 1 -s
        clear;
echo "";
echo -e "\033[33m======== Start marking the full check here =========\033[0m";
echo "";
echo "\`\`\`bash";
echo "Skript v.$SKRIPTV"
echo "";
echo -e "\033[34;107m*** BASE SYSTEM ***\033[0m";

if [ -f "$DOCKER" ]; then
echo -e "Hardware Vendor : $(cat /sys/devices/virtual/dmi/id/sys_vendor)";
echo -e "Kernel          : $(uname -m)";
echo -e "Userland        : $(getconf LONG_BIT) bit";
echo -e "Docker          : $(cat /opt/scripts/.docker_config/.thisisdocker)"
else
        hostnamectl | grep -v 'Machine\|Boot';
        echo "OS is similar to: $ID_LIKE"
        echo "";
        grep -i model /proc/cpuinfo | tail -1;
        echo -e "Docker          : false";
fi;
for x in $EOLDEB; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[31mDebian Release '$CODENAME' reached its END OF LIFE and needs to be updated to the latest stable release '$DEBSTABLE' NOW!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $EOLUBU; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[31mUbuntu Release '$CODENAME' reached its END OF LIFE and needs to be updated to the latest LTS release '$UBULTS' NOW!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $DEBSTABLE; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[32mYour Operating System is the current Debian stable version '$DEBSTABLE'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $UBULTS; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[32mYour Operating System is the current Ubuntu LTS release '$UBULTS'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $OLDLTS; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[1;33mYour Operating System '$OLDLTS' is an aging Ubuntu LTS release! Please upgrade to the latest LTS release '$UBULTS' in due time!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $TESTING; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[1;33mYour Operating System codenamed '$CODENAME' is not released yet! Please use it only for testing purposes!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $OLDSTABLE; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[1;33mDebian '$OLDSTABLE' is the current oldstable version. Please upgrade to the latest stable release '$DEBSTABLE' in due time!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

if [ $UNKNOWNRELEASE -eq 1 ]; then
    echo "Unknown release name: $CODENAME. Please check yourself if your Operating System is maintained."
fi;


SYSTDDVIRT=$(systemd-detect-virt 2>/dev/null)
if [ "$SYSTDDVIRT" != "" ]; then
    echo -e "Virtualization  : $(systemd-detect-virt)"
else
    echo "Virtualization  : Docker"
fi;
echo -e "Kernel          : $(uname -m)";
echo -e "Userland        : $(getconf LONG_BIT) bit";
echo "";
echo "Systemuptime and Load:";
        uptime;
echo "CPU threads: $(grep -c processor /proc/cpuinfo)"
echo "";
# RASPBERRY only
if [[ $(type -P "vcgencmd" 2>/dev/null) = *"/vcgencmd" ]]; then
#        echo "Raspberry only:";
#        vcgencmd get_throttled 2> /dev/null;
#        echo "Other values than 0x0 hint to temperature/voltage problems";
#        vcgencmd measure_temp;
#        vcgencmd measure_volts;

#### TEST CODE  ###

echo "";
echo -e "\033[34;107m*** RASPBERRY THROTTLING ***\033[0m";
# CODE from https://github.com/alwye/get_throttled under MIT Licence
ISSUES_MAP=( \
  [0]="Under-voltage detected" \
  [1]="Arm frequency capped" \
  [2]="Currently throttled"
  [3]="Soft temperature limit active" \
  [16]="Under-voltage has occurred" \
  [17]="Arm frequency capping has occurred" \
  [18]="Throttling has occurred" \
  [19]="Soft temperature limit has occurred")

HEX_BIN_MAP=( \
  ["0"]="0000" \
  ["1"]="0001" \
  ["2"]="0010" \
  ["3"]="0011" \
  ["4"]="0100" \
  ["5"]="0101" \
  ["6"]="0110" \
  ["7"]="0111" \
  ["8"]="1000" \
  ["9"]="1001" \
  ["A"]="1010" \
  ["B"]="1011" \
  ["C"]="1100" \
  ["D"]="1101" \
  ["E"]="1110" \
  ["F"]="1111" \
)

THROTTLED_OUTPUT=$(vcgencmd get_throttled)
IFS='x'
read -r -a strarr <<< "$THROTTLED_OUTPUT"
THROTTLED_CODE_HEX=${strarr[1]}

# Display current issues
echo "Current issues:"
CURRENT_HEX=${THROTTLED_CODE_HEX:4:1}
CURRENT_BIN=${HEX_BIN_MAP[$CURRENT_HEX]}
if [ "$CURRENT_HEX" == "0" ] || [ -z "$CURRENT_HEX" ]; then
  echo "No throttling issues detected."
else
  bit_n=0
  for (( i=${#CURRENT_BIN}-1; i>=0; i--)); do
    if [ "${CURRENT_BIN:$i:1}" = "1" ]; then
      echo "~ ${ISSUES_MAP[$bit_n]}"
      bit_n=$((bit_n+1))
    fi
  done
fi

echo ""

# Display past issues
echo "Previously detected issues:"
PAST_HEX=${THROTTLED_CODE_HEX:0:1}
PAST_BIN=${HEX_BIN_MAP[$PAST_HEX]}
if [ "$PAST_HEX" = "0" ]; then
  echo "No throttling issues detected."
else
  bit_n=16
  for (( i=${#PAST_BIN}-1; i>=0; i--)); do
    if [ "${PAST_BIN:$i:1}" = "1" ]; then
      echo "~ ${ISSUES_MAP[$bit_n]}"
      bit_n=$((bit_n+1))
    fi
  done
fi

fi

if [[ -f "/var/run/reboot-required" ]]; then
        echo "";
        echo "This system needs to be REBOOTED!";
        echo "";
fi


echo "";
echo -e "\033[34;107m*** Time and Time Zones ***\033[0m";

if [ -f "$DOCKER" ]; then
        date -u;
        date;
        date +"%Z %z";
        cat /etc/timezone;
else
    timedatectl;
fi;

if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ $(command -v apt-get) ]] && [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
echo "Your timezone is probably wrong. Do you want to reconfigure it? (y/n)"
read -r -s -n 1 char;
        if
                                [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]
        then
                                sudo dpkg-reconfigure tzdata;
        fi;
fi;


echo "";
echo -e "\033[34;107m*** Users and Groups ***\033[0m";
        echo "User that called 'iob diag':";
        whoami;
        env | grep HOME;
        echo "GROUPS=$(groups)";
        echo "";
        echo "User that is running 'js-controller':";
        if [[ $(pidof iobroker.js-controller) -gt 0 ]];
        then
                IOUSER=$(ps -o user= -p "$(pidof iobroker.js-controller)")
                echo "$IOUSER";
                sudo -H -u "$IOUSER" env | grep HOME;
                echo "GROUPS=$(sudo -u "$IOUSER" groups)"
        else
         echo "js-controller is not running";
        fi;

echo "";

echo -e "\033[34;107m*** Display-Server-Setup ***\033[0m";
XORGTEST=$(pgrep -cf '[X]|[w]ayland|X11|wayfire')
if [[ "$XORGTEST" -gt 0 ]];
        then
                echo -e "Display-Server: true"
        else
                echo -e "Display-Server: false"
fi
echo -e "Desktop: \t$DESKTOP_SESSION";
echo -e "Terminal: \t$XDG_SESSION_TYPE";
if [ -f "$DOCKER" ]; then
        echo -e "";
else
        echo -e "Boot Target: \t$(systemctl get-default)";
fi;
echo "";
echo -e "\033[34;107m*** MEMORY ***\033[0m";
        free -th --mega;
echo "";
echo -e "Active iob-Instances: \t$(echo "$IOBLISTINST" | grep -c ^+)";
echo "";
        vmstat -S M -s | head -n 10;

# RASPBERRY only - Code broken for RPi5
# if [[ $(type -P "vcgencmd" 2>/dev/null) = *"/vcgencmd" ]]; then
#        echo "";
#        echo "Raspberry only:";
#        vcgencmd mem_oom;
#fi;

echo "";
echo -e "\033[34;107m*** top - Table Of Processes  ***\033[0m";
top -b -n 1 | head -n 5;

if [ -f "$DOCKER" ]; then
echo "";
else
echo "";
echo -e "\033[34;107m*** FAILED SERVICES ***\033[0m";
echo "";
systemctl list-units --failed --no-pager;
echo "";
fi;
echo -e "\033[34;107m*** FILESYSTEM ***\033[0m";
        df -PTh;
echo "";
echo -e "\033[32mMessages concerning ext4 filesystem in dmesg:\033[0m";
sudo dmesg -T | grep -i ext4;
echo "";
echo -e "\033[32mShow mounted filesystems:\033[0m";
findmnt --real;
echo "";
if [[ -L "/opt/iobroker/backups" ]]; then
  echo "backups directory is linked to a different directory";
  echo "";
fi
echo -e "\033[32mFiles in neuralgic directories:\033[0m";
echo "";
echo -e  "\033[32m/var:\033[0m";
        sudo du -h /var/ | sort -rh | head -5;
echo -e "";
if [ -f "$DOCKER" ]; then
    echo -e ""
else
    journalctl --disk-usage;
fi;
echo "";
echo -e "\033[32m/opt/iobroker/backups:\033[0m";
        du -h /opt/iobroker/backups/ | sort -rh | head -5;
echo "";
echo -e "\033[32m/opt/iobroker/iobroker-data:\033[0m";
        du -h /opt/iobroker/iobroker-data/ | sort -rh | head -5;
echo "";
echo -e "\033[32mThe five largest files in iobroker-data are:\033[0m";
        find /opt/iobroker/iobroker-data -maxdepth 15 -type f -exec du -sh {} + | sort -rh | head -n 5;
echo "";
# Detecting dev-links in /dev/serial/by-id
echo -e "\033[32mUSB-Devices by-id:\033[0m";
echo "USB-Sticks -  Avoid direct links to /dev/tty* in your adapter setups, please always prefer the links 'by-id':";
echo "";

SYSZIGBEEPORT=$(find /dev/serial/by-id/ -maxdepth 1 -mindepth 1 2>/dev/null);

# echo "CODE I ";
#
#
# if [[ -n "$SYSZIGBEEPORT" ]];
#         then
#                 echo "$SYSZIGBEEPORT";
#         else
#                 echo "No Devices found 'by-id'";
# fi;
#
# readarray IOBZIGBEEPORT < <( iob list instances | grep system.adapter.zigbee | awk -F ':' '{print $4}' );
# for i in  ${IOBZIGBEEPORT[@]}; do
#         if [[ "$SYSZIGBEEPORT" == *"$i"* ]]
#                 then
#                 echo "";
#                 echo "Your zigbee COM-Port is matching 'by-id'. Very good!"
#                 else
#                 echo;
#                 echo "HINT:";
#                 echo "Your zigbee COM-Port is NOT matching 'by-id'. Please check your setting:";
#                 echo "$IOBZIGBEEPORT0";
#         fi
#                 done;
#
# echo "";
# echo "CODE II";
IOBZIGBEEPORT0=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.0 | awk -F ':' '{print $4}' | cut -c 2-)
IOBZIGBEEPORT1=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.1 | awk -F ':' '{print $4}' | cut -c 2-)
IOBZIGBEEPORT2=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.2 | awk -F ':' '{print $4}' | cut -c 2-)


if [[ -n "$SYSZIGBEEPORT" ]];
        then
                echo "$SYSZIGBEEPORT";
        else
                echo "No Devices found 'by-id'";
fi;

if  [[ -z "$IOBZIGBEEPORT0" ]]
        then
                echo "";
        elif [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT0"* ]]
        then
                echo "";
                echo "Your zigbee.0 COM-Port is matching 'by-id'. Very good!";
        else
                echo;
                echo "HINT:";
                echo "Your zigbee.0 COM-Port is NOT matching 'by-id'. Please check your setting:";
                echo "$IOBZIGBEEPORT0";
                # diff -y --left-column <(echo "$IOBZIGBEEPORT0") <(echo "$SYSZIGBEEPORT");
fi;

if  [[ -z "$IOBZIGBEEPORT1" ]]
        then
                echo "";
        elif [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT1"* ]]
        then
                echo "";
                echo "Your zigBee.1 COM-Ports is matching 'by-id'. Very good!";
        else
                echo;
                echo "HINT:";
                echo "Your zigbee.1 COM-Port is NOT matching 'by-id'. Please check your setting:";
                echo "$IOBZIGBEEPORT1";
                # diff -y --left-column <(echo "$IOBZIGBEEPORT1") <(echo "$SYSZIGBEEPORT");
fi;

if  [[ -z "$IOBZIGBEEPORT2" ]]
        then
                echo "";
        elif [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT2"* ]]
        then
                echo "";
                echo "Your zigBee.2 COM-Ports is matching 'by-id'. Very good!";
        else
                echo;
                echo "HINT:";
                echo "Your zigbee.2 COM-Port is NOT matching 'by-id'. Please check your setting:";
                echo "$IOBZIGBEEPORT2";
                # diff -y --left-column <(echo "$IOBZIGBEEPORT2") <(echo "$SYSZIGBEEPORT");
fi;

echo "";
echo -e "\033[34;107m*** NodeJS-Installation ***\033[0m";
echo "";

# PATHAPT=$(type -P apt);
PATHNODEJS=$(type -P nodejs);
PATHNODE=$(type -P node);
PATHNPM=$(type -P npm);
PATHNPX=$(type -P npx);
PATHCOREPACK=$(type -P corepack);


if [ "$PATHNODEJS" = "" ];
then
        echo -e "nodejs: \t\tN/A";
else
        echo -e "$(type -P nodejs) \t$(nodejs -v)";
        VERNODEJS=$(nodejs -v);
fi;

if [ "$PATHNODE" = "" ];
then
        echo -e "node: \t\tN/A";

else
        echo -e "$(type -P node) \t\t$(node -v)";
        VERNODE=$(node -v);
fi;

if [ "$PATHNPM" = "" ];
then
        echo -e "npm: \t\t\tN/A";
else
        echo -e "$(type -P npm) \t\t$(npm -v)";
        VERNPM=$(npm -v);
fi;

if [ "$PATHNPX" = "" ];
then
        echo -e "npx: \t\t\tN/A";

else
        echo -e "$(type -P npx) \t\t$(npx -v)";
        VERNPX=$(npx -v);
fi;

if [ "$PATHCOREPACK" = "" ];
then
        echo -e "corepack: \tN/A";

else
        echo -e "$(type -P corepack) \t$(corepack -v)";
        # VERCOREPACK=$(corepack -v);
fi;


if
        [[ $PATHNODEJS != "/usr/bin/nodejs" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
        elif
        [[ $PATHNODE != "/usr/bin/node" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
        elif
        [[ $PATHNPM != "/usr/bin/npm" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
        elif
        [[ $PATHNPX != "/usr/bin/npx" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
        elif
        [[ $VERNODEJS != "$VERNODE" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
        elif
        [[ $VERNPM != "$VERNPX" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
        elif
        [[ $PATHCOREPACK != "/usr/bin/corepack" ]];
        then
                NODENOTCORR=1
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
else
                echo "";
fi

echo "";
if [ -f /usr/bin/apt-cache ]
then
        apt-cache policy nodejs;
        echo "";
else
echo "";
fi

# npm doctor can be misleading, deactivated to avoid confusion
# echo -e "Calling 'npm doctor' for you. \033[32mPlease be patient!\033[0m";
# echo "";
# (cd /opt/iobroker && sudo -H -u iobroker npm doctor);
# echo "";
# echo "The recommended versions for ioBroker are nodeJS v$NODERECOM / npm v$NPMRECOM!";
# echo "Don't trust the doctor if he recommends different versions!"
# echo "";

ANZNPMTMP=$(find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium' | wc -l);
echo -e "\033[32mTemp directories causing npm8 problem:\033[0m ""$ANZNPMTMP""";
if [[ $ANZNPMTMP -gt 0 ]]
then
        echo -e "Some problems detected, please run \e[031miob fix\e[0m";
else
        echo "No problems detected"
fi;

# echo "";
# echo -e "Temp directories being cleaned up now `find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \;`";
# find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \ &> /dev/null;
# echo -e "\033[32m1 - Temp directories causing npm8 problem:\033[0m `find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium'>e;
echo "";
echo "Errors in npm tree:";
echo "$NPMLS" | grep ERR;
echo "";
echo -e "\033[34;107m*** ioBroker-Installation ***\033[0m";
echo "";
echo -e "\033[32mioBroker Status\033[0m";
iobroker status;
echo "";
# multihost detection - wip
# iobroker multihost status
# iobroker status all | grep MULTIHOSTSERVICE/enabled
echo -e "\033[32mCore adapters versions\033[0m"
echo -e "js-controller: \t$(iob -v)";
echo -e "admin: \t\t$(iob version admin)";
echo -e "javascript: \t$(iob version javascript)";
echo "";
echo -e "nodejs modules from github: \t$(echo "$NPMLS" | grep -c 'github.com')";
echo "$NPMLS" | grep 'github.com';
echo "";
echo -e "\033[32mAdapter State\033[0m";
echo "$IOBLISTINST";
echo "";
echo -e "\033[32mEnabled adapters with bindings\033[0m";
echo "$IOBLISTINST" | grep enabled | grep port ;
echo "";
echo -e "\033[32mioBroker-Repositories\033[0m";
        iob repo list;
echo "";
echo -e "\033[32mInstalled ioBroker-Instances\033[0m";
        iob update -i;
echo "";
echo -e "\033[32mObjects and States\033[0m";
echo "Please stand by - This may take a while";
IOBOBJECTS=$(iob list objects 2>/dev/null | wc -l);
echo -e "Objects: \t$IOBOBJECTS";
IOBSTATES=$(iob list states 2>/dev/null | wc -l);
echo -e "States: \t$IOBSTATES";
echo "";
echo -e "\033[34;107m*** OS-Repositories and Updates ***\033[0m";
if [ -f /usr/bin/apt-get ]
then
        sudo apt-get update 1>/dev/null && sudo apt-get update
        APT=$(apt-get upgrade -s |grep -P '^\d+ upgraded'|cut -d" " -f1)
        echo -e "Pending Updates: $APT";
else
        echo "No Debian-based Linux detected."
fi


echo "";

echo -e "\033[34;107m*** Listening Ports ***\033[0m";
        sudo netstat -tulpen #| sed -n '1,2p;/LISTEN/p';
# Alternativ - ss ist nicht ueberall installiert
# sudo ss -tulwp | grep LISTEN;
echo "";
echo -e "\033[34;107m*** Log File - Last 25 Lines ***\033[0m";
echo "";
# iobroker logs --lines 25;
tail -n 25 /opt/iobroker/log/iobroker.current.log;
echo "";
echo "\`\`\`";
echo "";
echo -e "\033[33m============ Mark until here for C&P =============\033[0m";
echo "";
echo "iob diag has finished.";
echo "";
echo "";
       # read -p "For a Summary please press <Enter>";
echo "Press any key for a summary";
        read -r -n 1 -s
echo "";
        clear;
echo "Copy text starting here:";
echo "";
echo "\`\`\`bash";
echo "======================= SUMMARY =======================";
echo -e "\t\t\tv.$SKRIPTV"
echo "";
echo "";
if [ -f "$DOCKER" ]; then
        INSTENV=2
elif [ "$SYSTDDVIRT" != "none" ]; then
        INSTENV=1
else
        INSTENV=0
fi;
INSTENV2=$(
if [[ $INSTENV -eq 2 ]]; then
        echo "Docker";
elif [ $INSTENV -eq 1 ]; then
        echo "$SYSTDDVIRT";
else
        echo "native";
fi;)
if [ -f "$DOCKER" ]; then
        grep -i model /proc/cpuinfo | tail -1;
echo -e "Kernel          : $(uname -m)";
echo -e "Userland        : $(dpkg --print-architecture)";
if [[ -f "$DOCKER" ]]; then
    echo -e "Docker          : $(cat /opt/scripts/.docker_config/.thisisdocker)"
else
    echo -e "Docker          : false"
fi;

else
hostnamectl | grep -v 'Machine\|Boot';
fi;
echo "";
echo -e "Installation: \t\t$INSTENV2";
echo -e "Kernel: \t\t$(uname -m)";
echo -e "Userland: \t\t$(getconf LONG_BIT) bit";
if [ -f "$DOCKER" ]; then
    echo -e "Timezone: \t\t$(date +"%Z %z")"
else
    echo -e "Timezone: \t\t$(timedatectl | grep zone | cut -c28-80)";
fi;
echo -e "User-ID: \t\t$EUID";
echo -e "Display-Server: \t$(if [[ $XORGTEST -gt 0 ]]; then echo "true";else echo "false";fi)";
if [ -f "$DOCKER" ]; then
        echo -e "";
else
        echo -e "Boot Target: \t\t$(systemctl get-default)";
fi;

echo "";
echo -e "Pending OS-Updates: \t$APT";
echo -e "Pending iob updates: \t$(iob update -u | grep -c 'Updatable\|Updateable')";
if [[ -f "/var/run/reboot-required" ]]; then
        echo "";
        echo "This system needs to be REBOOTED NOW!";
        echo "";
fi

echo "";
echo -e "Nodejs-Installation:";
if [ "$PATHNODEJS" = "" ];
then
        echo -e "nodejs: \t\tN/A";
else
        echo -e "$(type -P nodejs) \t$(nodejs -v)";
        VERNODEJS=$(nodejs -v);
fi;

if [ "$PATHNODE" = "" ];
then
        echo -e "node: \t\tN/A";

else
        echo -e "$(type -P node) \t\t$(node -v)";
        VERNODE=$(node -v);
fi;

if [ "$PATHNPM" = "" ];
then
        echo -e "npm: \t\t\tN/A";
else
        echo -e "$(type -P npm) \t\t$(npm -v)";
        VERNPM=$(npm -v);
fi;

if [ "$PATHNPX" = "" ];
then
        echo -e "npx: \t\t\tN/A";

else
        echo -e "$(type -P npx) \t\t$(npx -v)";
        VERNPX=$(npx -v);
fi;

if [ "$PATHCOREPACK" = "" ];
then
        echo -e "corepack: \tN/A";

else
        echo -e "$(type -P corepack) \t$(corepack -v)";
        # VERCOREPACK=$(corepack -v);
fi;

echo -e "";
echo -e "Recommended versions are nodejs ""$NODERECOM"" and npm ""$NPMRECOM""";

if
        [[ $PATHNODEJS != "/usr/bin/nodejs" ]];
        then
                echo "*** nodejs is NOT correctly installed ***";
                echo "Wrong installation path detected. This needs to be fixed.";
        elif
        [[ $PATHNODE != "/usr/bin/node" ]];
        then
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
        elif
        [[ $PATHNPM != "/usr/bin/npm" ]];
        then
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
        elif
        [[ $PATHNPX != "/usr/bin/npx" ]];
        then
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
         elif
        [[ $PATHCOREPACK != "/usr/bin/corepack" ]];
        then
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed";
        elif
        [[ $VERNODEJS != "$VERNODE" ]];
        then
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "nodejs and node versions do not match. This needs to be fixed.";
        elif
        [[ $VERNPM != "$VERNPX" ]];
        then
                echo -e "\033[0;31mnodejs is NOT correctly installed\033[0m";
                echo "npm and npx versions do not match. This needs to be fixed.";
        else
                echo "Your nodejs installation is correct";
fi
if [[ $NODENOTCORR -eq 1 ]];
then
                echo "";
                echo "Please execute";
                echo "iobroker nodejs-update";
                echo "to fix these errors."
fi;
echo "";
# echo -e "Total Memory: \t\t`free -h | awk '/^Mem:/{print $2}'`";
echo "MEMORY: ";
        free -ht --mega;
echo "";
echo -e "Active iob-Instances: \t$(echo "$IOBLISTINST" | grep -c ^+)";
        iob repo list | tail -n1;
echo "";
echo -e "ioBroker Core: \t\tjs-controller \t\t$(iob -v)";
echo -e "\t\t\tadmin \t\t\t$(iob version admin)";
echo "";
echo -e "ioBroker Status: \t$(iobroker status)";
echo "";
# iobroker status all | grep MULTIHOSTSERVICE/enabled;
echo "Status admin and web instance:";
echo "$IOBLISTINST" | grep 'admin.\|system.adapter.web.';
echo "";
echo -e "Objects: \t\t$IOBOBJECTS";
echo -e "States: \t\t$IOBSTATES";
echo "";
echo -e "Size of iob-Database:";
echo "";
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*objects\* -exec du -sh {} + |sort -rh | head -n 5;
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*states\* -exec du -sh {} + |sort -rh | head -n 5;
echo "";
echo "";
if [[ $ANZNPMTMP -gt 0 ]]
then
        echo -e "*********************************************************************";
        echo -e "Some problems detected, please run \e[031miob fix\e[0m and try to have them fixed";
        echo -e "*********************************************************************";
        echo -e "";
else
        echo ""
fi;

for x in $EOLDEB; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[31mDebian Release '$CODENAME' reached its END OF LIFE and needs to be updated to the latest stable release '$DEBSTABLE' NOW!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $EOLUBU; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[31mUbuntu Release '$CODENAME' reached its END OF LIFE and needs to be updated to the latest LTS release '$UBULTS' NOW!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $DEBSTABLE; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[32mYour Operating System is the current Debian stable version '$DEBSTABLE'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $UBULTS; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[32mYour Operating System is the current Ubuntu LTS release '$UBULTS'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $OLDLTS; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[1;33mYour Operating System '$OLDLTS' is an aging Ubuntu LTS release! Please upgrade to the latest LTS release '$UBULTS' in due time!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $TESTING; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[1;33mYour Operating System codenamed '$CODENAME' is not released yet! Please use it only for testing purposes!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for x in $OLDSTABLE; do
    if [ $x = "$CODENAME" ]; then
        echo -e "\e[1;33mDebian '$OLDSTABLE' is the current oldstable version. Please upgrade to the latest stable release '$DEBSTABLE' in due time!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

if [ $UNKNOWNRELEASE -eq 1 ]; then
    echo "Unknown release name: $CODENAME. Please check yourself if your Operating System is maintained."
fi;


echo "=================== END OF SUMMARY ===================="
echo -e "\`\`\`";
echo "";
echo "=== Mark text until here for copying ===";
exit;
