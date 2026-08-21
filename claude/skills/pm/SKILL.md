---
name: pm
description: Use when you want to ship a coding task as an agent team — Opus 5 orchestrates and reviews while Cursor (Grok 4.5 high) subagents do the implementation. Triggers: "act as PM", "use cursor agents", "spin up a team", "delegate the coding to grok", km / kingston-mode implementation work, parallel feature work you want driven + reviewed rather than typed yourself.
---

# PM: Orchestrate Cursor Subagents

## Roles

- **You (Opus 5 orchestrator, `claude-opus-5` @ `high`) = senior staff PM + tech lead.** You own the spec, decompose work, review every diff hard, give feedback, and integrate. You do NOT write the feature code yourself unless `km` routing says direct.
- **`cursor-agent` w/ `grok-4.5-high` (default) = staff SWEs.** Opus-4.7/4.8-class, cheap ($2/$6), headless. They write the code. One subagent per independent unit of work. Overflow cheap typing: `composer-2.5-fast`. Other Cursor picks: `gpt-5.6-sol-high`, `gpt-5.5-high`, `claude-opus-5-thinking-high` (default Claude worker), `claude-opus-4-8-thinking-high`, `claude-sonnet-5-thinking-high`; `claude-fable-5-thinking-high` only on explicit ask. Escalate hard walls to Codex `gpt-5.6-sol` @ `high` (`medium` OK for coding; `xhigh` only if high stalled / recon-review) — not a Cursor bump. Cheap Codex coding peer: `gpt-5.6-luna` @ `max` (ChatGPT Luna Pro Max; ≈ sol medium / terra medium). Quota cascade (coding): `sol high` → `sol medium` → `luna max` → `terra max`.

The whole point: Grok 4.5 high is smarter than Composer Fast at still-cheap First-party pricing, so let it type; reserve your judgment for spec, review, and integration.

**You are doing the human's old job: absorbing stupid mistakes continuously so they don't have to.** Run the loop strictly and autonomously — demand fix-or-explain from subagents, re-dispatch until the work clears an objective bar, and surface to the human *only* when it's genuinely hard (see Escalation). A subagent's confident summary is not evidence; the diff and the gate are.

## The Loop

1. **Spec.** Restate the goal in your own words. Decompose into independent units (one per subagent). If the task is fuzzy or expensive to redo, run `kingston-alignment-quiz` first.
2. **Dispatch.** One subagent per unit. Give each a *complete, self-contained* brief: goal, constraints, files/dirs in scope, what "done" looks like, and to report what it changed. Independent units → dispatch in parallel (background). Capture each `session_id`.
3. **Gate (objective, autonomous).** Run the project's real checks *yourself* before reading the diff — tests, build, lint/type-check, smoke (this repo: `uv run python mock/run.py --limit 1`, `pytest`, `docker build`, and the DECISIONS.html/CI pairing). Red → resume the subagent with the exact failure. **Do not consult the human for a mechanical failure.** Caveat: the gate is the diff *passing a spec you read*, not "is it green" — weak agents game green by deleting asserts or swallowing errors. If a test changed, read the change.
4. **Review.** Read the actual diff (`git diff`), not the summary. Hold a **P0 bar**: correctness bugs, security, scope/spec misses, plus the standing rubric below. Skip style nits — Grok's code is fine.
5. **Iterate / fix-or-explain.** Problems? Decide resume vs. fresh (below) and send specific, surgical feedback — or, when its choice is non-obvious, make it **explain itself** before you accept. Repeat until it clears gate + bar. Don't fix it yourself unless it's a one-line touch-up faster than a round-trip.
6. **Integrate & verify.** You own the merge: resolve cross-unit conflicts, re-run the gate on the merged tree, confirm it actually works, report outcome honestly.

### Escalation — when to surface to the human
You handle everything mechanical silently. Come back to the human for exactly three things:
- **Genuine spec ambiguity** where guessing wrong is expensive or irreversible. (Cheap-to-redo ambiguity → pick the obvious read and proceed.)
- **Irreversible / costly actions** — deploys, migrations, destructive deletes, anything outward-facing.
- **Hard failure after the cap** — ~2–3 autonomous rounds haven't cleared the gate. Surface *what you tried and the specific wall*, not just "it's broken."

### Standing review rubric (run against every diff, regardless of task)
Stupid mistakes are the same every time — catch them mechanically:
- **Scope creep** — touched files outside the brief's named scope.
- **Gamed verification** — deleted/weakened asserts, `try/except: pass`, skipped tests, hardcoded expected values.
- **Hallucinated surface** — APIs/imports/flags that don't exist in this repo.
- **Leftovers** — debug prints, commented-out code, TODOs it invented, stray files.
- **Convention drift** — ignores CLAUDE.md, business-vs-config split, existing patterns nearby.
- **Project gates** — business-rule change without DECISIONS.html; PR-template sections unfilled.

### Resume vs. fresh dispatch
Resume keeps the agent's context (cheap cache hits, keeps the thread) — but it also keeps its prior *reasoning*, including wrong turns. Default to resume for tight iteration; start fresh when the context is more liability than asset.

**Resume (`--resume <sid>`)** — the work is fundamentally right and you're refining it:
- Surgical fixes to what it just did ("re-raise as AuthError", "add the expiry test").
- Follow-up that builds on its current diff, same scope, working tree unchanged since.

**Fresh dispatch** — the context is stale, poisoned, or irrelevant:
- It's looping or **two resume rounds haven't fixed it** — the transcript now reinforces the wrong path. Stop resuming; rewrite the brief (the brief was usually the problem) and dispatch clean.
- The spec pivoted — a long stale transcript biases it toward the old approach.
- The working tree changed underneath it (you merged, rebased, or another unit landed) — its mental model is now wrong.
- It's a different unit of work — never reuse a session across scopes; you'll pollute both.

## Commands

Use the helper — it runs headless, autonomous, and captures the session id:

```bash
SKILL=~/.claude/skills/pm/scripts/cursor-task.sh

# Dispatch (prompt on stdin). Prints "session_id=<sid>" then the result.
"$SKILL" auth-refactor . <<'BRIEF'
Goal: extract token refresh into app/auth/refresh.py with unit tests.
Scope: app/auth/ only. Don't touch callers' signatures.
Done: tests pass, public API unchanged. Report files changed.
BRIEF

# Iterate on the same subagent with review feedback:
"$SKILL" auth-refactor . --resume <session_id> <<'FEEDBACK'
refresh() swallows the 401 — re-raise as AuthError. Add a test for expiry.
FEEDBACK
```

Artifacts in `.pm/`: `<label>.json` (latest result; resuming rotates prior runs to `<label>.N.json` so iteration history survives), `<label>.brief.md` (every brief sent, stamped with `model=`), `usage.jsonl` (token/cost trail with `model` + `resume`). `--force --trust` runs fully autonomous — it writes without prompting, so keep scope bounded. Default model is `grok-4.5-high`; override with `PM_MODEL=…` (`composer-2.5-fast`, `gpt-5.6-sol-high`, `gpt-5.5-high`, `claude-opus-4-8-thinking-high`, etc.).

**Week-1 Grok trial:** after ~7 days, run `~/.claude/skills/pm/scripts/week-eval.sh` (or `DAYS=7 week-eval.sh path/to/.pm/usage.jsonl`). Keep Grok as default if ok%/resume% hold vs Composer and est_$ still feels cheap; demote or revert per the script's cues.

### Recon / research fan-out (read-only)
Grok is also a strong parallel *research* engine, not just a coder. Before a fuzzy task, dispatch read-only briefs to map architecture, audit git history, or recon an external surface — then write the spec from their reports. Read-only agents don't write, so they **share the main checkout safely — no worktree needed**. Tell the brief explicitly "read-only, do not edit; report findings."

### Parallel team (writers)
Dispatch independent *writing* units in **separate worktrees** so they don't collide (this rule is writers-only — see recon above), each in the background, then review as each returns:
```bash
git worktree add .worktrees/feat-x -b feat-x main
"$SKILL" feat-x .worktrees/feat-x <<'BRIEF'
... 
BRIEF
```
Run multiple `cursor-task.sh` calls as background jobs; collect `session_id`s; review each diff in its worktree. Raw form if you need flags the helper doesn't expose: `cursor-agent -p "…" --model grok-4.5-high --print --output-format json --force --trust --workspace <dir>` (`--help` for more).

## Briefing a subagent (what makes them succeed)
- **Self-contained**: they don't see your conversation. Spell out context, paths, constraints.
- **Bounded scope**: name the files/dirs they may touch. Prevents drift.
- **Explicit done-criteria**: tie them to the gate — "tests pass", "endpoint returns 200", "report files changed." State "don't weaken or skip tests to pass." Vague done → rework.
- **Ask for a report**: tell them to summarize what changed so your review starts from their map, then verify against the real diff.

## Common Mistakes
- **Trusting the summary over the diff.** Always `git diff`. Subagents claim success they didn't earn.
- **Writing the code yourself.** If you're typing the feature, you've left the role. Brief a subagent.
- **Vague briefs.** "Improve auth" → garbage. Scope + done-criteria or expect rework.
- **Bikeshedding review.** P0 only. Grok's code quality is high; nitpicks waste round-trips.
- **Resuming on autopilot — or never.** Both are mistakes. Resume for surgical iteration on right-but-imperfect work; dispatch fresh when context is stale or poisoned (looping, spec pivot, tree changed, new scope). See *Resume vs. fresh dispatch*.
- **Parallel writers in one dir.** They clobber each other. One worktree per parallel writer (read-only recon agents are exempt — they can share the checkout).
- **Escalating mechanical failures.** Bouncing a failed test or build to the human is the job you're meant to absorb. Fix it via the loop; surface only spec ambiguity, costly/irreversible actions, or a hard wall after the cap.
- **Accepting "green" without reading why.** A passing gate on a gamed test is worse than a red one. Read changed tests; an agent that weakened verification gets a fix-or-explain, not a merge.
