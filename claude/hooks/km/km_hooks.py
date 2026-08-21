#!/usr/bin/env python3
"""Kingston mode (km) enforcement hooks for Claude Code."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

STATE_ROOT = Path.home() / ".claude" / "km-state"
_SKILL_CANDIDATES = (
    Path.home() / ".claude" / "skills" / "km" / "SKILL.md",
    Path.home() / ".cursor" / "skills" / "km" / "SKILL.md",
)
SKILL_PATH = next((p for p in _SKILL_CANDIDATES if p.is_file()), _SKILL_CANDIDATES[0])

KM_TRIGGERS = re.compile(r"/(?:km|kingston-mode)\b|kingston\s+mode", re.I)
PROD_GO_TRIGGERS = re.compile(
    r"^(?:go|yes|yep|yup|ship it|do it|approved?|lgtm)\.?$|"
    r"(?:go ahead|hotfix prod|deploy prod|flip traffic|update prod|push to prod)",
    re.I,
)
PROD_CMD = re.compile(
    r"gcloud run (?:services update(?:-traffic)?|deploy(?!.*--no-traffic)|jobs execute)",
    re.I,
)
PR_CREATE = re.compile(r"gh pr create\b", re.I)


def state_dir(session_id: str) -> Path:
    return STATE_ROOT / session_id


def is_active(session_id: str) -> bool:
    return (state_dir(session_id) / "active").is_file()


def set_active(session_id: str) -> None:
    d = state_dir(session_id)
    d.mkdir(parents=True, exist_ok=True)
    (d / "active").write_text("1")
    for name in ("prod-go", "thermo-done"):
        path = d / name
        if path.exists():
            path.unlink()


def set_prod_go(session_id: str) -> None:
    state_dir(session_id).mkdir(parents=True, exist_ok=True)
    (state_dir(session_id) / "prod-go").touch()


def set_thermo_done(session_id: str) -> None:
    state_dir(session_id).mkdir(parents=True, exist_ok=True)
    (state_dir(session_id) / "thermo-done").touch()


def deny(message: str) -> None:
    payload = {
        "hookSpecificOutput": {
            "permissionDecision": "deny",
            "permissionDecisionReason": message,
        },
        "systemMessage": message,
    }
    print(json.dumps(payload), file=sys.stderr)
    sys.exit(2)


def emit_context(text: str, event: str) -> None:
    payload = {
        "additional_context": text,
        "hookSpecificOutput": {
            "hookEventName": event,
            "additionalContext": text,
        },
    }
    print(json.dumps(payload))


def user_prompt_submit(data: dict) -> None:
    session_id = data.get("session_id", "")
    prompt = data.get("prompt", "") or ""

    if not session_id or prompt.strip().startswith("<"):
        return

    activated = bool(KM_TRIGGERS.search(prompt))
    if activated:
        set_active(session_id)

    prod_go = bool(is_active(session_id) and PROD_GO_TRIGGERS.search(prompt.strip()))
    if prod_go:
        set_prod_go(session_id)

    if activated:
        if not SKILL_PATH.is_file():
            emit_context(
                f"<EXTREMELY_IMPORTANT>km skill missing at {SKILL_PATH}</EXTREMELY_IMPORTANT>",
                "UserPromptSubmit",
            )
            return
        skill = SKILL_PATH.read_text()
        ctx = (
            "<EXTREMELY_IMPORTANT>\n"
            "Kingston mode is ACTIVE. Hooks enforce:\n"
            "- prod deploy/mutation blocked until Kingston replies go\n"
            "- gh pr create blocked until thermo-nuclear-code-quality-review runs\n"
            "- Task subagents blocked — use codex exec/review or pm/cursor-agent\n\n"
            f"{skill}\n"
            "</EXTREMELY_IMPORTANT>"
        )
        emit_context(ctx, "UserPromptSubmit")
        return

    if prod_go:
        emit_context(
            "<EXTREMELY_IMPORTANT>\n"
            "km: prod-go granted. Retry the blocked prod command.\n"
            "</EXTREMELY_IMPORTANT>",
            "UserPromptSubmit",
        )


def pre_tool_use(data: dict) -> None:
    session_id = data.get("session_id", "")
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}

    if not session_id or not is_active(session_id):
        return

    if tool_name == "Task":
        deny(
            "km: Task subagents are blocked while Kingston mode is active. "
            "Use `codex exec` / `codex review` for recon/review/hard units, "
            "or `pm` + cursor-agent for delegable implementation."
        )

    if tool_name != "Bash":
        return

    cmd = tool_input.get("command", "") or ""
    sd = state_dir(session_id)

    if PROD_CMD.search(cmd) and not (sd / "prod-go").is_file():
        deny(
            "km: prod deploy/mutation blocked. Surface a one-line 'what this does' "
            "to Kingston and wait for explicit go (reply 'go'). Do not work around this hook."
        )

    if PR_CREATE.search(cmd) and not (sd / "thermo-done").is_file():
        deny(
            "km: gh pr create blocked until thermo-nuclear-code-quality-review runs. "
            "Invoke Skill thermo-nuclear-code-quality-review, fix must-dos, then retry."
        )


def post_tool_use(data: dict) -> None:
    session_id = data.get("session_id", "")
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}

    if not session_id or not is_active(session_id) or tool_name != "Skill":
        return

    skill = (tool_input.get("skill") or "").lower()
    if "thermo" in skill:
        set_thermo_done(session_id)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(0)

    event = sys.argv[1]
    raw = sys.stdin.read().strip()
    if not raw:
        sys.exit(0)

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        sys.exit(0)

    if event == "user-prompt-submit":
        user_prompt_submit(data)
    elif event == "pre-tool-use":
        pre_tool_use(data)
    elif event == "post-tool-use":
        post_tool_use(data)


if __name__ == "__main__":
    main()
