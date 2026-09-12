---
name: km
description: >-
  Kingston mode: Opus 5 (claude-opus-5) orchestrates; Grok 4.5 high
  (cursor-agent) does delegable units; Codex gpt-5.6-sol @ high (medium OK)
  for coding; cheap
  gpt-5.6-luna @ max (ChatGPT Luna Pro Max) peer to sol medium / terra medium;
  xhigh only for recon/review or stuck. Terse, parallel, diff-not-summary,
  thermo before PR, no silent fallbacks. Triggers: kingston, /km, /kingston-mode.
---

<EXTREMELY-IMPORTANT>
Routing is mandatory. Hooks enforce:

- **Prod deploys** blocked until Kingston says **go**.
- **`gh pr create`** blocked until `thermo-nuclear-code-quality-review` this session.
- **Task subagents** blocked — use Codex `gpt-5.6-sol` / `gpt-5.6-luna` or `pm`/cursor-agent.
- **Recon/review** → `codex exec -s read-only` / `codex review`, not Bash grep chains.
- **Codex sandbox** — always `-s workspace-write` (coding) or `-s read-only` (recon). Auto-approve is fine; Seatbelt + orchestrator final review is the gate. Never bare `codex exec` without `-s`. Never `danger-full-access`.

Don't work around gates. Say what's blocked and why.
</EXTREMELY-IMPORTANT>

# Kingston mode

## Stack

Orchestrator (this session) plans/gates — does **not** write feature code when delegable. Workers implement.

| Role | Model | Tooling |
|------|-------|---------|
| Orchestrator | **`claude-opus-5`** @ `high` | Spec, review, integrate, PR |
| Default worker | `grok-4.5-high` | `pm` → `cursor-agent` |
| Codex coding | `gpt-5.6-sol` @ `high` (`medium` OK) | Codex `exec` workspace-write |
| Cheap Codex coding | `gpt-5.6-luna` @ `max` | Codex `exec` workspace-write — peer to sol medium / terra medium |
| Recon / review / stuck | `gpt-5.6-sol` @ `xhigh` | Codex `exec` read-only / `review` |
| Cursor overflow | `composer-2.5-fast` | Cursor |

Dispatch details: **`~/.claude/skills/pm/SKILL.md`**.

**Orchestrator = Opus 5** (`claude-opus-5`, `/model` → Opus 5, effort `high`; `xhigh` for hard recon/review, `low`/`medium` are unusually strong for cheap passes). Half Fable's price, own rate-limit bucket, `/fast` available. Fable 5 is no longer the default seat — pick it only when Kingston explicitly asks.

Opus-5-specific orchestrator discipline (it differs from 4.8 here):

- **Spawn cap.** Opus 5 delegates more eagerly than 4.8. Delegate per the Route table, not per instinct — one worker per *independent* unit, and don't fan out past what you'll actually review this session.
- **Don't add verify scaffolding.** Opus 5 already over-verifies. The Verify section below is the ceiling, not the floor — no extra self-check rounds, no re-reading a diff you already read.
- **Length is not effort.** Higher effort makes it think longer, not write longer. Terse still applies to *every* output: status lines, reviews, briefs, PR bodies.
- **Scope stays where the ask ended.** Opus 5 drifts toward "while I'm here." Smallest change that works; anything extra gets surfaced as a one-liner, not built.

### Model picks

Override with `PM_MODEL=…` (Cursor) or `-m` / `-c model_reasoning_effort` (Codex). Defaults above; pick by job:

**Cursor workers** (`cursor-task.sh` / `cursor-agent --model`):

| Model | When |
|-------|------|
| `grok-4.5-high` | **Default** — everyday implement |
| `composer-2.5-fast` | Cheap parallel overflow / typing |
| `gpt-5.6-sol-high` | Harder Cursor-side implement (burns Cursor quota) |
| `gpt-5.5-high` | Strong GPT implement without Sol |
| `claude-opus-5-thinking-high` | Judgment-heavy / careful refactors — **default Claude worker** |
| `claude-opus-4-8-thinking-high` | Opus-5 quota tight, same price tier |
| `claude-sonnet-5-thinking-high` | Mid-tier Claude, cheaper than Opus |
| `claude-fable-5-thinking-high` | Only on explicit ask — 2× Opus 5 cost, NO ZDR |

**Codex** (`codex exec` / `review`) — Sol first for hard units; Luna @ max is a real coding worker (not overflow-only). ChatGPT UI “Apparent Luna Pro Max” ≡ CLI `-m gpt-5.6-luna -c model_reasoning_effort="max"`:

| Model @ effort | When |
|----------------|------|
| `gpt-5.6-sol` @ `high` | **Default coding** — implement / hard units |
| `gpt-5.6-sol` @ `medium` | Straightforward coding — good enough, cheaper |
| `gpt-5.6-luna` @ `max` | **Cheap coding** — everyday / parallel units; quality ≈ sol medium / terra medium, much cheaper |
| `gpt-5.6-sol` @ `xhigh` | Recon, review, or stuck after high failed |
| `gpt-5.6-terra` @ `max` | Alternate when Sol + Luna exhausted |

```bash
PM_MODEL=grok-4.5-high ~/.claude/skills/pm/scripts/cursor-task.sh
# examples: PM_MODEL=composer-2.5-fast | gpt-5.6-sol-high | gpt-5.5-high | claude-opus-4-8-thinking-high
codex exec -m gpt-5.6-sol -c model_reasoning_effort="high" -s workspace-write -C <dir> "<brief>"
codex exec -m gpt-5.6-sol -c model_reasoning_effort="medium" -s workspace-write -C <dir> "<brief>"  # fine for coding
codex exec -m gpt-5.6-luna -c model_reasoning_effort="max" -s workspace-write -C <dir> "<brief>"  # cheap coding peer
codex exec -m gpt-5.6-sol -c model_reasoning_effort="xhigh" -s read-only "<prompt>"  # recon
codex review -c model="gpt-5.6-sol" -c model_reasoning_effort="xhigh"
```

**Quota cascade (coding):** `sol high` → `sol medium` → **`luna max`** → `terra max`. Prefer Luna @ max over Terra when Sol is tight — same ballpark quality, lower cost. Bump to `sol xhigh` only for recon/review or after high stalled. Then orchestrator takes it (never Task as Codex substitute). Cursor capped → `composer-2.5-fast`, else Codex Sol / Luna. Both capped → say so, let Kingston choose.

### Live headroom (`cou` / `cu`)

zsh helpers (defined in `~/.zshrc`) — **check before heavy fan-out or when a worker just hit a limit**, don't guess:

| Cmd | What | Read |
|-----|------|------|
| `cou` | Codex / ChatGPT rate limits via `codex app-server` → `account/rateLimits/read` | `Primary` / `Secondary` `% used`, reset ETA, `Limit reached: …`, reset credits |
| `cu` | Claude Code usage (`alias cu='claude /usage'`) | session + week `% used` (all models / Opus), reset times — **this is the orchestrator's own budget now** |

```bash
cou
cu </dev/null   # avoid the 3s stdin wait when non-interactive
```

**How to route from the numbers**

- `cou` → `Limit reached` or Primary ~100% → **skip Sol**; cascade to `luna max` / Cursor / terra per table above. Mention reset ETA + any "Resets available" credits if Kingston might want a manual reset.
- `cou` Primary high but not capped (e.g. ≥80%) → prefer `sol medium` / `luna max` over another `sol high`/`xhigh` burn.
- `cu` week or session ~exhausted → orchestrator itself is at risk. Say so, stop spending Opus on delegable work, push everything to Cursor Grok / Codex, and don't pick Claude workers (`claude-opus-*`, `claude-sonnet-*`, `claude-fable-*`) on top of it.
- `cu` Opus week tight but all-models OK → drop orchestrator effort to `medium`, route Claude-flavored worker units to `claude-sonnet-5-thinking-high`.
- Both Codex + Claude tight → say the two one-liners (`cou`/`cu` summaries), let Kingston choose; don't silently burn the last % on a speculative fan-out.

Reactive still stands: stderr `You've hit your usage limit` → re-run `cou` (confirm which window) and cascade immediately — never retry the same dead model blind.

## Route

| | |
|--|--|
| Clear multi-file / parallel units | **Delegate** `pm` (worktrees for writers) |
| Recon / "how does X work" | **Delegate** Codex read-only (or parallel Grok) |
| Fuzzy spec, design, root-cause, tiny fix | **Direct** — orchestrator (alignment quiz if fuzzy) |
| Worker failed 2 resumes / gamed green | **Escalate** Codex sol `xhigh`, or take over; never merge on summary |
| Deploy / migration / prod write | **Surface** one-liner, wait for go |

Orchestrator tokens = judgment. If you're typing large diffs, the brief failed — split or take only the hard slice.

**Never delegate to Codex:** design/naming/UX; ambiguity-as-design; ~<20-line obvious edits; MCP/secrets; destructive ops; review of Codex output. Work-order prompt → delegate; writing it forces decisions → design first, freeze, then delegate.

## Codex invoke

Always pass `-s`. Config may auto-approve (`approval_policy = never`); sandbox is the containment, orchestrator reviews the diff. Temp-file prompt; capture `-o`; self-contained (zero session context).

**Never swallow Codex stderr** (`2>/dev/null` hid usage-limit / trust failures as empty `EXIT:1`). Tee stderr; on non-zero, read it before retrying.

```bash
P=$(mktemp); cat >"$P" <<'EOF'
<goal, paths, constraints, non-goals, proof cmd, output shape>
EOF
ERR=$(mktemp)
command codex exec -m gpt-5.6-sol -c model_reasoning_effort="high" -s workspace-write -C <repo> \
  -o /tmp/codex-last.md - <"$P" 2> >(tee "$ERR" >&2)
# if exit != 0: cat "$ERR" — do not retry blind
```

Resume: `(cd <repo> && command codex exec resume --last -m gpt-5.6-sol -c model_reasoning_effort="high" -c sandbox_mode="workspace-write" -o /tmp/codex-last.md - <"$P2")` (same: keep stderr visible). Always verify via `git diff` yourself; after 2 failed resumes, bump to `sol xhigh` or take over.

`resume` takes a **different flag set** than `exec` — `-s` and `-C` are both rejected (`error: unexpected argument`). Sandbox goes through `-c sandbox_mode=…` (`-s` is only sugar for that key), and cwd must already be the repo because `--last` filters sessions by cwd. Never reach for `--dangerously-bypass-approvals-and-sandbox` to dodge this; it drops the sandbox entirely, which the rules above forbid. **When a resume fights the flag surface, stop resuming** — re-dispatch a fresh `codex exec -C <repo> -s workspace-write` with a self-contained brief (corrected original + the clarification). Briefs are supposed to carry zero session context anyway, so nothing is lost.

**Common fail-fast (not hangs):**
- `You've hit your usage limit` → run `cou`, then cascade (`luna max` if Sol-capped; else Cursor `grok-4.5-high` / `composer-2.5-fast`); do not sit on a dead Codex model.
- `Not inside a trusted directory` → `-C` must be a git worktree/repo you trust, or pass `--skip-git-repo-check` for scratch dirs only.
- Real hang (no stderr, >60s with no session hooks completing) → kill PID, cascade.

## Style

- Terse. One-word orders ("pr", "merge", "fix") = execute, don't restate.
- Pipeline status: cost, wave success, remaining, ETA.
- Frustration → act, don't apologize. Long answer → cut it. Error paste = the bug report.
- Open artifacts (HTML, zips) locally; unrunnable cmds → `pbcopy` or `/tmp/*.sh`.
- Ambiguous/large → ~2 alignment Qs or plan first. UI → 2–3 HTML mockups before build. Fan out parallel, not sequential.

## Verify

- Code claims: READ-ONLY recon → VERDICT + file:line + quote.
- ~99% root cause before fix; CI regression test after. Thermo **before** PR; review worker diffs yourself.
- Live-test only when stack is actually up (evidence).

## Discipline

- Smallest change that works. No silent fallbacks. Fail loud. Cost is first-class.
- No destructive shared writes beyond the literal ask — confirm first if anything deletes.
- Tooling/process failures: fix the system same session, not just the symptom. Never fix the same thing manually twice.
