#!/usr/bin/env bash
# Summarize .pm/usage.jsonl for the Grok-as-default worker trial.
#
# Usage:
#   week-eval.sh [path-to-usage.jsonl ...]
#   week-eval.sh                    # finds .pm/usage.jsonl under cwd + common repos
#   DAYS=7 week-eval.sh             # only last N days (default 7)
#
# Pricing (on-demand First-party; for relative burn only):
#   grok-4.5*:        $2 / $6  per 1M in/out
#   composer-2.5-fast:$3 / $15
#   composer-2.5:     $0.50 / $2.50
set -uo pipefail

DAYS="${DAYS:-7}"
files=("$@")
if [ ${#files[@]} -eq 0 ]; then
  while IFS= read -r f; do files+=("$f"); done < <(
    { find . -path '*/.pm/usage.jsonl' 2>/dev/null
      for d in "$HOME/dev"/*; do
        [ -f "$d/.pm/usage.jsonl" ] && echo "$d/.pm/usage.jsonl"
      done
    } | sort -u
  )
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "no .pm/usage.jsonl found" >&2
  exit 1
fi

DAYS="$DAYS" python3 - "${files[@]}" <<'PY'
import json, os, sys, time
from collections import defaultdict

cutoff = int(time.time()) - int(os.environ.get("DAYS", "7")) * 86400
# model prefix -> (in_per_m, out_per_m)
RATES = {
    "grok-4.5-fast": (4.0, 18.0),
    "grok-4.5": (2.0, 6.0),
    "composer-2.5-fast": (3.0, 15.0),
    "composer-2.5": (0.5, 2.5),
}

def rate(model: str):
    m = (model or "").lower()
    for k, v in RATES.items():
        if m.startswith(k):
            return v
    return (2.0, 6.0)  # unknown → grok-ish

rows = []
for path in sys.argv[1:]:
    try:
        lines = open(path).read().splitlines()
    except OSError as e:
        print(f"skip {path}: {e}", file=sys.stderr)
        continue
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if int(r.get("ts") or 0) < cutoff:
            continue
        r["_src"] = path
        rows.append(r)

if not rows:
    print(f"no usage rows in last {os.environ.get('DAYS','7')} days across {len(sys.argv)-1} file(s)")
    sys.exit(0)

by = defaultdict(list)
for r in rows:
    by[r.get("model") or "(unknown)"].append(r)

print(f"window: last {os.environ.get('DAYS','7')}d | files: {len(sys.argv)-1} | rows: {len(rows)}")
print()
hdr = f"{'model':<28} {'n':>4} {'ok%':>5} {'resume%':>8} {'labels':>6} {'avg_ms':>8} {'avg_in':>8} {'avg_out':>8} {'est_$':>8}"
print(hdr)
print("-" * len(hdr))

def avg(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None

def fmt(x, nd=0):
    if x is None:
        return "-"
    return f"{x:.{nd}f}" if nd else f"{int(round(x))}"

for model in sorted(by, key=lambda m: (-len(by[m]), m)):
    rs = by[model]
    n = len(rs)
    ok = sum(1 for r in rs if r.get("ok", True))
    resumes = sum(1 for r in rs if r.get("resume"))
    labels = {r.get("label") for r in rs if r.get("label")}
    # resumes per distinct label (proxy for babysitting)
    label_runs = defaultdict(int)
    for r in rs:
        label_runs[r.get("label")] += 1
    multi = sum(1 for c in label_runs.values() if c > 1)
    ain, aout = rate(model)
    cost = 0.0
    for r in rs:
        i, o = r.get("in") or 0, r.get("out") or 0
        cost += (i / 1e6) * ain + (o / 1e6) * aout
    print(
        f"{model:<28} {n:>4} {100*ok/n:>4.0f}% {100*resumes/n:>7.0f}% "
        f"{len(labels):>6} {fmt(avg([r.get('dur_ms') for r in rs])):>8} "
        f"{fmt(avg([r.get('in') for r in rs])):>8} {fmt(avg([r.get('out') for r in rs])):>8} "
        f"{cost:>8.2f}"
    )

print()
print("decision cues:")
print("  keep grok default  — ok% high, resume% not worse than composer, est_$ still cheap, few Codex escalations (manual)")
print("  demote             — resume%/multi-round labels spike, or you rewrite diffs often")
print("  revert             — quality ≈ composer but burns First-party pool much faster")
print()
# per-label multi-round hotspots
hot = sorted(
    ((lab, sum(1 for r in rows if r.get("label") == lab),
      next((r.get("model") for r in rows if r.get("label") == lab), "?"))
     for lab in {r.get("label") for r in rows}),
    key=lambda x: -x[1],
)
hot = [h for h in hot if h[1] >= 2][:10]
if hot:
    print("multi-round labels (babysitting hotspots):")
    for lab, c, m in hot:
        print(f"  {c}x  {lab}  [{m}]")
else:
    print("no multi-round labels in window (good)")
PY
