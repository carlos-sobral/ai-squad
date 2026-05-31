#!/usr/bin/env python3
"""Stop guard for the ai-squad / global SDD harness.

Operationalizes the CLAUDE.md "iron law": no success claim without fresh
verification evidence in the current message.

Trigger (all three must hold for the turn that is about to end):
  - code was edited (Edit/Write/MultiEdit/NotebookEdit on a NON-doc file), AND
  - NO Bash command ran in the turn (proxy for "ran nothing to verify"), AND
  - the final assistant text contains a success claim.

When triggered, blocks the Stop and feeds a reason back to the model, forcing it
to verify (or retract the claim) before finishing. Doc-only edits (.md/.txt/...)
never trigger. Honors stop_hook_active to avoid loops. Fails OPEN on any error —
a buggy hook must never trap the user in an un-stoppable turn.
"""
import sys
import os
import re
import json

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
DOC_EXT = {".md", ".markdown", ".mdx", ".txt", ".rst"}
SUCCESS_RE = re.compile(
    r"\b(done|fixed|passing|complete[d]?|works now|ready to merge|"
    r"all (?:tests|checks) pass\w*|pronto|funcionando|funciona|corrigido|"
    r"resolvido|tudo passando|passou|conclu[ií]do)\b|✅",
    re.IGNORECASE,
)


def allow() -> None:
    sys.exit(0)


def block(reason: str) -> None:
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)


def is_genuine_user(entry: dict) -> bool:
    """A real user turn — not a tool_result echoed back as a user message."""
    if entry.get("type") != "user":
        return False
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        return not any(
            isinstance(b, dict) and b.get("type") == "tool_result" for b in content
        )
    return False


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        allow()

    if data.get("stop_hook_active"):
        allow()

    tp = data.get("transcript_path")
    if not tp or not os.path.exists(tp):
        allow()

    try:
        entries = []
        with open(tp) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except Exception:
                    continue
    except Exception:
        allow()

    last_user = -1
    for i, e in enumerate(entries):
        if is_genuine_user(e):
            last_user = i
    turn = entries[last_user + 1:] if last_user >= 0 else entries

    did_edit_code = False
    did_bash = False
    last_text = ""
    for e in turn:
        if e.get("type") != "assistant":
            continue
        content = (e.get("message") or {}).get("content")
        if isinstance(content, str):
            last_text = content
            continue
        if not isinstance(content, list):
            continue
        for b in content:
            if not isinstance(b, dict):
                continue
            if b.get("type") == "text":
                last_text = b.get("text", "") or last_text
            elif b.get("type") == "tool_use":
                name = b.get("name", "")
                if name == "Bash":
                    did_bash = True
                elif name in EDIT_TOOLS:
                    fp = (b.get("input") or {}).get("file_path", "") or ""
                    if os.path.splitext(fp)[1].lower() not in DOC_EXT:
                        did_edit_code = True

    if did_edit_code and not did_bash and SUCCESS_RE.search(last_text or ""):
        block(
            "Iron-law de verificacao (CLAUDE.md global): voce editou codigo e "
            "declarou sucesso sem rodar nenhum comando de verificacao nesta "
            "resposta. Rode o que prova o claim (teste/build/lint/repro) e cite "
            "a evidencia (ex.: '34/34 pass, exit 0'), ou remova a afirmacao de "
            "sucesso."
        )

    allow()


if __name__ == "__main__":
    main()
