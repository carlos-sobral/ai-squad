#!/usr/bin/env python3
"""PreToolUse(Bash) guard for the ai-squad / global SDD harness.

Turns two soft CLAUDE.md "iron laws" into hard, deterministic confirmations:

  1. No `git push --force` (incl. -f / --force-with-lease) without human confirmation.
  2. No broad `git add`/`git commit -a` inside the global source-of-truth dirs
     (~/.claude/agents, ~/.claude/skills), which once dragged unrelated drift
     into a mislabeled commit (incident ba7fda4).

Mechanism: emit a PreToolUse permissionDecision of "ask", which forces a
confirmation prompt even under `defaultMode: dontAsk`. The hook never hard-blocks
legitimate work — it only requires an explicit human yes. Fails OPEN on any
parsing error so a hook bug can never trap the shell.
"""
import sys
import os
import re
import json


def ask(reason: str) -> None:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # fail-open

    if data.get("tool_name") != "Bash":
        sys.exit(0)

    cmd = (data.get("tool_input") or {}).get("command", "") or ""
    cwd = data.get("cwd", "") or ""

    # 1) Force push -> require confirmation.
    if re.search(r"\bgit\s+push\b", cmd) and re.search(
        r"(?:^|\s)(?:-f\b|--force(?:-with-lease)?\b)", cmd
    ):
        ask(
            "Guardrail ai-squad: force-push detectado (`git push --force/-f`). "
            "A iron-law global exige confirmacao humana antes de reescrever "
            "historico remoto. Confirme so se voce revisou o impacto."
        )

    # 2) Broad git add / commit -a inside the global source-of-truth dirs.
    home = os.path.expanduser("~")
    global_dirs = (
        os.path.join(home, ".claude", "agents"),
        os.path.join(home, ".claude", "skills"),
    )
    abs_cwd = os.path.abspath(cwd) if cwd else ""
    in_global = any(abs_cwd == d or abs_cwd.startswith(d + os.sep) for d in global_dirs)

    if in_global:
        broad_add = re.search(
            r"\bgit\s+add\b[^|&;]*?(?:-A\b|--all\b|-u\b|(?:^|\s)\.(?:\s|$))", cmd
        )
        broad_commit = re.search(r"\bgit\s+commit\b", cmd) and re.search(
            r"(?:^|\s)-[A-Za-z]*a[A-Za-z]*\b|--all\b", cmd
        )
        if broad_add or broad_commit:
            ask(
                "Guardrail ai-squad: `git add`/`commit` amplo dentro de "
                "~/.claude/agents|skills (fonte da verdade). Risco de arrastar "
                "drift nao relacionada para um commit de escopo enganoso "
                "(incidente ba7fda4). Confirme so apos `git status` + add de "
                "arquivos especificos."
            )

    sys.exit(0)


if __name__ == "__main__":
    main()
