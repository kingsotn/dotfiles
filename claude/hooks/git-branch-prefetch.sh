#!/bin/sh
# PreToolUse(Bash) hook: when the command is about to create a git branch,
# run `git fetch origin` first so the global reference-transaction hook
# (~/.config/git/hooks) sees a fresh FETCH_HEAD and allows the branch.
# Managed by /cf (~/.claude/skills/cf).

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

printf '%s' "$cmd" | grep -qE 'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(checkout[[:space:]]+-b|switch[[:space:]]+(-c|--create)|branch[[:space:]]+[A-Za-z0-9_./]|worktree[[:space:]]+add[[:space:]].*-b[[:space:]])' || exit 0

# Fetch in the repo the command targets (honor `git -C <path>` if present).
target=$(printf '%s' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
if [ -n "$target" ]; then
  git -C "$target" fetch origin >/dev/null 2>&1 || true
else
  git fetch origin >/dev/null 2>&1 || true
fi
exit 0
