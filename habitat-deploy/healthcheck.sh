#!/usr/bin/env bash

set -euo pipefail

# shellcheck disable=SC2009  # pgrep does not show arguments
STATUS_FILE="$(ps -o pid,args | grep -Po '^ *1 +.*/deploy.sh +\K[^ ]*')"

[ -f "$STATUS_FILE" ] && [ -x "$STATUS_FILE" ] && [ "$(cat "$STATUS_FILE")" == "started" ] && \
    exit 0

exit 1