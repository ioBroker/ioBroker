#!/bin/bash
# iobroker diagnostics
# written to help getting information about the environment the ioBroker installation is running in
DOCKER=/opt/scripts/.docker_config/.thisisdocker
#if [[ -f "/opt/scripts/.docker_config/.thisisdocker" ]]
if [ "$(id -u)" = 0 ] && [ ! -f "$DOCKER" ];
        then
                echo -e "You should not be root on your system!\nBetter use your standard user!\n\n";
                sleep 15;
fi;
clear;
SKRPTLANG=$1;
if [[ "$SKRPTLANG" = "--de" ]]; then
                echo "*** iog diag startet, bitte etwas warten ***"
        else
                echo "*** iob diag is starting up, please wait ***";
fi;
# VARIABLES
export LC_ALL=C;
SKRIPTV="2024-09-07";      #version of this script
#NODE_MAJOR=20           this is the recommended major nodejs version for ioBroker, please adjust accordingly if the recommendation changes

HOST=$(uname -n);
ID_LIKE=$(awk -F= '$1=="ID_LIKE" { print $2 ;}' /etc/os-release | xargs);
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
if [[ "$SKRPTLANG" == "--de" ]]; then
echo "";
echo -e "\033[34;107m*** ioBroker Diagnose ***\033[0m";
echo "";
echo "Das Fenster des Terminalprogramms (puTTY) bitte so groß wie möglich ziehen oder den Vollbildmodus verwenden.";
echo "";
echo "Die nachfolgenden Prüfungen liefern Hinweise zu etwaigen Fehlern, bitte im Forum hochladen:";
echo "";
echo "https://forum.iobroker.net";
echo "";
echo "Bitte die vollständige Ausgabe, einschließlich der \`\`\` Zeichen am Anfang und am Ende markieren und kopieren.";
echo "Es hilft beim helfen!"
echo "";
     # read -p "Press <Enter> to continue";
echo "Bitte eine Taste drücken";
read -r -n 1 -s
        clear;
echo "";
else
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
fi;

if [[ "$SKRPTLANG" == "--de" ]]; then
echo -e "\033[33m========== Langfassung ab hier markieren und kopieren ===========\033[0m";
echo "";
echo "\`\`\`bash";
echo "Skript v.$SKRIPTV"
echo "";
echo -e "\033[34;107m*** GRUNDSYSTEM ***\033[0m";
else
echo -e "\033[33m========== Start marking the full check here ===========\033[0m";
echo "";
echo "\`\`\`bash";
echo "Script v.$SKRIPTV"
echo "";
echo -e "\033[34;107m*** BASE SYSTEM ***\033[0m";
fi;

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
echo "";

if [[ "$SKRPTLANG" == "--de" ]]; then

echo -e "\033[34;107m*** LEBENSZYKLUS STATUS ***\033[0m";

for RELEASE in $EOLDEB; do
    if [ "$RELEASE" = "$CODENAME" ]; then
        RELEASESTATUS="\e[31mDas Debian Release '$CODENAME' hat sein Lebensende erreicht und muss JETZT auf die aktuelle stabile Veröffentlichung '$DEBSTABLE' gebracht werden!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $EOLUBU; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[31mDas Ubuntu Release '$CODENAME' hat sein Lebensende erreicht und muss JETZT auf die aktuelle Version '$UBULTS' mit Langzeitunterstützung gebracht werden.\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $DEBSTABLE; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[32mDas Betriebssystem ist das aktuelle, stabile Debian '$DEBSTABLE'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $UBULTS; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[32mDas Betriebssystem ist die aktuelle  Ubuntu LTS Version '$UBULTS'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $OLDLTS; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[1;33mDie Unterstützung für das Betriebssystem mit dem Codenamen '$CODENAME' läuft aus. Es sollte in nächster Zeit auf die aktuelle Version '$UBULTS' mit Langzeitunterstützung gebracht werden.\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $TESTING; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[1;33mDas Betriebssystem mit dem Codenamen '$CODENAME' ist eine Testversion! Es sollte nur zu Testzwecken eingesetzt werden!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $OLDSTABLE; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[1;33mDebian '$OLDSTABLE' ist eine veraltete Version. Es sollte in nächster Zeit auf die aktuelle stabile Version '$DEBSTABLE' gebracht werden!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

if [ $UNKNOWNRELEASE -eq 1 ]; then
    RELEASESTATUS="Das Betriebssystem mit dem Codenamen '$CODENAME' ist unbekannt. Bitte den Status der Unterstützung eigenständig prüfen."
fi;

echo -e "$RELEASESTATUS";

else
echo -e "\033[34;107m*** LIFE CYCLE STATUS ***\033[0m";

for RELEASE in $EOLDEB; do
    if [ "$RELEASE" = "$CODENAME" ]; then
        RELEASESTATUS="\e[31mDebian Release codenamed '$CODENAME' reached its END OF LIFE and needs to be updated to the latest stable release '$DEBSTABLE' NOW!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $EOLUBU; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[31mUbuntu Release codenamed '$CODENAME' reached its END OF LIFE and needs to be updated to the latest LTS release '$UBULTS' NOW!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $DEBSTABLE; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[32mOperating System is the current Debian stable version codenamed '$DEBSTABLE'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $UBULTS; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[32mOperating System is the current Ubuntu LTS release codenamed '$UBULTS'!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $OLDLTS; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[1;33mOperating System codenamed '$CODENAME' is an aging Ubuntu LTS release! Please upgrade to the latest LTS release '$UBULTS' in due time!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $TESTING; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[1;33mOperating System codenamed '$CODENAME' is a testing release! Please use it only for testing purposes!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

for RELEASE in $OLDSTABLE; do
    if [ "$RELEASE" == "$CODENAME" ]; then
        RELEASESTATUS="\e[1;33mDebian '$OLDSTABLE' is the current oldstable version. Please upgrade to the latest stable release '$DEBSTABLE' in due time!\e[0m";
        UNKNOWNRELEASE=0;
    fi;
done;

if [ $UNKNOWNRELEASE -eq 1 ]; then
    RELEASESTATUS="Unknown release codenamed '$CODENAME'. Please check yourself if the Operating System is actively maintained."
fi;

echo -e "$RELEASESTATUS";
fi;
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

if [[ "$SKRPTLANG" = "--de" ]]; then
        if [[ -f "/var/run/reboot-required" ]]; then
                echo "";
                echo "This system needs to be REBOOTED!";
                echo "";
        fi
        else
        if [[ -f "/var/run/reboot-required" ]]; then
                echo "";
                echo "Dieses System benötigt einen NEUSTART!";
                echo "";
        fi
fi;

echo "";

if [[ "$SKRPTLANG" = "--de" ]]; then
echo -e "\033[34;107m*** ZEIT UND ZEITZONEN ***\033[0m";

        if [ -f "$DOCKER" ]; then
                date -u;
                date;
                date +"%Z %z";
                cat /etc/timezone;
        else
                timedatectl;
        fi;

        if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
                echo "Die gesetzte Zeitzone ist vermutlich falsch. Soll sie jetzt geändert werden? (j/n)"
                read -r -s -n 1 char;
                if
                [[ "$char" = "j" ]] || [[ "$char" = "J" ]]
                then
                        if command -v dpkg-reconfigure > /dev/null; then
                        sudo dpkg-reconfigure tzdata;
                        else
                # Setup the timezone for the server (Default value is "Europe/Berlin")
                echo "Setzen der Zeitzone";
                read -p "Eingabe der Zeitzone (Voreinstellung ist Europe/Berlin): " TIMEZONE;
                TIMEZONE=${TIMEZONE:-"Europe/Berlin"};
                sudo timedatectl set-timezone $TIMEZONE;
                        fi;
                # Set up time synchronization with systemd-timesyncd
                echo "Zeitsynchronisierung mittels systemd-timesyncd wird eingerichtet"
                sudo systemctl enable systemd-timesyncd
                sudo systemctl start systemd-timesyncd
                fi;
        fi;
else

echo -e "\033[34;107m*** TIME AND TIMEZONES ***\033[0m";

if [ -f "$DOCKER" ]; then
        date -u;
        date;
        date +"%Z %z";
        cat /etc/timezone;
else
    timedatectl;
fi;

if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
echo "Timezone is probably wrong. Do you want to reconfigure it? (y/n)"
read -r -s -n 1 char;
        if
                [[ "$char" = "y" ]] || [[ "$char" = "Y" ]]
        then
                if command -v dpkg-reconfigure > /dev/null; then
                sudo dpkg-reconfigure tzdata;
                else
                # Setup the timezone for the server (Default value is "Europe/Berlin")
                echo "Setting up timezone";
                read -p "Enter the timezone for the server (default is Europe/Berlin): " TIMEZONE;
                TIMEZONE=${TIMEZONE:-"Europe/Berlin"};
                sudo timedatectl set-timezone $TIMEZONE;
                fi;
                # Set up time synchronization with systemd-timesyncd
                echo "Setting up time synchronization with systemd-timesyncd"
                sudo systemctl enable systemd-timesyncd
                sudo systemctl start systemd-timesyncd

        fi;
fi;
fi;

echo "";
if [[ "$SKRPTLANG" = "--de" ]]; then
echo -e "\033[34;107m*** User und Gruppen ***\033[0m";
        echo "User der 'iob diag' aufgerufen hat:";
        whoami;
        env | grep HOME;
        echo "GROUPS=$(groups)";
        echo "";
        echo "User der den 'js-controller' ausführt:";
        if [[ $(pidof iobroker.js-controller) -gt 0 ]];
        then
                IOUSER=$(ps -o user= -p "$(pidof iobroker.js-controller)")
                echo "$IOUSER";
                sudo -H -u "$IOUSER" env | grep HOME;
                echo "GROUPS=$(sudo -u "$IOUSER" groups)"
        else
         echo "js-controller läuft nicht";
        fi;

echo "";

if [ ! -f "$DOCKER" ] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then

# Prompt for username
echo "Es sollte ein Standarduser angelegt werden! Dieser user kann dann auch mittels 'sudo' temporär root-Rechte erlangen!"
echo "Ein permanentes Login als root ist nicht vorgesehen."
read -p "Neuer Nutzername (Nicht 'root' und nicht 'iobroker'!): " USERNAME

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
    echo "Nutzer $USERNAME existiert bereits. Überspringe die Neuanlage."
else
    # Prompt for password
    read -s -p "Passwort für den neuen Nutzer: " PASSWORD
    echo
    read -s -p "Passwort für den neuen Nutzer nochmal eingeben: " PASSWORD_CONFIRM
    echo

    # Check if passwords match
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "Passwort stimmt nicht überein. Breche ab."
        exit 1
    fi

    # Add a new user account with sudo access and set the password
    echo "Neuer Nutzer wird angelegt. Bitte künftig nur noch diesen Nutzer verwenden."
    useradd -m -s /bin/bash -G adm,dialout,sudo,audio,video,plugdev,users,iobroker $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
fi

fi;
else
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

if [ ! -f "$DOCKER" ] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then

# Prompt for username
echo "A default user should be created! This user will be enabled to temporarily switch to root via 'sudo'!"
echo "A root login is not required in most Linux Distributions."
read -p "Enter the username for a new user (Not 'root' and not 'iobroker'!): " USERNAME

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists. Skipping user creation."
else
    # Prompt for password
    read -s -p "Enter the password for the new user: " PASSWORD
    echo
    read -s -p "Confirm the password for the new user: " PASSWORD_CONFIRM
    echo

    # Check if passwords match
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "Passwords do not match. Exiting."
        exit 1
    fi

    # Add a new user account with sudo access and set the password
    echo "Adding new user account..."
    useradd -m -s /bin/bash -G adm,dialout,sudo,audio,video,plugdev,users,iobroker $USERNAME
    echo "$USERNAME:$PASSWORD" | chpasswd
fi

fi;
fi;
echo -e "\033[34;107m*** DISPLAY-SERVER SETUP ***\033[0m";
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

echo "";
echo -e "\033[34;107m*** DMESG CRITICAL ERRORS ***\033[0m";
echo "";
CRITERROR=$(sudo dmesg --level=emerg,alert,crit -T | wc -l);
if [[ "$CRITERROR" -gt 0 ]]; then
        if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "Es wurden "$CRITERROR" KRITISCHE FEHLER gefunden. \nSiehe 'sudo dmesg --level=emerg,alert,crit -T' für Details"
        else
                echo -e ""$CRITERROR" CRITICAL ERRORS DETECTED! \nCheck 'sudo dmesg --level=emerg,alert,crit -T' for details";
        fi;
else
        if [[ "$SKRPTLANG" = "--de" ]]; then
                echo "Es wurden keine kritischen Fehler gefunden"
        else
                echo "No critical errors detected"
        fi;
fi;
echo "";

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
if [ ! -f "$DOCKER" ]; then
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
IOBZIGBEEPORT3=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.3 | awk -F ':' '{print $4}' | cut -c 2-)


if [[ -n "$SYSZIGBEEPORT" ]];
        then
                echo "$SYSZIGBEEPORT";
        else
                echo "No Devices found 'by-id'";
fi;

if  [[ -n "$IOBZIGBEEPORT0" ]]; then
        if [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT0"* ]]
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
fi;
if  [[ -n "$IOBZIGBEEPORT1" ]]; then
        if [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT1"* ]]
        then
                echo "";
                echo "Your zigBee.1 COM-Port is matching 'by-id'. Very good!";
        else
                echo;
                echo "HINT:";
                echo "Your zigbee.1 COM-Port is NOT matching 'by-id'. Please check your setting:";
                echo "$IOBZIGBEEPORT1";
                # diff -y --left-column <(echo "$IOBZIGBEEPORT1") <(echo "$SYSZIGBEEPORT");
        fi;
fi;
if  [[ -n "$IOBZIGBEEPORT2" ]]; then
        if [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT2"* ]]
        then
                echo "";
                echo "Your zigBee.2 COM-Port is matching 'by-id'. Very good!";
        else
                echo;
                echo "HINT:";
                echo "Your zigbee.2 COM-Port is NOT matching 'by-id'. Please check your setting:";
                echo "$IOBZIGBEEPORT2";
                # diff -y --left-column <(echo "$IOBZIGBEEPORT2") <(echo "$SYSZIGBEEPORT");
        fi;
fi;
if  [[ -n "$IOBZIGBEEPORT3" ]]; then
        if [[ "$SYSZIGBEEPORT" == *"$IOBZIGBEEPORT3"* ]]
        then
                echo "";
                echo "Your zigbee.3 COM-Port is matching 'by-id'. Very good!";
        else
                echo;
                echo "HINT:";
                echo "Your zigbee.3 COM-Port is NOT matching 'by-id'. Please check your setting:";
                echo "$IOBZIGBEEPORT3";
                # diff -y --left-column <(echo "$IOBZIGBEEPORT0") <(echo "$SYSZIGBEEPORT");
        fi;
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


if [[ -z "$PATHNODEJS" ]];
then
        echo -e "nodejs: \t\tN/A";
else
        echo -e "$(type -P nodejs) \t$(nodejs -v)";
        VERNODEJS=$(nodejs -v);
fi;

if [[ -z "$PATHNODE"  ]];
then
        echo -e "node: \t\tN/A";

else
        echo -e "$(type -P node) \t\t$(node -v)";
        VERNODE=$(node -v);
fi;

if [[ -z "$PATHNPM" ]];
then
        echo -e "npm: \t\t\tN/A";
else
        echo -e "$(type -P npm) \t\t$(npm -v)";
        VERNPM=$(npm -v);
fi;

if [[ -z "$PATHNPX" ]];
then
        echo -e "npx: \t\t\tN/A";

else
        echo -e "$(type -P npx) \t\t$(npx -v)";
        VERNPX=$(npx -v);
fi;

if [[ -z "$PATHCOREPACK" ]];
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
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
        elif
        [[ $PATHNODE != "/usr/bin/node" ]];
        then
                NODENOTCORR=1
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
        elif
        [[ $PATHNPM != "/usr/bin/npm" ]];
        then
                NODENOTCORR=1
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
        elif
        [[ $PATHNPX != "/usr/bin/npx" ]];
        then
                NODENOTCORR=1
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
        elif
        [[ $VERNODEJS != "$VERNODE" ]];
        then
                NODENOTCORR=1
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
        elif
        [[ $VERNPM != "$VERNPX" ]];
        then
                NODENOTCORR=1
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
        elif
        [[ $PATHCOREPACK != "/usr/bin/corepack" ]];
        then
                NODENOTCORR=1
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                fi;
fi;

echo "";
if [ -f /usr/bin/apt-cache ];
then
        apt-cache policy nodejs;
        echo "";
fi;

ANZNPMTMP=$(find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium' | wc -l);
echo -e "\033[32mTemp directories causing deletion problem:\033[0m ""$ANZNPMTMP""";
if [[ $ANZNPMTMP -gt 0 ]];
then
        echo -e "Some problems detected, please run \e[031miob fix\e[0m";
else
        echo "No problems detected";
fi;

# echo "";
# echo -e "Temp directories being cleaned up now `find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \;`";
# find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \ &> /dev/null;
# echo -e "\033[32m1 - Temp directories causing npm8 problem:\033[0m `find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium'>e;
echo "";
if [[ $(echo "$NPMLS" | grep ERR -wc -l) -gt 0 ]];
then
        echo -e "\033[322mErrors in npm tree:\033[0m";
        echo "$NPMLS" | grep ERR;
        echo "";
else
        echo -e "\033[32mErrors in npm tree:\033[0m 0";
        echo "No problems detected";
        echo "";
fi;
echo -e "\033[34;107m*** ioBroker-Installation ***\033[0m";
echo "";
echo -e "\033[32mioBroker Status\033[0m";
iob status;
echo -e "\nHosts:";
iob list hosts;
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
if [ -f /usr/bin/apt-get ];
then
        sudo apt-get update 1>/dev/null && sudo apt-get update
        APT=$(apt-get upgrade -s |grep -P '^\d+ upgraded'|cut -d" " -f1)
        if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "Offene Systemupdates: $APT";
        else
        echo -e "Pending Updates: $APT";
        fi;
else
        if [[ "$SKRPTLANG" = "--de" ]]; then
        echo "Es wurde kein auf Debian basierendes System erkannt";
        else
        echo "No Debian-based Linux detected.";
        fi;
fi;


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
 if [[ "$SKRPTLANG" = "--de" ]]; then
 echo -e "\033[33m============ Langfassung bis hier markieren =============\033[0m";
echo "";
echo "iob diag hat das System inspiziert.";
echo "";
echo "";
echo "Beliebige Taste für eine Zusammenfassung drücken";
 else
echo -e "\033[33m============ Mark until here for C&P =============\033[0m";
echo "";
echo "iob diag has finished.";
echo "";
echo "";
echo "Press any key for a summary";
fi;
        read -r -n 1 -s
echo "";
        clear;
if [[ "$SKRPTLANG" = "--de" ]]; then
       echo "Zusammfassung ab hier markieren und kopieren:";
echo "";
echo "\`\`\`bash";
echo "===================== ZUSAMMENFASSUNG =====================";
echo -e "\t\t\tv.$SKRIPTV"
echo "";
echo "";
else
echo "Copy text starting here:";
echo "";
echo "\`\`\`bash";
echo "======================= SUMMARY =======================";
echo -e "\t\t\tv.$SKRIPTV"
echo "";
echo "";
fi;
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
if [[ "$SKRPTLANG" = "--de" ]]; then
echo -e "Offene OS-Updates: \t$APT";
echo -e "Offene iob updates: \t$(iob update -u | grep -c 'Updatable\|Updateable')";
else
echo -e "Pending OS-Updates: \t$APT";
echo -e "Pending iob updates: \t$(iob update -u | grep -c 'Updatable\|Updateable')";
fi;
if [[ -f "/var/run/reboot-required" ]]; then
        if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\nDas System muss JETZT neugestartet werden!";
                echo "";
        else
                echo -e "\nThis system needs to be REBOOTED NOW!";
                echo "";
        fi;
fi;
echo -e "\nNodejs-Installation:";
if [[ -z "$PATHNODEJS" ]];
then
        echo -e "nodejs: \t\tN/A";
else
        echo -e "$(type -P nodejs) \t$(nodejs -v)";
        VERNODEJS=$(nodejs -v);
fi;

if [[ -z "$PATHNODE" ]];
then
        echo -e "node: \t\t\tN/A";

else
        echo -e "$(type -P node) \t\t$(node -v)";
        VERNODE=$(node -v);
fi;

if [[ -z "$PATHNPM" ]];
then
        echo -e "npm: \t\t\tN/A";
else
        echo -e "$(type -P npm) \t\t$(npm -v)";
        VERNPM=$(npm -v);
fi;

if [[ -z "$PATHNPX" ]];
then
        echo -e "npx: \t\t\tN/A";

else
        echo -e "$(type -P npx) \t\t$(npx -v)";
        VERNPX=$(npx -v);
fi;

if [[ -z "$PATHCOREPACK" ]];
then
        echo -e "corepack: \tN/A";

else
        echo -e "$(type -P corepack) \t$(corepack -v)";
fi;
if [[ "$SKRPTLANG" = "--de" ]]; then
echo -e "\nEmpfohlene Versionen sind zurzeit nodejs ""$NODERECOM"" und npm ""$NPMRECOM""";
else
echo -e "\nRecommended versions are nodejs ""$NODERECOM"" and npm ""$NPMRECOM""";
fi;
if
        [[ $PATHNODEJS != "/usr/bin/nodejs" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
                fi;
        elif
        [[ $PATHNODE != "/usr/bin/node" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
                fi;
        elif
        [[ $PATHNPM != "/usr/bin/npm" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
                fi;
        elif
        [[ $PATHNPX != "/usr/bin/npx" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
                fi;
         elif
        [[ $PATHCOREPACK != "/usr/bin/corepack" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "Wrong installation path detected. This needs to be fixed.";
                fi;
        elif
        [[ $VERNODEJS != "$VERNODE" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Die Versionen von nodejs und node stimmen nicht überein. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "nodejs and node versions do not match. This needs to be fixed.";
                fi;

        elif
        [[ $VERNPM != "$VERNPX" ]];
        then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m";
                echo "Die Versionen von npm und npx stimmen nicht überein. Dies muss korrigiert werden.";
                else
                echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m";
                echo "npm and npx versions do not match. This needs to be fixed.";
                fi;
        else
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo "nodeJS ist korrekt installiert"
                else
                echo "nodeJS installation is correct";
                fi;
fi
if [[ $NODENOTCORR -eq 1 ]];
then
                if [[ "$SKRPTLANG" = "--de" ]]; then
                echo "";
                echo "Bitte den Befehl";
                echo -e "\e[031miob nodejs-update\e[0m";
                echo "zur Korrektur der Installation ausführen."
                else
                echo "";
                echo "Please execute";
                echo -e "\e[031miob nodejs-update\e[0m";
                echo "to fix these errors."
                fi;
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
        if [[ "$SKRPTLANG" = "--de" ]]; then
        echo "**********************************************************************";
        echo -e "Probleme wurden erkannt, bitte \e[031miob fix\e[0m ausführen";
        echo "**********************************************************************";
        echo "";
        else
        echo "**********************************************************************";
        echo -e "Some problems detected, please run \e[031miob fix\e[0m and try to have them fixed";
        echo "**********************************************************************";
        echo "";
        fi;
fi;
if [[ "$CRITERROR" -gt 0 ]]; then
        if [[ "$SKRPTLANG" = "--de" ]]; then
                echo -e "Es wurden "$CRITERROR" KRITISCHE FEHLER gefunden. \nSiehe 'sudo dmesg --level=emerg,alert,crit -T' für Details"
        else
                echo -e ""$CRITERROR" CRITICAL ERRORS DETECTED! \nCheck 'sudo dmesg --level=emerg,alert,crit -T' for details";
        fi;
fi;
echo -e "$RELEASESTATUS";
echo "";
if [[ "$SKRPTLANG" = "--de" ]]; then
echo "=================== ENDE DER ZUSAMMENFASSUNG ====================";
echo -e "\`\`\`";
echo "";
echo "=== Ausgabe bis hier markieren und kopieren ===";
else
echo "=================== END OF SUMMARY ====================";
echo -e "\`\`\`";
echo "";
echo "=== Mark text until here for copying ===";
fi;
exit;
