#!/bin/sh
# Hyper+4: workspace 4 = SSH monitor (left) + btop (right). Opens whichever is missing.
has() { i3-msg -t get_tree | jq -e --arg c "$1" 'any(.. | objects | .window_properties?.class? // empty; . == $c)' >/dev/null; }
wait_for() { for _ in $(seq 50); do has "$1" && return; sleep 0.1; done; }

i3-msg -q "workspace number 4"
if ! has ssh-watch; then
  setsid -f kitty --class ssh-watch ~/.local/bin/ssh-watch >/dev/null 2>&1
  wait_for ssh-watch
fi
if ! has btop-watch && command -v btop >/dev/null; then
  i3-msg -q '[class="^ssh-watch$"] focus, split h'
  setsid -f kitty --class btop-watch btop >/dev/null 2>&1
  wait_for btop-watch
  i3-msg -q '[class="^ssh-watch$"] resize set width 40 ppt'
fi
