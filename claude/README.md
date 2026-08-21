# Claude Code

Config for `~/.claude`. Credentials (`~/.claude/.credentials.json`), history, sessions, and
`settings.local.json` are never copied here.

## settings.json

Model/effort defaults, env flags, enabled plugins, status line, and the hook wiring below.

```sh
cp claude/settings.json ~/.claude/settings.json
```

Referenced but **not** in this repo: `~/.claude/ccnotify/ccnotify.py` (installed separately) and
`~/.cursor/statusline.sh`. Drop those hook entries if you don't use them. Machine- and
project-specific overrides go in `settings.local.json`, which `.gitignore_global` ignores.

## hooks/

```sh
cp -R claude/hooks ~/.claude/hooks && chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/km/*.sh
```

- `block-dangerous.sh` — PreToolUse(Bash): refuses recursive force-deletes, hard resets, force
  pushes, SQL drops, and curl-pipe-to-shell.
- `git-branch-prefetch.sh` — PreToolUse(Bash): fetches origin before any branch-creating command
  so a stale-fetch guard doesn't block it.
- `km/` — "kingston mode": gates prod commands and `gh pr create` behind an explicit go. Needs the
  `km` skill at `~/.cursor/skills/km/SKILL.md`.

## statusline.sh

Two-line status line for Claude Code.

```
@agent-name │ feat/my-branch │ Opus 5 │ ███░░░░░░░ 32%/200K
cost:41¢ │ +210-63(147) │ 4m12s
```

Line 1: optional `@agent` / session name, branch (or `wt:<name>` in a worktree, or cwd if not a repo), model, context bar
(green <50%, yellow ≥50%, red ≥80%). Line 2: session cost, lines added/removed/net, duration.

Requires `jq` and `bc`.

### Install

```sh
cp claude/statusline.sh ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
```

Then in `~/.claude/settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" }
}
```
