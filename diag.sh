#!/bin/bash
# iobroker diagnostics
SKRIPTV="2026-03-12" #version of this script

# written to help getting information about the environment the ioBroker installation is running in

## --help
# Funktion zur Anzeige der Hilfe
show_help() {
    cat <<EOF
ioBroker Diagnose-Skript - Hilfe

Verwendung: $0 [OPTIONEN]

Optionen:
  --help            Zeigt diese Hilfe an.
  --de              Ausgabe auf Deutsch (teilweise).
  --unmask          Zeigt maskierte Ausgaben im Klartext an.
  --summary / -s    Zeigt eine kurze Zusammenfassung der wichtigsten Informationen.
  --short / -s      Alias für --summary.
  --kurz / -k       Alias für --summary.
  --zusammenfassung Alias für --summary (deutsch).
  --allow-root      Erlaubt die Ausführung als Root (nicht empfohlen).

Beispiele:
  $0 --de              # Deutsche Ausgabe
  $0 --unmask          # Unmaskierte Ausgabe
  $0 --summary         # Kurze Zusammenfassung
  $0 --help            # Diese Hilfe anzeigen

Hinweis: Für eine vollständige Diagnose sollten keine Optionen außer --de oder --unmask verwendet werden.
EOF
}

# Prüfe, ob --help übergeben wurde
if [[ "$*" == *"--help"* ]]; then
    show_help
    exit 0
fi

DOCKER=/opt/scripts/.docker_config/.thisisdocker
#if [[ -f "/opt/scripts/.docker_config/.thisisdocker" ]]
if [[ $(id -u) -eq 0 ]] && [[ ! -f "$DOCKER" ]]; then
    printf "You should not be root on your system!\nBetter use your standard user!\n\n"
    sleep 15
fi
clear
if [[ "$*" =~ --de ]]; then SKRPTLANG="--de"; fi
if [[ "$SKRPTLANG" == "--de" ]]; then
    echo "*** iob diag startet, bitte etwas warten ***"
else
    echo "*** iob diag is starting up, please wait ***"
fi

if ! command -v distro-info >/dev/null; then
    if [[ "$SKRPTLANG" == "--de" ]]; then
        if command -v apt-get >/dev/null; then
            echo "iob diag muss aktualisiert werden. Bitte dazu zunächst 'iobroker fix' ausführen."
        else
            echo "iob diag muss aktualisiert werden. Bitte das Paket 'distro-info' nachinstallieren."
        fi
    else
        if command -v apt-get >/dev/null; then
            echo "iob diag needs to be updated. Please execute 'iobroker fix' first."
        else
            echo "iob diag needs to be updated. Please manually install package 'distro-info'"
        fi
    fi
fi

# Farbdefinitionen
GREEN=$(printf '\033[0;32m')
RED=$(printf '\033[0;31m')
YELLOW=$(printf '\033[1;33m')
NC=$(printf '\033[0m')  # No Color
HEADLINE='\033[34;107m'

# VARIABLES
export LC_ALL=C
#NODE_MAJOR=22           this is the recommended major nodejs version for ioBroker, please adjust accordingly if the recommendation changes
ALLOWROOT=""
if [ "$*" = "--allow-root" ]; then ALLOWROOT=$"--allow-root"; fi
MASKED=""
if [[ "$*" = *--unmask* ]]; then MASKED="unmasked"; fi
SUMMARY=""
if [[ "$*" = *--summary* ]] || [[ "$*" = *--short* ]] || [[ "$*" = *--zusammenfassung* ]] || [[ "$*" = *--kurz* ]] || [[ "$*" = *-s* ]] || [[ "$*" = *-k* ]]; then SUMMARY="summary"; fi
ARCH=$(getconf LONG_BIT);
HOST=$(uname -n)
ID_LIKE=$(awk -F= '$1=="ID_LIKE" { print $2 ;}' /usr/lib/os-release | xargs)
NODERECOM=$(iobroker state getValue system.host."$HOST".versions.nodeNewestNext $ALLOWROOT) #recommended node version
NPMRECOM=$(iobroker state getValue system.host."$HOST".versions.npmNewestNext $ALLOWROOT)   #recommended npm version
#NODEUSED=$(iobroker state getValue system.host."$HOST".versions.nodeCurrent);      #current node version in use
#NPMUSED=$(iobroker state getValue system.host."$HOST".versions.npmCurrent);        #current npm version in use
APT=0
INSTENV=0
INSTENV2=0
SYSTDDVIRT=""
NODENOTCORR=0
IOBLISTINST=$(iobroker list instances $ALLOWROOT)
NPMLS=$(cd /opt/iobroker && npm ls -a)

#Debian and Ubuntu releases and their status
EOLDEB=$(debian-distro-info --unsupported)
EOLUBU=$(ubuntu-distro-info --unsupported)
DEBSTABLE=$(debian-distro-info --stable)
UBULTS=$(ubuntu-distro-info --lts)
UBUSUP=$(ubuntu-distro-info --supported)
TESTING=$(debian-distro-info --testing && ubuntu-distro-info --devel 2>/dev/null)
OLDSTABLE=$(debian-distro-info --oldstable)
CODENAME=$(source /usr/lib/os-release && echo "$VERSION_CODENAME")
UNKNOWNRELEASE=1

clear
if [[ "$SKRPTLANG" == "--de" ]]; then
    echo ""
    printf "\033[34;107m*** ioBroker Diagnose ***\033[0m"
    echo ""
    echo "Das Fenster des Terminalprogramms (puTTY) bitte so groß wie möglich ziehen oder den Vollbildmodus verwenden."
    echo ""
    echo "Die nachfolgenden Prüfungen liefern Hinweise zu etwaigen Fehlern, bitte im Forum hochladen:"
    echo ""
    echo "https://forum.iobroker.net"
    echo ""
    echo "Bitte die vollständige Ausgabe, einschließlich der \`\`\` Zeichen am Anfang und am Ende markieren und kopieren."
    echo "Es hilft beim helfen!"
    if [[ "$MASKED" != "unmasked" ]]; then
        echo ""
        echo "******************************************************************************************************"
        echo "* Einige Testergebnisse sind maskiert. Um alle Ausgaben zu sehen bitte 'iob diag --unmask' aufrufen. *"
        echo "******************************************************************************************************"
        echo ""
    fi
    # read -p "Press <Enter> to continue";
    printf "\nBitte eine Taste drücken"
    read -r -n 1 -s
    clear
    echo ""
else
    echo ""
    printf "\033[34;107m*** ioBroker Diagnosis ***\033[0m"
    echo ""
    echo "Please stretch the window of your terminal programm (puTTY) as wide as possible or switch to full screen"
    echo ""
    echo "The following checks may give hints to potential malconfigurations or errors, please post them in our forum:"
    echo ""
    echo "https://forum.iobroker.net"
    echo ""
    echo "Just copy and paste the Summary Page, including the \`\`\` characters at start and end."
    echo "It helps us to help you!"
    if [[ "$MASKED" != "unmasked" ]]; then
        echo ""
        echo "**************************************************************************"
        echo "* Some output is masked. For full results please use 'iob diag --unmask' *"
        echo "**************************************************************************"
    fi
    printf "\nPress any key to continue"
    read -r -n 1 -s
    clear
    echo ""
fi

if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "%b%s%b" "$YELLOW" "========== Langfassung ab hier markieren und kopieren ===========" "$NC"
    printf "\n\n%s" '```bash'
    printf "\n%s%s" "Script v." "$SKRIPTV"
    printf "\n\n%b%s%b" "$HEADLINE" "*** GRUNDSYSTEM ***" "$NC"
else
    printf "%b%s%b" "$YELLOW" "========== Start marking the full check here ===========" "$NC"
    printf "\n\n%s" '```bash'
    printf "\n%s%s" "Script v." "$SKRIPTV"
    printf "\n\n%b%s%b" "$HEADLINE" "*** BASE SYSTEM ***" "$NC"
fi

if [ -f "$DOCKER" ]; then
    printf "\n%s" "Hardware Vendor : " "$(cat /sys/devices/virtual/dmi/id/sys_vendor)"
    printf "\n%s" "Kernel          : " "$(uname -m)"
    printf "\n%s%d%s\n" "Userland        : " "$(getconf LONG_BIT)" "bit"
    printf "\n%s\n" "Docker          : " "$(cat /opt/scripts/.docker_config/.thisisdocker)"
else
    source /usr/lib/os-release
    printf "\n%s%s\n" "Operating System: " "$PRETTY_NAME"
    hostnamectl | grep -v 'Machine\|Boot\|Operating'
    printf "%s%s\n\n" "OS is similar to: " "$ID_LIKE"
    grep -i model /proc/cpuinfo | tail -1
    printf "\n%s\n" "Docker          : false"
fi

SYSTDDVIRT=$(systemd-detect-virt 2>/dev/null)
if [[ -n "$SYSTDDVIRT" ]]; then
    printf "%s%s" "Virtualization  : " "$(systemd-detect-virt)"
else
    printf "%s" "Virtualization  : Docker"
fi
printf "\n%s%s" "Kernel          : " "$(uname -m)"
printf "\n%s%s%s" "Userland        : " "$(getconf LONG_BIT)" "bit"

check_architecture() {
    if (( ARCH == 32 )); then
        printf "\n\e[1;33mOutdated 32Bit architecture detected. Only a pure 64Bit-System will be supported in the future. You will have to reinstall your operating system with full 64Bit support or upgrade to more modern hardware soon.\e[0m"
    fi
}

check_architecture

printf "\n\n%s\n" "Systemuptime and Load:"
uptime
printf "%s%s\n" "CPU threads     : " "$(grep -c processor /proc/cpuinfo)"

if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%b%s%b\n" "$HEADLINE" "*** LEBENSZYKLUS STATUS ***" "$NC"

    for RELEASE in "${EOLDEB[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[31mDas Debian Release '$CODENAME' hat sein Lebensende erreicht und muss JETZT auf die aktuelle stabile Veröffentlichung '$DEBSTABLE' gebracht werden!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${EOLUBU[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[31mDas Ubuntu Release '$CODENAME' hat sein Lebensende erreicht und muss JETZT auf die aktuelle Version '$UBULTS' mit Langzeitunterstützung gebracht werden.\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${DEBSTABLE[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[32mDas Betriebssystem ist das aktuelle, stabile Debian '$DEBSTABLE'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${UBULTS[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[32mDas Betriebssystem ist die aktuelle Ubuntu LTS Version '$UBULTS'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${UBUSUP[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]] && [[ "$RELEASE" != "$UBULTS" ]]; then
            RELEASESTATUS="\e[1;33mDie Unterstützung für das Betriebssystem mit dem Codenamen '$CODENAME' läuft aus. Es sollte in nächster Zeit auf die aktuelle Version '$UBULTS' mit Langzeitunterstützung gebracht werden.\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${TESTING[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[1;33mDas Betriebssystem mit dem Codenamen '$CODENAME' ist eine Testversion! Es sollte nur zu Testzwecken eingesetzt werden!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${OLDSTABLE[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[1;33mDebian '$OLDSTABLE' ist eine veraltete Version. Es sollte in nächster Zeit auf die aktuelle stabile Version '$DEBSTABLE' gebracht werden!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    if (( UNKNOWNRELEASE == 1 )); then
        RELEASESTATUS="Das Betriebssystem mit dem Codenamen '$CODENAME' ist unbekannt. Bitte den Status der Unterstützung eigenständig prüfen."
    fi

    echo -e "$RELEASESTATUS"
    #printf "%s\n\n" "$RELEASESTATUS"

else
    printf "\n%b%s%b\n" "$HEADLINE" "*** LIFE CYCLE STATUS ***" "$NC"

    for RELEASE in "${EOLDEB[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[31mDebian Release codenamed '$CODENAME' reached its END OF LIFE and needs to be updated to the latest stable release '$DEBSTABLE' NOW!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${EOLUBU[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[31mUbuntu Release codenamed '$CODENAME' reached its END OF LIFE and needs to be updated to the latest LTS release '$UBULTS' NOW!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${DEBSTABLE[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[32mOperating System is the current Debian stable version codenamed '$DEBSTABLE'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${UBULTS[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[32mOperating System is the current Ubuntu LTS release codenamed '$UBULTS'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${UBUSUP[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]] && [[ "$RELEASE" != "$UBULTS" ]]; then
            RELEASESTATUS="\e[1;33mOperating System codenamed '$CODENAME' is an aging Ubuntu release! Please upgrade to the latest LTS release '$UBULTS' in due time!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${TESTING[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[1;33mOperating System codenamed '$CODENAME' is a testing release! Please use it only for testing purposes!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in "${OLDSTABLE[@]}"; do
        if [[ "$RELEASE" == "$CODENAME" ]]; then
            RELEASESTATUS="\e[1;33mDebian '$OLDSTABLE' is the current oldstable version. Please upgrade to the latest stable release '$DEBSTABLE' in due time!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    if  (( UNKNOWNRELEASE == 1 )) ; then
        RELEASESTATUS="Unknown release codenamed '$CODENAME'. Please check yourself if the Operating System is actively maintained."
    fi
    echo -e "$RELEASESTATUS"
fi

# RASPBERRY only
if [[ $(type -P "vcgencmd" 2>/dev/null) = *"/vcgencmd" ]]; then
    #        echo "Raspberry only:";
    #        vcgencmd get_throttled 2> /dev/null;
    #        echo "Other values than 0x0 hint to temperature/voltage problems";
    #        vcgencmd measure_temp;
    #        vcgencmd measure_volts;

    echo ""
    printf "\033[34;107m*** RASPBERRY THROTTLING ***\033[0m\n"
    # CODE from https://github.com/alwye/get_throttled under MIT Licence
    ISSUES_MAP=(
        [0]="Under-voltage detected"
        [1]="Arm frequency capped"
        [2]="Currently throttled"
        [3]="Soft temperature limit active"
        [16]="Under-voltage has occurred"
        [17]="Arm frequency capping has occurred"
        [18]="Throttling has occurred"
        [19]="Soft temperature limit has occurred")

    HEX_BIN_MAP=(
        ["0"]="0000"
        ["1"]="0001"
        ["2"]="0010"
        ["3"]="0011"
        ["4"]="0100"
        ["5"]="0101"
        ["6"]="0110"
        ["7"]="0111"
        ["8"]="1000"
        ["9"]="1001"
        ["A"]="1010"
        ["B"]="1011"
        ["C"]="1100"
        ["D"]="1101"
        ["E"]="1110"
        ["F"]="1111"
    )

    THROTTLED_OUTPUT=$(vcgencmd get_throttled)
    IFS='x'
    read -r -a strarr <<<"$THROTTLED_OUTPUT"
    THROTTLED_CODE_HEX=${strarr[1]}

    # Display current issues
    echo "Current issues:"
    CURRENT_HEX=${THROTTLED_CODE_HEX:4:1}
    CURRENT_BIN=${HEX_BIN_MAP[$CURRENT_HEX]}
    if (( CURRENT_HEX == 0 )) || [[ -z "$CURRENT_HEX" ]]; then
        printf "\e[32mNo throttling issues detected.\e[0m\n"
    else
        bit_n=0
        for ((i = ${#CURRENT_BIN} - 1; i >= 0; i--)); do
            if [ "${CURRENT_BIN:$i:1}" = "1" ]; then
                echo "~ ${ISSUES_MAP[$bit_n]}"
                bit_n=$((bit_n + 1))
            fi
        done
    fi

    echo ""

    # Display past issues
    printf "Previously detected issues:\n"
    PAST_HEX=${THROTTLED_CODE_HEX:0:1}
    PAST_BIN=${HEX_BIN_MAP[$PAST_HEX]}
    if [ "$PAST_HEX" = "0" ]; then
        printf "\e[32mNo throttling issues detected.\e[0m\n"
    else
        bit_n=16
        for ((i = ${#PAST_BIN} - 1; i >= 0; i--)); do
            if [ "${PAST_BIN:$i:1}" = "1" ]; then
                echo "~ ${ISSUES_MAP[$bit_n]}"
                bit_n=$((bit_n + 1))
            fi
        done
    fi
fi

if [[ "$SKRPTLANG" == "--de" ]]; then
    if [[ -f "/var/run/reboot-required" ]]; then
        printf "\n%b%s%b" "$RED" "Dieses System benötigt einen NEUSTART" "$NC"
    fi
else
    if [[ -f "/var/run/reboot-required" ]]; then
        printf "\n%b%s%b" "$RED" "This system needs to be REBOOTED!" "$NC"
    fi
fi

if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%b%s%b\n" "$HEADLINE" "*** ZEIT UND ZEITZONEN ***" "$NC"

    if [[ -f "$DOCKER" ]]; then
        date -u
        date
        date +"%Z %z"
        cat /etc/timezone
    else
        timedatectl
    fi

    if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
        printf "\n%s\n" "Die gesetzte Zeitzone ist vermutlich falsch. Bitte die Zeitzone mit den Mitteln des Betriebssystems ändern oder per 'iobroker fix' setzen."
    fi
else

    printf "\n%b%s%b\n" "$HEADLINE" "*** TIME AND TIMEZONES ***" "$NC"

    if [[ -f "$DOCKER" ]]; then
        date -u
        date
        date +"%Z %z"
        cat /etc/timezone
    else
        timedatectl
    fi

    if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
        if [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
            printf "\n%s\n" "Timezone is probably wrong. Please configure it with system admin tools or by running 'iobroker fix'"
        fi
    fi
fi

echo ""
if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%b%s%b" "$HEADLINE" "*** User und Gruppen ***" "$NC"
    printf "\n%s\n" "User der 'iob diag' aufgerufen hat:"
    whoami
    env | grep HOME
    #echo "GROUPS=\"$(groups)\""
    printf "GROUPS=%s\n\n" "$(groups)"
    echo "User der den 'js-controller' ausführt:"
    if pgrep -f iobroker.js-controller >/dev/null; then
        IOUSER=$(ps -o user= -p "$(pgrep -f iobroker.js-controller | head -1)")
        printf "\n%s\n" "$IOUSER"
        printf "%s%s\n" "HOME="  "$(sudo -H -u "$IOUSER" bash -c 'echo $HOME')"
        printf "%s%s" "GROUPS=" "$(sudo -u "$IOUSER" groups)"
    else
    printf "\n%b%s%b" "$RED" "js-controller läuft nicht" "$NC"
    fi

    if [[ ! -f "$DOCKER" ]] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then
        # Prompt for username
        printf "\n%s\n" "Es sollte ein Standarduser angelegt werden! Dieser user kann auch mittels 'sudo' temporär root-Rechte erlangen."
        printf "%s\n" "Ein permanentes Login als root ist nicht vorgesehen."
        printf "%s" "Bitte den 'iobroker fix' ausführen oder manuell einen entsprechenden User anlegen."
    fi
else
    printf "%b%s%b" "$HEADLINE" "*** Users and Groups ***" "$NC"
    printf "\n%s\n" "User that called 'iob diag':"
    printf "%s\n" "$(whoami)"
    printf "%s%s\n" "HOME=" "$(bash -c 'echo $HOME')"
    printf "%s%s" "GROUPS=" "$(groups)"
    printf "\n\n%s" "User that is running 'js-controller':"
    if pgrep -f iobroker.js-controller >/dev/null; then
        IOUSER=$(ps -o user= -p "$(pgrep -f iobroker.js-controller | head -1)")
        printf "\n%s\n" "$IOUSER"
        printf "%s%s\n" "HOME="  "$(sudo -H -u "$IOUSER" bash -c 'echo $HOME')"
        printf "%s%s" "GROUPS=" "$(sudo -u "$IOUSER" groups)"
    else
        printf "\n%b%s%b" "$RED" "js-controller is not running" "$NC"
    fi

    if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then

        # Prompt for username
        printf "\n%s" "A default user should be created! This user will be enabled to temporarily switch to root via 'sudo'!"
        printf "\n%s" "A root login is not required in most Linux Distributions."
        printf "\n%s" "Run 'iobroker fix' or use the system tools to create a user."
    fi
fi
printf "\n\n%b%s%b" "$HEADLINE" "*** DISPLAY-SERVER SETUP ***" "$NC"

if [ -n "$WAYLAND_DISPLAY" ]; then
    printf "\n%s\t\t%s" "Display-Server:" "Wayland"
elif [ -n "$DISPLAY" ]; then
    printf "\n%s\t\t%s" "Display-Server:" "X11"
else
    printf "\n%s\t\t%s" "Display-Server:" "Unknown"
fi
printf "\n%s\t%s" "Display-Manager: " "$(systemctl status display-manager --no-pager 2>&1 | head -n 1 | sed 's/Unit.*could not be found\./Not found/')"
printf "\n%s\t\t%s" "Desktop:" "$DESKTOP_SESSION"
printf "\n%s\t\t%s" "Session:" "$XDG_SESSION_TYPE"

if [ -z "$DOCKER" ]; then
    printf "Boot Target: \t%s" "$(systemctl get-default)"
fi

if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
    if [[ $(systemctl get-default) == "graphical.target" ]]; then
        if [[ "$SKRPTLANG" == "--de" ]]; then
            printf "\n\n%b%s"  "Das System bootet in eine graphische Oberfläche. Im Serverbetrieb wird kein GUI verwendet." "$YELLOW"
            printf "\n%s%b" "Bitte das BootTarget auf 'multi-user.target' setzen oder 'iobroker fix' ausführen." "$NC"
        else
            printf "\n\n%b%s" "$YELLOW" "System is booting into 'graphical.target'. Usually a server is running in 'multi-user.target'."
            printf "\n%s%b" "Please set BootTarget to 'multi-user.target' or run 'iobroker fix'" "$NC"
        fi
    fi
fi

printf "\n\n%b%s%b\n" "$HEADLINE" "*** MEMORY ***" "$NC"
free -th --mega
printf "\n%s\t%d\n\n" "Active iob-Instances: "  "$(grep -c '^+' <<< "$IOBLISTINST")"
vmstat -S M -s | head -n 10

printf "\n%b%s%b\n" "$HEADLINE" "*** top - Table Of Processes  ***" "\033[0m"
top -b -n 1 | head -n 5

if [ ! -f "$DOCKER" ]; then
    printf "\n%b%s%b\n" "$HEADLINE" "*** FAILED SERVICES ***" "$NC"
    systemctl list-units --failed --no-pager
fi

printf "\n%b%s%b\n" "$HEADLINE" "*** DMESG CRITICAL ERRORS ***" "$NC"
CRITERROR=$(sudo dmesg --level=emerg,alert,crit -T | wc -l)
if (( CRITERROR > 0 )); then
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "%b%s%s%s\n%b%s" "$RED" "Es wurden" "$CRITERROR" "KRITISCHE FEHLER gefunden." "$NC" "Siehe 'sudo dmesg --level=emerg,alert,crit -T' für Details"
    else
        printf "%b%s%s%b\n%s" "$RED" "$CRITERROR" "CRITICAL ERRORS DETECTED!" "$NC" "Check 'sudo dmesg --level=emerg,alert,crit -T' for details"
    fi
else
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "%b%s%b" "$GREEN" "Es wurden keine kritischen Fehler gefunden" "$NC"
    else
        printf "%b%s%b" "$GREEN" "No critical errors detected" "$NC"
    fi
fi

printf "\n\n%b%s%b\n" "$HEADLINE" "*** FILESYSTEM ***" "$NC"
df -PTh
printf "\n%b%s%b\n" "$GREEN" "Messages concerning filesystems in dmesg:" "$NC"
sudo dmesg -T | grep -Ei 'ext4|btrfs|ext2|ext3|vfat|xfs|f2fs|gfs2' | grep -Ev 'Modules linked in:|Kernel command line:|info'
printf "\n%b%s%b\n" "$GREEN" "Show mounted filesystems:" "$NC"
findmnt --real

if [[ -L "/opt/iobroker/backups" ]]; then
    printf "\nbackups directory is linked to a different directory\n"
fi
printf "\n%b%s%b" "$GREEN" "Files in neuralgic directories:" "$NC"
printf "\n%b%s%b\n" "$GREEN" "/var:" "$NC"
sudo du -h /var/ | sort -rh | head -5

if [[ ! -f "$DOCKER" ]]; then
    journalctl --disk-usage
fi
printf "\n%b%s%b\n" "$GREEN" "/opt/iobroker/backups:" "$NC"
du -h /opt/iobroker/backups/ | sort -rh | head -5
printf "\n%b%s%b\n" "$GREEN" "/opt/iobroker/iobroker-data:" "$NC"
du -h /opt/iobroker/iobroker-data/ | sort -rh | head -5
printf "\n%b%s%b\n" "$GREEN" "The five largest files in iobroker-data are:" "$NC"
find /opt/iobroker/iobroker-data -maxdepth 15 -type f -exec du -sh {} + | sort -rh | head -n 5

# ============================================================================
# ZigBee Port Checking - Optimierte Version
# ============================================================================

# Funktion für ZigBee Port Check
check_zigbee_port() {
    local instance=$1
    local configured_port


    configured_port=$(awk -F: -v instance="$instance" '$0 ~ "system.adapter.zigbee." instance {print substr($4, 2)}' <<< "$IOBLISTINST")

    # Wenn kein Port konfiguriert, überspringe diese Instanz
    [[ -z "$configured_port" ]] && return 0

    # Prüfe ob der konfigurierte Port in den by-id Geräten vorkommt
    if [[ "$SYSZIGBEEPORT" == "$configured_port" ]]; then
        echo ""
        if [[ "$SKRPTLANG" == "--de" ]]; then
            printf "\n%b%s%s%s%b" "$GREEN" "✓ zigbee." "$instance" " COM-Port stimmt mit 'by-id' überein. Sehr gut!" "$NC"
        else
            printf "\n%b%s%s%s%b" "$GREEN" "✓ Your zigbee." "$instance" " COM-Port is matching 'by-id'. Very good!" "$NC"
        fi
    else
        echo ""
        if [[ "$SKRPTLANG" == "--de" ]]; then
            printf "\n%b%s" "$YELLOW" "⚠ HINWEIS:"
            printf "\n%s%d%s%b" "Dein zigbee." "$instance" " COM-Port stimmt NICHT mit 'by-id' überein." "$NC"
            printf "\n%s" "Bitte überprüfe die Einstellung:"
            printf "\n%s" "$configured_port"
        else
            printf "\n%b%s" "$YELLOW" "⚠ HINT:"
            printf "\n%s%d%s%b" "Your zigbee." "$instance" " COM-Port is NOT matching 'by-id'." "$NC"
            printf "\n%s" "Please check your setting:"
            printf "\n%s" "$configured_port"
        fi
    fi
}

# USB-Geräte by-id
printf "\n%b%s%b\n" "$GREEN" "USB-Devices by-id:" "$NC"
if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "USB-Sticks - Vermeide direkte Links zu /dev/tty* in deinen Adapter-Einstellungen,\n"
    printf "bevorzuge immer die Links 'by-id':\n\n"
else
    printf "USB-Sticks - Avoid direct links to /dev/tty* in your adapter setups,\n"
    printf "please always prefer the links 'by-id':\n\n"
fi


# Finde alle USB-Geräte by-id
SYSZIGBEEPORT=$(find /dev/serial/by-id/ -maxdepth 1 -mindepth 1 2>/dev/null)

if [[ -n "$SYSZIGBEEPORT" ]]; then
    echo "$SYSZIGBEEPORT"
else
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "Keine Geräte gefunden 'by-id'"
    else
        printf "No Devices found 'by-id'"
    fi
fi

# Prüfe ob überhaupt ZigBee-Daten existieren
for d in /opt/iobroker/iobroker-data/zigbee_*; do
    if [[ -d "$d" ]]; then
        printf "\n%b%s%b" "$HEADLINE" "*** ZigBee Settings ***" "$NC"
        break
    fi
done

# Prüfe alle ZigBee-Instanzen automatisch (0-9)
# Die Funktion überspringt automatisch nicht-existente Instanzen
for i in {0..9}; do
    check_zigbee_port "$i"
done

# ============================================================================
# Ende des optimierten ZigBee-Blocks
# ============================================================================

# masked output

if ls /opt/iobroker/iobroker-data/zigbee_*/nvbackup.json 1>/dev/null 2>&1; then
    for d in /opt/iobroker/iobroker-data/zigbee_*/nvbackup.json; do
        if [[ "$MASKED" != "unmasked" ]]; then
            printf "\n\n%s\n" "Zigbee Network Settings on your coordinator / in nvbackup are:"
            printf "\n%s" "zigbee.X"
            printf "\n%s" "\nExtended Pan ID:"
            printf "\n%s" "\n*** MASKED ***"
            printf "\n%s" "\nPan ID:"
            printf "\n%s" "\n*** MASKED ***"
            printf "\n%s" "\nChannel:"
            printf "\n%s" "\n*** MASKED ***"
            printf "\n%s" "\nNetwork Key:"
            printf "\n%s" "\n*** MASKED ***"
            printf "\n\n%s\n" "To unmask the settings run 'iob diag --unmask'"
            break
        fi
    done

    for d in /opt/iobroker/iobroker-data/zigbee_*/nvbackup.json; do
        if [[ "$MASKED" = "unmasked" ]]; then

            printf "\n%s\n" "Zigbee Network Settings on your coordinator / in nvbackup are:"
            printf "\n%s%s" "zigbee." "$(printf '%s\n' "$d" | cut -c36)"
            printf "\n%s\n" "Extended Pan ID:"
            grep extended_pan_id "$d" | cut -c 23-38
            printf "%s\n" "Pan ID:"
            printf "%d" 0x"$(grep \"pan_id\" "$d" | cut -c 14-17)"
            printf "\n%s\n" "Channel:"
            grep \"channel\" "$d" | cut -c 14-15
            printf "%s\n" "Network Key:"
            grep \"key\" "$d" | cut -c 13-44
        fi
    done
else
    printf "\n%s\n" "No nvbackup.json found."
fi

########### TESTCODE ######################

# Function to shorten port paths (show last 25 characters)
shorten_port() {
    local port="$1"
    if [[ "$port" == tcp://* ]]; then
        printf "%s" "$port"  # TCP connections are not shortened
    elif [[ ${#port} -gt 25 ]]; then
        printf "%s" "...${port: -25}"
    else
        printf "%s" "$port"
    fi
}

# Get actual by-id ports from the system using mapfile
SYSZIGBEEPORTS=()
while IFS= read -r -d '' port; do
    SYSZIGBEEPORTS+=("$port")
done < <(find /dev/serial/by-id/ -maxdepth 1 -mindepth 1 -print0 2>/dev/null)

# Get actual ioBroker instances
IOBLISTINST=$(iobroker list instances 2>/dev/null)

# Extract ZigBee instances with numbers (e.g., zigbee.0, zigbee.1)
instances=()
while IFS= read -r line; do
    if [[ $line =~ system\.adapter\.zigbee\.[0-9]+ ]]; then
        instances+=("$line")
    fi
done < <(echo "$IOBLISTINST" | grep -E 'system\.adapter\.zigbee\.[0-9]+')

# Function to extract configured port for a ZigBee instance
get_zigbee_port() {
    local instance="$1"
    echo "$IOBLISTINST" | grep -A1 "$instance" | grep -m1 -oP 'port: \K[^\s]+'
}

# Function to print ZigBee port status in a table format
print_zigbee_port_table() {
    local lang="$1"
    shift
    local sys_zigbee_ports=("$@")

    # Table header (language-dependent)
    if [[ "$lang" == "--de" ]]; then
        printf "\n%b%s%b\n" "$GREEN" "=== ZigBee-Port-Übersicht ===" "$NC"
        printf "%-15s %-35s %-35s %-20s\n" "Instanz" "Konfigurierter Port" "Verfügbarer by-id-Port" "Status"
        printf "%-15s %-35s %-35s %-20s\n" "-------" "----------------------------" "----------------------------" "------"
    else
        printf "\n%b%s%b\n" "$GREEN" "=== ZigBee Port Overview ===" "$NC"
        printf "%-15s %-35s %-35s %-20s\n" "Instance" "Configured Port" "Available by-id Port" "Status"
        printf "%-15s %-35s %-35s %-20s\n" "--------" "----------------------------" "----------------------------" "------"
    fi

    for instance_line in "${instances[@]}"; do
        # Extract instance number (e.g., "0" from "system.adapter.zigbee.0")
        local instance_number
        instance_number=$(echo "$instance_line" | grep -oP 'zigbee\.\K[0-9]+')

        local configured_port
        configured_port=$(get_zigbee_port "$instance_line")

        # Skip if no port is configured
        if [[ -z "$configured_port" ]]; then
            continue
        fi

        # Shorten the configured port path
        local short_configured_port
        short_configured_port=$(shorten_port "$configured_port")

        # Check if the configured port is a TCP connection
        if [[ "$configured_port" == tcp://* ]]; then
            printf "%-15s %-35s %-35s %-20s\n" \
                "zigbee.$instance_number" \
                "$short_configured_port" \
                "-" \
                "${YELLOW}tcp${NC}"
        else
            # For serial ports, check each by-id port
            for i in "${!sys_zigbee_ports[@]}"; do
                local short_port
                short_port=$(shorten_port "${sys_zigbee_ports[$i]}")

                local status
                if [[ "$configured_port" == "${sys_zigbee_ports[$i]}" ]]; then
                    if [[ "$lang" == "--de" ]]; then
                        status="${GREEN}✓ Übereinstimmend${NC}"
                    else
                        status="${GREEN}✓ Matching${NC}"
                    fi
                else
                    if [[ "$lang" == "--de" ]]; then
                        status="${RED}✗ Nicht übereinstimmend${NC}"
                    else
                        status="${RED}✗ Not matching${NC}"
                    fi
                fi

                # Print table row for each by-id port
                if [[ $i -eq 0 ]]; then
                    printf "%-15s %-35s %-35s %-20s\n" \
                        "zigbee.$instance_number" \
                        "$short_configured_port" \
                        "$short_port" \
                        "$status"
                else
                    printf "%-15s %-35s %-35s %-20s\n" \
                        "" \
                        "" \
                        "$short_port" \
                        "$status"
                fi
            done
        fi
    done
}

# Print the table only if there are ZigBee instances
if [[ ${#instances[@]} -gt 0 ]]; then
    print_zigbee_port_table "$SKRPTLANG" "${SYSZIGBEEPORTS[@]}"
fi

############ TESTCODE ENDE ####################


#### NODEJS-CHECK

PATHNODEJS=$(type -P nodejs)
PATHNODE=$(type -P node)
PATHNPM=$(type -P npm)
PATHNPX=$(type -P npx)
VERNODEJS=$(nodejs -v 2>/dev/null)
VERNODE=$(node -v 2>/dev/null)
VERNPM=$(npm -v 2>/dev/null)
VERNPX=$(npx -v 2>/dev/null)

check_nodejs_installation() {
    local show_messages="${1:-true}" # Standard: Zeige Meldungen

    # Sammle alle Probleme
    local problems=()

    [[ "$PATHNODEJS" != "/usr/bin/nodejs" ]] && problems+=(" nodejs path ")
    [[ "$PATHNODE" != "/usr/bin/node" ]] && problems+=(" node path ")
    [[ "$PATHNPM" != "/usr/bin/npm" ]] && problems+=(" npm path ")
    [[ "$PATHNPX" != "/usr/bin/npx" ]] && problems+=(" npx path ")
    [[ "$VERNODEJS" != "$VERNODE" ]] && problems+=(" nodejs/node version mismatch ")
    [[ "$VERNPM" != "$VERNPX" ]] && problems+=(" npm/npx version mismatch ")

    # Wenn Probleme gefunden wurden
    if [[ ${#problems[@]} -gt 0 ]]; then
        if [[ "$show_messages" == "true" ]]; then
            NODENOTCORR=1
            if [[ "$SKRPTLANG" == "--de" ]]; then
                printf "\n%b%s%b" "$RED" "*** Node.js ist NICHT korrekt installiert ***" "$NC"
                printf "\n%s%s" "Probleme:" "${problems[*]}"
                printf "\n%s\n" "Führe 'iobroker nodejs-update' im Terminal aus."
            else
                printf "\n%b%s%b" "$RED" "*** Node.js is NOT correctly installed ***" "$NC"
                printf "\n%s%s" "Issues: " "${problems[*]}"
                printf "\n%s\n" "Execute 'iob nodejs-update' in your terminal."
            fi
        fi
        return 1
    else
        if [[ "$show_messages" == "true" ]]; then
            if [[ "$SKRPTLANG" == "--de" ]]; then
                printf "\n\n%b%s%b\n\n" "$GREEN" "✓ Node.js ist korrekt installiert" "$NC"
            else
                printf "\n\n%b%s%b\n\n" "$GREEN" "✓ Node.js installation is correct" "$NC"
            fi
        fi
        return 0
    fi
}

printf "\n%b%s%b\n" "$HEADLINE" "*** NodeJS-Installation ***" "$NC"
printf "\n%s\t\t%s" "$PATHNODEJS" "$VERNODEJS"
printf "\n%s\t\t%s" "$PATHNODE" "$VERNODE"
printf "\n%s\t\t%s" "$PATHNPM" "$VERNPM"
printf "\n%s\t\t%s" "$PATHNPX" "$VERNPX"

check_nodejs_installation

if [ -f /usr/bin/apt-cache ]; then
    apt-cache policy nodejs
fi

ANZNPMTMP=$(find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium' | wc -l)
printf "\n%b%s%b%s\n" "$GREEN" "Temp directories causing deletion problem: " "$NC" "$ANZNPMTMP"
if (( ANZNPMTMP > 0 )); then
    printf "%b%s%b" "$RED" "Some problems detected, please run 'iob fix'" "$NC"
else
    printf "%b%s%b" "$GREEN" "No problems detected" "$NC"
fi

if grep -q ERR <<< "$NPMLS"; then
    printf "\n\n%b%s%b" "$GREEN" "Errors in npm tree:" "$NC"
    echo "$NPMLS" | grep ERR
    echo ""
else
    printf "\n\n%b%s%b%s" "$GREEN" "Errors in npm tree: " "$NC" "0"
    printf "\n%b%s%b" "$GREEN" "No problems detected" "$NC"
fi

### Is my nodejs vulnerable?

if [[ $NODENOTCORR -eq 0 ]]; then
    printf "\n\n%b%s%b\n" "$GREEN" "Checking for nodejs vulnerability:" "$NC"
    if [ -d "/home/iobroker" ]; then
        cd /home/iobroker || exit
    else
        cd ~ || exit
    fi
    sudo -H -u "$(whoami)" npm i --silent is-my-node-vulnerable
    sudo -H -u "$(whoami)" npx is-my-node-vulnerable > /dev/null 2>&1
    EXIT_CODE=$?

    if [[ "$SKRPTLANG" == "--de" ]]; then
        if [ "$EXIT_CODE" -ne 0 ]; then
            printf '%sSicherheitslücken in der Node.js-Version erkannt!\n' "$RED"
            npx is-my-node-vulnerable
            printf '%s' "$NC"
        else
            printf '%sKeine bekannten Sicherheitslücken in der Node.js-Version erkannt!%s\n' "$GREEN" "$NC"
        fi
    else
        if [ "$EXIT_CODE" -ne 0 ]; then
                printf '%sVulnerabilities detected in the Node.js version!\n' "$RED"
                npx is-my-node-vulnerable
                printf '%s' "$NC"
            else
                printf '%sNo known Vulnerabilities detected!%s\n' "$GREEN" "$NC"
        fi
    fi
    cd || exit
fi

check_architecture

printf "\n\n%b%s%b" "$HEADLINE" "*** ioBroker-Installation ***" "$NC"
printf "\n%b%s%b\n" "$GREEN" "ioBroker Status" "$NC"
iob status $ALLOWROOT
printf "\n%b%s%b\n" "$GREEN" "Hosts:" "$NC"
iob list hosts $ALLOWROOT
printf "\n%b%s%b" "$GREEN" "Core adapters versions" "$NC"
printf "\n%s\t%s" "js-controller: " "$(iob -v $ALLOWROOT)"
printf "\n%s\t\t%s" "admin: " "$(iob version admin $ALLOWROOT)"
printf "\n%s\t%s" "javascript: " "$(iob version javascript $ALLOWROOT)"
printf '\n\n%b%s%b\t%d\n' "$GREEN" "nodejs modules from github: " "$NC" "$(grep -c 'github.com' <<< "$NPMLS")"
grep 'github.com' <<< "$(printf '\n\n%s\n' "$NPMLS")"
printf "\n\n%b%s%b\n" "$GREEN" "Adapter State" "$NC"
printf "%s\n\n" "$IOBLISTINST"
printf "%b%s%b\n" "$GREEN" "Enabled adapters with bindings" "$NC"
printf "%s" "$IOBLISTINST" | grep -E "enabled.*port"
echo ""
printf "\n%b%s%b\n" "$GREEN" "ioBroker-Repositories" "$NC"
iob repo list $ALLOWROOT
printf "\n\n%b%s%b\n" "$GREEN" "Installed ioBroker-Adapters" "$NC"
iob update -i $ALLOWROOT
printf "\n\n%b%s%b\n" "$GREEN" "Objects and States" "$NC"
echo "Please stand by - This may take a while"
IOBOBJECTS=$(iob list objects $ALLOWROOT 2>/dev/null | wc -l)
printf "\n%s\t%d" "Objects: " "$IOBOBJECTS"
IOBSTATES=$(iob list states $ALLOWROOT 2>/dev/null | wc -l)
printf "\n%s\t%d" "States: " "$IOBSTATES"

printf "\n\n%b%s%b\n\n" "$HEADLINE" "*** OS-Repositories and Updates ***" "$NC"
if [ -f /usr/bin/apt-get ]; then
    sudo apt-get update 1>/dev/null && sudo apt-get update
    APT=$(apt-get upgrade -s | grep -P '^\d+ upgraded' | cut -d" " -f1)

    if [[ "$SKRPTLANG" == "--de" ]]; then
        if (( APT == 0 )); then
            printf "\n%b%s%d%b" "$GREEN" "Offene Systemupdates: " "$APT" "$NC"
        else
            printf "\n%b%s%d%b"  "$RED" "Offene Systemupdates: " "$APT" "$NC"
        fi
    else
        if (( APT == 0 )); then
            printf "\n%b%s%d%b"  "$GREEN" "Pending systemupdates: " "$APT" "$NC"
        else
            printf "\n%b%s%d%b" "$RED" "Pending systemupdates: " "$APT" "$NC"
        fi
    fi
else
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "\n%s" "Es wurde kein auf Debian basierendes System erkannt"
    else
        printf "\n%s" "No Debian-based Linux detected."
    fi
fi

printf "\n\n%b%s%b\n" "$HEADLINE" "*** Listening Ports ***" "$NC"
if command -v ss &> /dev/null; then
    sudo ss -tulp
else
    sudo netstat -tulpn
fi

# Check if malware process pawns-cli is running
if pgrep "pawns-cli" > /dev/null; then
    if [ "$SKRPTLANG" == "--de" ]; then
        printf "\n%b%s" "$RED" "WARNUNG: Der Prozess 'pawns-cli' läuft auf diesem System!"
        printf "\n%s" "Dies könnte ein Hinweis auf Malwarebefall sein."
        printf "\n%s" "Bitte überprüfen Sie das System und entfernen Sie den Prozess, falls er nicht legitim ist."
        printf "\n%s" "Schauen Sie im Ordner Global bei den Skripten nach verdächtigen Einträgen"
        printf "\n%s" "Oftmals ist ein offen im Internet stehender ioBroker die Ursache. Das System muss abgesichert neuinstalliert werden."
        printf "\n%s%b" "Ein Backup muss aus der Zeit vor dem Befall stammen." "$NC"


    else
        printf "\n%b%s" "$RED" "WARNING: The process 'pawns-cli' is running on this system!"
        printf "\n%s" "This could be an indication of malware infection."
        printf "\n%s" "Please check the system and remove the process if it is not legitimate."
        printf "\n%s" "Check the scripts in the Global folder for any suspicious entries."
        printf "\n%s" "Often, the cause is an ioBroker installation that is openly accessible on the internet. The system must be reinstalled securely."
        printf "\n%s%b" "A backup must be from before the infection." "$NC"
    fi
    count=0
    matches=()

    for file in /tmp/*; do
        if [[ -e "$file" && "$file" =~ pawns-cli ]]; then
            matches+=("$file")
            ((count++))
        fi
    done

    if [[ "$SKRPTLANG" == "--de" ]]; then
        echo "Gefundene Dateien:"
        printf '%s\n' "${matches[@]}"
        echo -e "\nAnzahl der Malware-Dateien: $count"
    else
        echo "Found files:"
        printf '%s\n' "${matches[@]}"
        echo -e "\nNumber of malware: $count"
    fi
fi

printf "\n\n%b%s%b\n" "$HEADLINE" "*** Log File - Last 25 Lines ***" "$NC"
tail -n 25 /opt/iobroker/log/iobroker.current.log
printf "%s\n\n" '```'
if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%b%s%b" "$YELLOW" "============ Langfassung bis hier markieren =============" "$NC"
    printf "\n\n%s\n\n" "iob diag hat das System inspiziert."
    if [[ $SUMMARY != "summary" ]]; then
        exit
    else
        printf "\n\n%s" "Beliebige Taste für eine Zusammenfassung drücken"
    fi
else
    printf "\n%b%s%b"  "$YELLOW" "============= Mark until here for C&P =============" "$NC"
    printf "\n\n%s\n\n" "iob diag has finished."
    if [[ $SUMMARY != "summary" ]]; then
        exit
    else
        printf "\n\n%s" "Press any key for a summary"
    fi
    read -r -n 1 -s
fi
clear
if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%s" "Zusammfassung ab hier markieren und kopieren:"
    printf "\n\n%s" '```bash'
    printf "\n%s" "====================== ZUSAMMENFASSUNG ======================"
    printf "\n\t\t\t%s%s\n\n" "v." "$SKRIPTV"
else
    printf "\n%s" "Copy text starting here:"
    printf "\n\n%s" '```bash'
    printf "\n%s" "========================== SUMMARY =========================="
    printf "\n\t\t\t%s%s\n\n" "v." "$SKRIPTV"
fi

if [ -f "$DOCKER" ]; then
    INSTENV=2
elif [ "$SYSTDDVIRT" != "none" ]; then
    INSTENV=1
else
    INSTENV=0
fi
INSTENV2=$(
    if (( INSTENV == 2 )); then
        printf "%s" "Docker"
    elif (( INSTENV == 1 )); then
        printf "%s" "$SYSTDDVIRT"
    else
        printf "%s" "native"
    fi
)
if [[ -f "$DOCKER" ]]; then
    grep -i model /proc/cpuinfo | tail -1
    printf "\n%s%s" "Kernel          : " "$(uname -m)"
    printf "\n%s%s" "Userland        : " "$(dpkg --print-architecture)"
    if [[ -f "$DOCKER" ]]; then
        printf "\n%s%s" "Docker          : " "$(cat /opt/scripts/.docker_config/.thisisdocker)"
    else
        printf "\n%s" "Docker          : false"
    fi

else
    hostnamectl | grep -v 'Machine\|Boot'
fi
printf "\n%s\t\t%s" "Installation: " "$INSTENV2"
printf "\n%s\t\t%s" "Kernel: " "$(uname -m)"
printf "\n%s\t\t%s%s" "Userland: " "$(getconf LONG_BIT)" "bit"
if [ -f "$DOCKER" ]; then
    printf "\n%s\t\t%s" "Timezone: " "$(date +"%Z %z")"
else
    printf "\n%s\t\t%s" "Timezone: " "$(timedatectl | grep zone | cut -c28-80)"
fi
printf "\n%s\t\t%s" "User-ID: " "$EUID"
printf "\n%s\t%s" "Display-Server: " "$(if [[ $DESKTOP_SESSION ]]; then echo "true"; else echo "false"; fi)"
if [ ! -f "$DOCKER" ]; then
    printf "\n%s\t\t%s" "Boot Target: " "$(systemctl get-default)"
fi

if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%s\t%s" "Offene OS-Updates: " "$APT"
    printf "\n%s\t%s" "Offene iob updates: " "$(iob update -u $ALLOWROOT | grep -c 'Updatable\|Updateable')"
else
    printf "\n%s\t%s" "Pending OS-Updates: " "$APT"
    printf "\n%s\t%s" "Pending iob updates: " "$(iob update -u $ALLOWROOT | grep -c 'Updatable\|Updateable')"
fi
if [[ -f "/var/run/reboot-required" ]]; then
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "\n%b%s%b\n\n" "$RED" "Das System muss JETZT neugestartet werden!" "$NC"
    else
        printf "\n%b%s%b\n\n" "$RED"  "This system needs to be REBOOTED NOW!" "$NC"
    fi
fi

printf "\n\n%s" "Nodejs-Installation:"
printf "\n%s\t\t%s" "$PATHNODEJS" "$VERNODEJS"
printf "\n%s\t\t%s" "$PATHNODE" "$VERNODE"
printf "\n%s\t\t%s" "$PATHNPM" "$VERNPM"
printf "\n%s\t\t%s" "$PATHNPX" "$VERNPX"
if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%s%s%s%s" "Empfohlene Versionen sind zurzeit nodejs " "$NODERECOM" " und npm " "$NPMRECOM"
else
    printf "\n\n%s%s%s%s" "Recommended versions are nodejs " "$NODERECOM" " and npm " "$NPMRECOM"
fi
# Nutze die bereits existierende Funktion
if check_nodejs_installation false; then
    # Return 0 = Alles OK
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "\n%b%s%b" "$GREEN" "✓ Node.js ist korrekt installiert" "$NC"
    else
        printf "\n%b%s%b" "$GREEN" "✓ Node.js installation is correct" "$NC"
    fi
else
    # Return 1 = Fehler gefunden
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "\n\n%b%s%b" "$RED" "⚠ Node.js ist nicht korrekt installiert!" "$NC"
        printf "\n%b%s%b" "$RED" "Bitte den Befehl 'iob nodejs-update' zur Korrektur ausführen." "$NC"
    else
        printf "\n\n%b%s%b" "$RED" "⚠ Node.js is NOT correctly installed!" "$NC"
        printf "\n%b%s%b" "$RED" "Please execute 'iob nodejs-update' to fix these errors." "$NC"
    fi
fi

printf "\n\n%s\n" "MEMORY: "
free -ht --mega
printf "\n%s%s\n" "Active iob-Instances: " "$(echo "$IOBLISTINST" | grep -c ^+)"

printf "\n%s\n%s\t\t%s\n" "ioBroker Core:" "js-controller" "$(iob -v $ALLOWROOT)"
printf "%s\t\t\t%s\t\t\n" "admin " "$(iob version admin $ALLOWROOT)"
printf "\n%s\n%s\n" "ioBroker Status: " "$(iobroker status $ALLOWROOT)"
iob repo list $ALLOWROOT | tail -n1

# iobroker status all | grep MULTIHOSTSERVICE/enabled;
printf "\n%s\n" "Status admin and web instance:"
printf "\n\n%s" "$IOBLISTINST" | grep -E 'admin\.|system\.adapter\.web\.'
printf "\n%s\t\t%s" "Objects: " "$IOBOBJECTS"
printf "\n%s\t\t%s" "States: " "$IOBSTATES"
printf "\n\n%s\n" "Size of iob-Database:"
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*objects\* -exec du -sh {} + | sort -rh | head -n 5
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*states\* -exec du -sh {} + | sort -rh | head -n 5

if (( ANZNPMTMP > 0 )); then
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "\n\n\n%s" "**********************************************************************"
        printf "\n%s" "Probleme wurden erkannt, bitte \e[031miob fix\e[0m ausführen"
        printf "\n%s\n\n" "**********************************************************************"
    else
        printf "\n\n\n%s" "**********************************************************************"
        printf "\n%s" "Some problems detected, please run \e[031miob fix\e[0m and try to have them fixed"
        printf "\n%s\n\n" "**********************************************************************"
    fi
fi
if (( CRITERROR > 0 )); then
    if [[ "$SKRPTLANG" == "--de" ]]; then
        printf "\n%s%s%s\n%s\n" "Es wurden " "$CRITERROR" " KRITISCHE FEHLER gefunden. " "Siehe 'sudo dmesg --level=emerg,alert,crit -T' für Details"
    else
        printf "\n%s%s\n%s" "$CRITERROR" " CRITICAL ERRORS DETECTED! " "Check 'sudo dmesg --level=emerg,alert,crit -T' for details"
    fi
fi
echo -e  "$RELEASESTATUS"

if [[ "$SKRPTLANG" == "--de" ]]; then
    printf "\n%s" "=================== ENDE DER ZUSAMMENFASSUNG ===================="
    printf "\n%s\n" '```'
    printf "\n%s" "=== Ausgabe bis hier markieren und kopieren ==="
else
    printf "\n%s" "=================== END OF SUMMARY ===================="
    printf "\n%s\n" '```'
    printf "\n%s\n\n" "=== Mark text until here for copying ==="
fi
exit
