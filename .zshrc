export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="eastwood"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

set_prompt() {
  PS1="%{$fg[cyan]%}%n@%m $(git_custom_status)[%~% ]%{$reset_color%}%B$%b "
}
precmd_functions+=(set_prompt)

export EDITOR="cursor --wait"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

alias python=python3
alias claude="claude --dangerously-skip-permissions"
alias cu='claude /usage'

# Codex has no CLI for usage. Query account/rateLimits/read via app-server JSON-RPC.
cou() {
  python3 - <<'PY'
import json, select, subprocess, sys, time
from datetime import datetime, timezone

def send(proc, obj):
    proc.stdin.write(json.dumps(obj) + "\n")
    proc.stdin.flush()

def read_until(proc, pred, timeout=15.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], max(0.0, deadline - time.time()))
        if not ready:
            continue
        line = proc.stdout.readline()
        if not line:
            break
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if pred(msg):
            return msg
    raise TimeoutError("timed out waiting for codex app-server")

def fmt_window(label, w):
    if not w:
        return f"  {label}: n/a"
    used = w.get("usedPercent")
    mins = w.get("windowDurationMins")
    resets = w.get("resetsAt")
    bits = []
    if used is not None:
        bits.append(f"{used}% used")
    if mins:
        if mins % 1440 == 0:
            bits.append(f"{mins // 1440}d window")
        elif mins % 60 == 0:
            bits.append(f"{mins // 60}h window")
        else:
            bits.append(f"{mins}m window")
    if resets:
        when = datetime.fromtimestamp(resets, tz=timezone.utc).astimezone()
        remaining = resets - time.time()
        if remaining > 0:
            h, rem = divmod(int(remaining), 3600)
            d, h = divmod(h, 24)
            m = rem // 60
            eta = f"{d}d {h}h" if d else (f"{h}h {m}m" if h else f"{m}m")
            bits.append(f"resets in {eta} ({when:%a %b %-d %-I:%M%p})")
        else:
            bits.append(f"reset due ({when:%a %b %-d %-I:%M%p})")
    return f"  {label}: " + " · ".join(bits)

proc = subprocess.Popen(
    ["codex", "app-server"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1,
)
try:
    send(proc, {
        "jsonrpc": "2.0",
        "id": 0,
        "method": "initialize",
        "params": {"clientInfo": {"name": "cou", "title": "cou", "version": "1.0"}},
    })
    read_until(proc, lambda m: m.get("id") == 0)
    send(proc, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
    send(proc, {"jsonrpc": "2.0", "id": 1, "method": "account/rateLimits/read", "params": {}})
    resp = read_until(proc, lambda m: m.get("id") == 1)
finally:
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except Exception:
        proc.kill()

if "error" in resp:
    print(json.dumps(resp["error"], indent=2), file=sys.stderr)
    sys.exit(1)

result = resp.get("result") or {}
rl = result.get("rateLimits") or {}
plan = rl.get("planType") or "unknown"
print(f"Codex usage ({plan})")
print(fmt_window("Primary", rl.get("primary")))
print(fmt_window("Secondary", rl.get("secondary")))
credits = result.get("rateLimitResetCredits") or {}
available = credits.get("availableCount")
if available is not None:
    print(f"  Resets available: {available}")
    for c in credits.get("credits") or []:
        if c.get("status") != "available":
            continue
        exp = c.get("expiresAt")
        exp_s = ""
        if exp:
            when = datetime.fromtimestamp(exp, tz=timezone.utc).astimezone()
            exp_s = f" · expires {when:%b %-d}"
        title = c.get("title") or c.get("resetType") or "reset"
        print(f"    - {title}{exp_s}")
reached = rl.get("rateLimitReachedType")
if reached:
    print(f"  Limit reached: {reached}")
PY
}

# Private machine overrides. Not in this repo.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
