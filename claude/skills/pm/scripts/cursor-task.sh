#!/usr/bin/env bash
# Dispatch ONE task to a Cursor (Grok 4.5 high) subagent — headless & autonomous.
#
# Usage (prompt is read from stdin):
#   cursor-task.sh <label> <workspace-dir>                 # new subagent
#   cursor-task.sh <label> <workspace-dir> --resume <sid>  # continue an existing one
#
# Env:
#   PM_DIR    where transcripts land   (default: .pm)
#   PM_MODEL  cursor model id          (default: grok-4.5-high)
#
# Output: prints "session_id=<sid>" on line 1, then the subagent's final result.
# Artifacts in $PM_DIR: <label>.json (latest transcript; resumes rotate prior runs
# to <label>.N.json), <label>.brief.md (every brief sent), usage.jsonl (cost trail).
set -uo pipefail

label="${1:?label required}"; ws="${2:?workspace dir required}"; shift 2
resume_sid=""
if [ "${1:-}" = "--resume" ]; then resume_sid="${2:?session id required after --resume}"; shift 2; fi

PM_DIR="${PM_DIR:-.pm}"; mkdir -p "$PM_DIR"
PM_MODEL="${PM_MODEL:-grok-4.5-high}"
prompt="$(cat)"
err="$PM_DIR/$label.err"

# Persist the brief (with model stamp), and rotate transcripts on resume so
# iteration history survives. Latest result is always $label.json; prior runs
# become $label.1.json, $label.2.json, ...
{
  printf '# model=%s resume=%s ts=%s\n' "$PM_MODEL" "${resume_sid:-none}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\n' "$prompt"
  printf '\n'
} >>"$PM_DIR/$label.brief.md"
out="$PM_DIR/$label.json"
if [ -n "$resume_sid" ] && [ -f "$out" ]; then
  n=1; while [ -f "$PM_DIR/$label.$n.json" ]; do n=$((n+1)); done
  mv "$out" "$PM_DIR/$label.$n.json"
fi

args=(--print --output-format json --model "$PM_MODEL" --force --trust --workspace "$ws")
[ -n "$resume_sid" ] && args+=(--resume "$resume_sid")

cursor-agent "${args[@]}" -p "$prompt" >"$out" 2>"$err" || true

PM_DIR="$PM_DIR" PM_LABEL="$label" PM_MODEL="$PM_MODEL" PM_RESUME="${resume_sid:-}" \
  python3 - "$out" "$err" <<'PY'
import json, os, sys, time
out, err = sys.argv[1], sys.argv[2]
model = os.environ.get("PM_MODEL", "")
resume = os.environ.get("PM_RESUME", "") or None
label = os.environ["PM_LABEL"]
usage_path = os.path.join(os.environ["PM_DIR"], "usage.jsonl")

def append(row):
    with open(usage_path, "a") as fh:
        fh.write(json.dumps(row) + "\n")

try:
    d = json.load(open(out))
except Exception:
    sys.stderr.write(open(err).read())
    append({
        "ts": int(time.time()),
        "label": label,
        "model": model,
        "resume": bool(resume),
        "sid": None,
        "ok": False,
        "dur_ms": None,
        "in": None,
        "out": None,
        "cache_read": None,
    })
    print("session_id="); print("(no result — subagent errored, see .err)"); sys.exit(0)

sid = d.get("session_id", "")
print("session_id=%s" % sid)
u = d.get("usage", {}) or {}
row = {
    "ts": int(time.time()),
    "label": label,
    "model": model,
    "resume": bool(resume),
    "sid": sid or None,
    "ok": True,
    "dur_ms": d.get("duration_ms"),
    "in": u.get("inputTokens"),
    "out": u.get("outputTokens"),
    "cache_read": u.get("cacheReadTokens"),
}
append(row)
if u:
    sys.stderr.write("tokens in=%s out=%s cache_read=%s model=%s\n" %
                     (u.get("inputTokens"), u.get("outputTokens"),
                      u.get("cacheReadTokens"), model))
print(d.get("result", "") or "(empty result)")
PY
