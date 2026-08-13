# Claude Code

## statusline.sh

Two-line status line for Claude Code.

```
feat/my-branch │ Opus 5 │ ███░░░░░░░ 32%/200K
cost:41¢ │ +210-63(147) │ 4m12s
```

Line 1: branch (or `wt:<name>` in a worktree, or cwd if not a repo), model, context bar
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
