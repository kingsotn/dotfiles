#!/bin/bash
# Claude Code Status Line
# Receives JSON via stdin with session metrics

INPUT=$(cat)

# Parse all fields with jq
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')
USED_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_SIZE=$(echo "$INPUT" | jq -r '.context_window.context_window_size // 200000')
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0')
API_MS=$(echo "$INPUT" | jq -r '.cost.total_api_duration_ms // 0')
LINES_ADD=$(echo "$INPUT" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // 0')

# Format duration as Xm Ys
DURATION_S=$((DURATION_MS / 1000))
MINS=$((DURATION_S / 60))
SECS=$((DURATION_S % 60))
if [ "$MINS" -gt 0 ]; then
  DURATION_FMT="${MINS}m${SECS}s"
else
  DURATION_FMT="${SECS}s"
fi

# Context bar (10 chars wide)
BAR_WIDTH=10
FILLED=$((USED_PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

# Context size label
if [ "$CTX_SIZE" -ge 1000000 ]; then
  CTX_LABEL="1M"
else
  CTX_LABEL="200K"
fi

# Color coding for context usage
if [ "$USED_PCT" -ge 80 ]; then
  PCT_COLOR="\033[31m"  # red
elif [ "$USED_PCT" -ge 50 ]; then
  PCT_COLOR="\033[33m"  # yellow
else
  PCT_COLOR="\033[32m"  # green
fi

RESET="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
RED="\033[31m"
BRIGHT_CYAN="\033[96m"
BRIGHT_YELLOW="\033[93m"
BRIGHT_MAGENTA="\033[95m"

# Net lines delta
NET_LINES=$((LINES_ADD - LINES_DEL))

# Git branch + worktree
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
WORKTREE_BRANCH=$(echo "$INPUT" | jq -r '.worktree.branch // ""')
WORKTREE_NAME=$(echo "$INPUT" | jq -r '.worktree.name // ""')

if [ -n "$WORKTREE_BRANCH" ]; then
  BRANCH="$WORKTREE_BRANCH"
  IS_WORKTREE=1
elif [ -n "$WORKTREE_NAME" ]; then
  BRANCH="$WORKTREE_NAME"
  IS_WORKTREE=1
else
  IS_WORKTREE=0
  if [ -n "$CWD" ]; then
    BRANCH=$(git -C "$CWD" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  else
    BRANCH=$(git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  fi
fi

if [ -z "$BRANCH" ]; then
  BRANCH="${CWD:-$(pwd)}"
  IS_PATH=1
else
  IS_PATH=0
fi

# Cost formatting
if (( $(echo "$COST > 1" | bc -l 2>/dev/null || echo 0) )); then
  COST_FMT=$(printf '$%.2f' "$COST")
elif (( $(echo "$COST > 0" | bc -l 2>/dev/null || echo 0) )); then
  CENTS=$(echo "$COST * 100" | bc -l 2>/dev/null | cut -d. -f1)
  COST_FMT="${CENTS}¢"
else
  COST_FMT="0¢"
fi

# ── Line 1: the three things that must always be visible ──────────────────────
# [branch/worktree]  |  [model]  |  [context bar + %]

SEP="${DIM} │ ${RESET}"

# Branch segment
if [ "$IS_WORKTREE" -eq 1 ]; then
  BRANCH_STR="${BOLD}${BRIGHT_YELLOW}wt:${BRANCH}${RESET}"
elif [ "$IS_PATH" -eq 1 ]; then
  BRANCH_STR="${BOLD}${BRIGHT_CYAN}${BRANCH}${RESET}"
else
  BRANCH_STR="${BOLD}${BRIGHT_CYAN}${BRANCH}${RESET}"
fi

# Model segment: "Claude Opus 4.6 (1M context)" → "Opus 4.6"
# Strip "Claude ", strip parentheticals "(…)", trim trailing whitespace
MODEL_SHORT=$(echo "$MODEL" | sed 's/Claude //' | sed 's/ *([^)]*)//g' | sed 's/[[:space:]]*$//')
MODEL_STR="${BRIGHT_MAGENTA}${MODEL_SHORT}${RESET}"

# Context segment
CTX_STR="${PCT_COLOR}${BAR} ${USED_PCT}%/${CTX_LABEL}${RESET}"

echo -e "${BRANCH_STR}${SEP}${MODEL_STR}${SEP}${CTX_STR}"

# ── Line 2: secondary stats ────────────────────────────────────────────────────
echo -e "${DIM}cost:${RESET}${CYAN}${COST_FMT}${RESET}${SEP}${GREEN}+${LINES_ADD}${RESET}${RED}-${LINES_DEL}${RESET}${DIM}(${NET_LINES})${RESET}${SEP}${DIM}${DURATION_FMT}${RESET}"
