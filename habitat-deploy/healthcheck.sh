#!/bin/sh

# shellcheck disable=SC2009  # pgrep does not show arguments
STATUS_FILE="$(ps -o pid,args | grep -Po '^ *1 +.*/deploy.sh +\K[^ ]*')"

[ -f "$STATUS_FILE" ] || exit 1
currentStatus="$(cat "$STATUS_FILE")"
[ "$currentStatus" = "update" ] && exit 0
[ "$currentStatus" = "upgrade" ] && exit 0
[ "$currentStatus" = "starting" ] && exit 0
[ "$currentStatus" = "started" ] && exit 0

exit 2