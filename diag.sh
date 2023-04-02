#!/bin/bash
# iobroker diagnostics
# written to help getting information about the environment the ioBroker installation is running in
clear;

# VARIABLES
export LC_ALL=C;
SKRIPTV="2023-04-02"; #version of this script
NODERECOM="18";  #recommended node version
NPMRECOM="9";    #recommended npm version
XORGTEST=0;      #test for GUI
DOCKER=/opt/scripts/.docker_config/.thisisdocker;
APT=0;
INSTENV=0;
INSTENV2=0;
SYSTDDVIRT=0;
#if [ $EUID -eq 0 ] | [ ! -f "$DOCKER" ]; then
#  echo -e "Dieses Skript darf nicht von root ausgeführt werden! \nBitte als Standarduser ausführen!" 1>&2
#  exit 1
#fi

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
read -n 1 -s
	clear;
echo "";
echo -e "\033[33m======== Start marking the full check here =========\033[0m";
echo "";
echo "\`\`\`";
echo -e "Skript v.`echo $SKRIPTV`"
echo "";
echo -e "\033[34;107m*** BASE SYSTEM ***\033[0m";
grep Model /proc/cpuinfo;
echo -e "Architecture    : `uname -m`";

if [ -f "$DOCKER" ]; then
    echo -e "Docker          : `cat /opt/scripts/.docker_config/.thisisdocker`"
else
    echo -e "Docker          : false"
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
    echo -e "Virtualization  : `systemd-detect-virt`"
else
    echo "Virtualization  : Unknown (buanet/Synology?)"
fi;
	lsb_release -idrc;
echo "";
        cat /etc/os-release;
echo "";
echo "Systemuptime and Load:";
        uptime;
echo "CPU threads: $(grep -c processor /proc/cpuinfo)"
echo "";
echo -e "\033[34;107m*** Time and Time Zones ***\033[0m";
        timedatectl;
echo "";
echo -e "\033[34;107m*** User and Groups ***\033[0m";
        whoami;
        echo $HOME;
        groups;
echo "";
echo -e "\033[34;107m*** X-Server-Setup ***\033[0m";

XORGTEST=`ps aux | grep -c 'Xorg'`
if (("$XORGTEST" > 1)); then
    echo -e "X-Server: \ttrue"
else
    echo -e "X-Server: \tfalse"
fi
echo -e "Desktop: \t$DESKTOP_SESSION";
echo -e "Terminal: \t$XDG_SESSION_TYPE";
echo -e "Boot Target: \t`systemctl get-default`";
echo "";
echo -e "\033[34;107m*** MEMORY ***\033[0m";
        free -th --mega;
echo "";
        vmstat -S M -s | head -n 10;
echo "";
echo -e "\033[34;107m*** FILESYSTEM ***\033[0m";
        df -PTh;
echo "";
echo -e "\033[32mMessages concerning ext4 filesystem in dmesg:\033[0m";
sudo dmesg -T | grep -i ext4;
echo "";
echo -e "\033[32mShow mounted filesystems (real ones only):\033[0m";
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
echo -e "\033[34;107m*** NodeJS-Installation ***\033[0m";
echo "";
sudo ln -s /usr/bin/node /usr/bin/nodejs &> /dev/null;
echo -e "`type -P nodejs` \t`nodejs -v`";
echo -e "`type -P node` \t\t`node -v`";
echo -e "`type -P npm` \t\t`npm -v`";
echo -e "`type -P npx` \t\t`npx -v`";
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


echo -e "\033[32mTemp directories causing npm8 problem:\033[0m `find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium' | wc -l`";
# echo "";
echo -e "Temp directories being cleaned up now `find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \;`";
# find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \ &> /dev/null;
# echo -e "\033[32m1 - Temp directories causing npm8 problem:\033[0m `find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium'>e;
echo "";
echo -e "\033[34;107m*** ioBroker-Installation ***\033[0m";
echo "";
echo -e "\033[32mioBroker Status\033[0m";
iobroker status;
echo "";
echo -e "\033[32mCore adapters versions\033[0m"
echo -e "js-controller: \t`iob -v`";
echo -e "admin: \t\t`iob version admin`";
echo -e "javascript: \t`iob version javascript`";
echo "";
echo -e "Adapters from github: \t`(cd /opt/iobroker && npm ls | grep -c 'git')`";
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
echo -e "Objects: \t`echo $IOBOBJECTS`";
IOBSTATES=$(iob list states 2>/dev/null | wc -l);
echo -e "States: \t`echo $IOBSTATES`";
echo "";
echo -e "\033[34;107m*** OS-Repositories and Updates ***\033[0m";
        sudo apt-get update 1>/dev/null && sudo apt-get update
        APT=`apt-get upgrade -s |grep -P '^\d+ upgraded'|cut -d" " -f1`
echo -e "Pending Updates: `echo $APT`";
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
	read -n 1 -s
echo "";
        clear;
echo "Copy text starting here:";
echo "";
echo "\`\`\`";
echo "======================= SUMMARY =======================";
echo -e "\t\t`echo "     "v.$SKRIPTV`"
echo "";
echo "";
echo -e "Operatingsystem: `lsb_release -d | tr -s ' ' | cut -d: -f 2`"
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
        echo $SYSTDDVIRT;
else
        echo "Native";
fi;)
echo -e "Kernel: \t\t`uname -r`";
echo -e "Installation: \t\t`echo $INSTENV2`";
echo -e "Timezone: \t\t`timedatectl | grep zone | cut -c28-80`";
echo -e "User-ID: \t\t`echo $EUID`";
echo -e "X-Server: \t\t`if [[ $XORGTEST -gt 1 ]]; then echo "true";else echo "false";fi`";
echo -e "Boot Target: \t\t`systemctl get-default`";
echo "";
echo -e "Pending OS-Updates: \t`echo $APT`";
echo -e "Pending iob updates: \t`iob update -u | grep -c 'Updatable\|Updateable'`";
echo "";
echo -e "Nodejs-Installation: \t`type -P nodejs` \t`nodejs -v`";
echo -e "\t\t\t`type -P node` \t\t`node -v`";
echo -e "\t\t\t`type -P npm` \t\t`npm -v`";
echo -e "\t\t\t`type -P npx` \t\t`npx -v`";
echo -e "";
echo -e "Recommended versions are nodejs "$NODERECOM".x.y and npm "$NPMRECOM".x.y";
echo "";
# echo -e "Total Memory: \t\t`free -h | awk '/^Mem:/{print $2}'`";
echo "MEMORY: ";
        free -ht --mega;
echo "";
echo -e "Active iob-Instances: \t`iob list instances | grep ^+ | wc -l`";
	iob repo list | tail -n1;
echo "";
echo -e "ioBroker Core: \t\tjs-controller \t\t`iob -v`";
echo -e "\t\t\tadmin \t\t\t`iob version admin`";
echo "";
echo -e "ioBroker Status: \t`iobroker status`";
# iobroker status;
echo "";
echo "Status admin and web instance:";
iobroker list instances | grep 'admin.\|web.'
echo "";
echo -e "Objects: \t\t`echo $IOBOBJECTS`";
echo -e "States: \t\t`echo $IOBSTATES`";
echo "";
echo -e "Size of iob-Database:";
echo "";
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*objects\* -exec du -sh {} + |sort -rh | head -n 5;
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*states\* -exec du -sh {} + |sort -rh | head -n 5;
echo "";
echo "";
echo "=================== END OF SUMMARY ===================="
echo -e "\`\`\`";
echo "";
unset LC_ALL
exit;
