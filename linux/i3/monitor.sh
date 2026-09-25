#!/bin/sh
# Hyper+4: workspace 4 = SSH monitor (top left) + nvidia-smi (bottom left) + btop (top right)
# + rig status (bottom right: ~/dev/rig/status.sh, Harbor jobs and containers).
# Opens whichever is missing.
has() { i3-msg -t get_tree | jq -e --arg c "$1" 'any(.. | objects | .window_properties?.class? // empty; . == $c)' >/dev/null; }
wait_for() { for _ in $(seq 50); do has "$1" && return; sleep 0.1; done; }
open() { class=$1; shift; setsid -f kitty --class "$class" "$@" >/dev/null 2>&1; wait_for "$class"; }

i3-msg -q "workspace number 4"
has ssh-watch || open ssh-watch ~/.local/bin/ssh-watch

if ! has btop-watch && command -v btop >/dev/null; then
  i3-msg -q '[class="^ssh-watch$"] focus, split h'
  open btop-watch btop
fi

if ! has nvsmi-watch && command -v nvidia-smi >/dev/null; then
  i3-msg -q '[class="^ssh-watch$"] focus, split v'
  open nvsmi-watch watch -n 2 -t nvidia-smi
fi

if ! has rig-status && [ -x ~/dev/rig/status.sh ]; then
  if has btop-watch; then i3-msg -q '[class="^btop-watch$"] focus, split v'
  else i3-msg -q '[class="^ssh-watch$"] focus, split h'; fi
  open rig-status ~/dev/rig/status.sh -w
fi

i3-msg -q '[class="^ssh-watch$"] resize set width 40 ppt'
i3-msg -q '[class="^ssh-watch$"] focus'
