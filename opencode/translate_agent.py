#!/usr/bin/env python3
"""Translate one ai-squad agent (Claude Code format) into an OpenCode v2 agent.

Single source of the translation rules — used by install.sh and scripts/sync-opencode-agents.sh.

Usage: translate_agent.py <src.md> <dest.md> [--model <provider/model#variant>]

Rules:
  - frontmatter: model -> by nature of work (MODEL_BY_CLAUDE + MODEL_OVERRIDES, or --model); name/version/effort dropped; mode: subagent added
  - tool names: mcp__<srv>__<tool> -> <srv>_<tool>; `WebSearch`/`WebFetch`/`Skill` tool -> lowercase
  - appends opencode/runtime-notes.md (all agents) + opencode/adaptations/<agent>.md (if present)
  - CLAUDE.md -> AGENTS.md in the whole file (OpenCode v2 does not read CLAUDE.md)
"""

import argparse
import pathlib
import re

OC_DIR = pathlib.Path(__file__).resolve().parent

# Modelo por natureza do trabalho (decisão de 2026-11-21): planejamento, ideação,
# pesquisa e julgamento -> Opus via provider claude-agent; código -> GLM do gateway
# Sensedia. Deriva do modelo Claude do agente canônico, com exceções explícitas.
# O alvo do GLM é #high, mas a variante vem da convenção da frota (plugin
# sensedia-opencode-v2.ts sobrescreve o provider local) e hoje só existe low/medium.
MODEL_BY_CLAUDE = {
    "opus": "claude-agent/opus#high",
    "sonnet": "glm/glm#medium",
    "haiku": "glm/glm#medium",
}
MODEL_OVERRIDES = {
    "security-engineer": "glm/glm#medium",  # mexe com código; decidido pelo Carlos em 2026-11-21
}
DEFAULT_MODEL = "glm/glm#medium"


def resolve_model(stem: str, fm: str, forced: str | None) -> str:
    if forced:
        return forced
    if stem in MODEL_OVERRIDES:
        return MODEL_OVERRIDES[stem]
    m = re.search(r"^model:\s*(\S+)", fm, flags=re.M)
    return MODEL_BY_CLAUDE.get(m.group(1) if m else "", DEFAULT_MODEL)


def translate(src: pathlib.Path, model: str | None) -> str:
    text = src.read_text(encoding="utf-8")
    _, fm, body = text.split("---", 2)

    model = resolve_model(src.stem, fm, model)
    fm = re.sub(r"^model: .*$", f"model: {model}", fm, flags=re.M)
    # `name` é campo V1 no OpenCode (o ID vem do nome do arquivo); o Claude Code exige.
    fm = re.sub(r"^(effort|version|name): .*\n", "", fm, flags=re.M)
    if not re.search(r"^mode:", fm, flags=re.M):
        fm = fm.rstrip("\n") + "\nmode: subagent\n"

    body = re.sub(r"mcp__([A-Za-z0-9-]+)__(\*|[A-Za-z0-9_]*)", r"\1_\2", body)
    body = body.replace("`WebSearch`", "`websearch`").replace(
        "`WebFetch`", "`webfetch`"
    )
    body = body.replace("`Skill` tool", "`skill` tool")
    body = body.replace(
        'via the Agent tool (`subagent_type: "general-purpose"`)',
        "via the `subagent` tool with the built-in `general` agent",
    )

    body = (
        body.rstrip("\n")
        + "\n"
        + (OC_DIR / "runtime-notes.md").read_text(encoding="utf-8")
    )
    adapt = OC_DIR / "adaptations" / f"{src.stem}.md"
    if adapt.exists():
        body = body.rstrip("\n") + "\n" + adapt.read_text(encoding="utf-8")

    out = ("---" + fm + "---" + body).replace("CLAUDE.md", "AGENTS.md")

    # Detector — the frontmatter MUST be closed by a second '---' before the body
    # starts. The split above consumes the source's closing fence, so it has to be
    # re-emitted here. Without it the whole file parses as one unterminated
    # frontmatter and OpenCode silently drops the agent ("Unknown agent"). Observed
    # 2026-10-25: this bug shipped twice (old install.sh inline python and the first
    # version of this translator) and all 13 agents went unregistered on the machine.
    fence = next(
        (i for i, l in enumerate(out.splitlines()) if l == "---" and i > 0), None
    )
    if fence is None or fence > 12:
        raise SystemExit(
            f"translate_agent: {src.name}: generated frontmatter is not terminated "
            f"within the first 12 lines (closing fence at line {fence})"
        )
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dest")
    ap.add_argument(
        "--model",
        default=None,
        help="força um modelo para todos os agentes; sem ele vale MODEL_BY_CLAUDE/MODEL_OVERRIDES",
    )
    a = ap.parse_args()
    pathlib.Path(a.dest).write_text(
        translate(pathlib.Path(a.src), a.model), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
