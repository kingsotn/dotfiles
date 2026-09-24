#!/bin/sh
# Like Karabiner's `open -a`: focus the app if it has a window, otherwise go to
# its workspace and launch it.
# usage: hyper-app.sh <workspace> <class regex> [command...]
ws=$1
cls=$2
shift 2

if i3-msg -t get_tree | jq -e --arg c "$cls" \
  'any(.. | objects | .window_properties?.class? // empty; test($c; "i"))' >/dev/null; then
  i3-msg -q "[class=\"(?i)$cls\"] focus"
else
  i3-msg -q "workspace number $ws"
  [ $# -gt 0 ] && command -v "$1" >/dev/null && setsid -f "$@" >/dev/null 2>&1
fi
