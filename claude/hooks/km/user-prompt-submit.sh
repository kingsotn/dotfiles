#!/usr/bin/env bash
set -euo pipefail
exec python3 "$(dirname "$0")/km_hooks.py" user-prompt-submit
