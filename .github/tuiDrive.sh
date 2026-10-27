#!/usr/bin/env bash
# Runs installer or fixer with the interactive display under the util-linux "script", like a user
# at a terminal who presses Enter whenever a dialog waits, which takes its preselected choice.
#
# Usage: tuiDrive.sh <typescript> <rows> <cols> <script> [options...]
# The exit code is the one of the script.
#
# - The keys are pressed one at a time, when the screen has stopped changing: the progress view
#   redraws its ticker every 0.2 s, so only a dialog keeps the output quiet. Keys typed ahead do
#   not work, because sudo with use_pty (the default of sudo-rs) reads pending input away from
#   the terminal before the next dialog is drawn.
# - stdin of "script" stays open until the script has ended: an early EOF reaches the dialogs as
#   a closed terminal, and the util-linux "script" ends only after EOF on its stdin.

set -u

typescript=$1
rows=$2
cols=$3
shift 3

result="$typescript.rc"
rm -f "$typescript" "$result"
printf -v command '%q ' "$@"
printf -v result_arg '%q' "$result"

press_enter_when_quiet() {
    local size last=-1 quiet=0
    while [ ! -e "$result" ]; do
        sleep 1
        size=$(wc -c <"$typescript" 2>/dev/null || echo 0)
        if [ "$size" -ne "$last" ]; then
            last=$size
            quiet=0
        elif [ $((++quiet)) -ge 5 ]; then
            echo "Enter after $SECONDS s" >&2
            printf '\r'
            quiet=0
        fi
    done
}

script -qfec "stty rows $rows cols $cols; env -u CI TERM=xterm-256color bash $command; echo \$? > $result_arg" \
    "$typescript" < <(press_enter_when_quiet) >/dev/null

if [ ! -s "$result" ]; then
    echo "The script did not report an exit code"
    exit 1
fi
exit "$(cat "$result")"
