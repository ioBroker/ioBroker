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
                        echo -e "You should not use root directly on your system!\nBetter use your standard user!\n\n";
                        sleep 5;
fi

clear;
echo "*** iob diag is starting up, please wait ***";
# VARIABLES
export LC_ALL=C;
SKRIPTV="2023-10-16";      #version of this script
NODE_MAJOR=18           #this is the recommended major nodejs version for ioBroker, please adjust accordingly if the recommendation changes

HOST=$(hostname)
NODERECOM=$(iobroker state getValue system.host."$HOST".versions.nodeNewestNext);  #recommended node version
NPMRECOM=$(iobroker state getValue system.host."$HOST".versions.npmNewestNext);    #recommended npm version
NODEUSED=$(iobroker state getValue system.host."$HOST".versions.nodeCurrent);      #current node version in use
#NPMUSED=$(iobroker state getValue system.host."$HOST".versions.npmCurrent);        #current npm version in use
XORGTEST=0;      #test for GUI
APT=0;
INSTENV=0;
INSTENV2=0;
SYSTDDVIRT="";
NODENOTCORR=0;
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
echo "\`\`\`";
echo "Skript v.$SKRIPTV"
echo "";
echo -e "\033[34;107m*** BASE SYSTEM ***\033[0m";

if [ -f "$DOCKER" ]; then
echo -e "Hardware Vendor : $(cat /sys/devices/virtual/dmi/id/sys_vendor)";
echo -e "Kernel          : $(uname -m)";
echo -e "Userland        : $(dpkg --print-architecture)";
echo -e "Docker          : $(cat /opt/scripts/.docker_config/.thisisdocker)"
else
        hostnamectl | grep -v 'Machine\|Boot';
        echo "";
        grep -i model /proc/cpuinfo | tail -1;
        echo -e "Docker          : false";
fi;
# Alternativer DockerCheck - Nicht getestet:
#
# if [ -f /.dockerenv ]; then
#    echo "I'm inside matrix ;(";
# else
#    echo "I'm living in real world!";
# fi

SYSTDDVIRT=$(systemd-detect-virt 2>/dev/null)
if [ "$SYSTDDVIRT" != "" ]; then
    echo -e "Virtualization  : $(systemd-detect-virt)"
else
    echo "Virtualization  : Docker"
fi;
echo -e "Kernel          : $(uname -m)";
echo -e "Userland        : $(dpkg --print-architecture)";
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

echo "";
echo -e "\033[34;107m*** User and Groups ***\033[0m";
        whoami;
        echo "$HOME";
        groups;
echo "";

echo -e "\033[34;107m*** X-Server-Setup ***\033[0m";
XORGTEST=$(pgrep -fc 'Xorg|wayland|X11')
if [[ "$XORGTEST" -gt 0 ]];
        then
                echo -e "X-Server: \ttrue"
        else
                echo -e "X-Server: \tfalse"
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
        vmstat -S M -s | head -n 10;

# RASPBERRY only
if [[ $(type -P "vcgencmd" 2>/dev/null) = *"/vcgencmd" ]]; then
        echo "";
        echo "Raspberry only:";
        vcgencmd mem_oom;
fi;

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
findmnt;
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
echo "USB-Sticks -  Avoid direct links to /dev/* in your adapter setups, please always prefer the links 'by-id':";
echo "";
find /dev/serial/by-id/ -maxdepth 1 -mindepth 1;
echo "";

echo -e "\033[34;107m*** NodeJS-Installation ***\033[0m";
echo "";
echo -e "$(type -p nodejs) \t$(nodejs -v)";
echo -e "$(type -p node) \t\t$(node -v)";
echo -e "$(type -p npm) \t\t$(npm -v)";
echo -e "$(type -p npx) \t\t$(npx -v)";
echo -e "$(type -p corepack) \t$(corepack -v)";
PATHAPT=$(type -p apt);
PATHNODEJS=$(type -p nodejs);
PATHNODE=$(type -p node);
PATHNPM=$(type -p npm);
PATHNPX=$(type -p npx);
PATHCOREPACK=$(type -p corepack);
VERNODEJS=$(nodejs -v);
VERNODE=$(node -v);
VERNPM=$(npm -v);
VERNPX=$(npx -v);
#VERCOREPACK=$(corepack -v);

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
        apt-cache policy nodejs;
echo "";
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
cd /opt/iobroker && npm ls -a | grep ERR;
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
echo -e "Adapters from github: \t$( (cd /opt/iobroker && npm ls | grep -c 'git') )";
echo "";
echo -e "\033[32mAdapter State\033[0m";
iob list instances;
echo "";
echo -e "\033[32mEnabled adapters with bindings\033[0m";
iob list instances | grep enabled | grep port ;
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
        sudo apt-get update 1>/dev/null && sudo apt-get update
        APT=$(apt-get upgrade -s |grep -P '^\d+ upgraded'|cut -d" " -f1)
echo -e "Pending Updates: $APT";
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
echo "\`\`\`";
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
echo -e "Userland: \t\t$(dpkg --print-architecture)";
if [ -f "$DOCKER" ]; then
    echo -e "Timezone: \t\t$(cat /etc/timezone)"
else
    echo -e "Timezone: \t\t$(timedatectl | grep zone | cut -c28-80)";
fi;
echo -e "User-ID: \t\t$EUID";
echo -e "X-Server: \t\t$(if [[ $XORGTEST -gt 0 ]]; then echo "true";else echo "false";fi)";
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
echo -e "Nodejs-Installation: \t$( type -p nodejs ) \t$( nodejs -v )";
echo -e "\t\t\t$(type -P node) \t\t$(node -v)";
echo -e "\t\t\t$(type -P npm) \t\t$(npm -v)";
echo -e "\t\t\t$(type -P npx) \t\t$(npx -v)";
echo -e "\t\t\t$(type -P corepack) \t$(corepack -v)";
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
                echo "Please check";
                echo "https://forum.iobroker.net/topic/35090/howto-nodejs-installation-und-upgrades-unter-debian";
                echo "for more information on how to fix these errors or run:";
                echo "iobroker nodejs-update";
fi;
echo "";
# echo -e "Total Memory: \t\t`free -h | awk '/^Mem:/{print $2}'`";
echo "MEMORY: ";
        free -ht --mega;
echo "";
echo -e "Active iob-Instances: \t$(iob list instances | grep -c ^+)";
        iob repo list | tail -n1;
echo "";
echo -e "ioBroker Core: \t\tjs-controller \t\t$(iob -v)";
echo -e "\t\t\tadmin \t\t\t$(iob version admin)";
echo "";
echo -e "ioBroker Status: \t$(iobroker status)";
echo "";
# iobroker status all | grep MULTIHOSTSERVICE/enabled;
echo "Status admin and web instance:";
iobroker list instances | grep 'admin.\|system.adapter.web.'
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

echo "=================== END OF SUMMARY ===================="
echo -e "\`\`\`";
echo "";
echo "=== Mark text until here for copying ===";
exit;
