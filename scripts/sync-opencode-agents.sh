#!/usr/bin/env bash
# sync-opencode-agents.sh — ai-squad agents → opencode
#
# Converts the 13 ai-squad agents from the Claude global source of truth
# (~/.claude/agents/*.md) into opencode-compatible agents
# (~/.config/opencode/agents/*.md).
#
# Why: opencode does NOT read ~/.claude/agents/. It loads agents only from
# ~/.config/opencode/agents/*.md (global) or .opencode/agents/ (project),
# in markdown-with-YAML-frontmatter format. Skills, by contrast, ARE shared —
# opencode reads ~/.claude/skills/*/SKILL.md natively, so no conversion is
# needed for skills.
#
# Conversion rules live in ONE place: opencode/translate_agent.py (also used by install.sh).
# Model defaults to glm/glm; override with --model or OPCODE_MODEL.
#
# Usage: bash scripts/sync-opencode-agents.sh [--model glm/glm]
#
# Idempotent: safe to re-run; regenerates all agents from the global source.

set -euo pipefail
export LC_ALL=C
export LANG=C

MODEL="${OPCODE_MODEL:-glm/glm}"
TRANSLATOR="$(cd "$(dirname "$0")/.." && pwd)/opencode/translate_agent.py"
SRC_DIR="${HOME}/.claude/agents"
DST_DIR="${HOME}/.config/opencode/agents"

# ---------- helpers ----------
log() { printf '[sync-opencode-agents] %s\n' "$*"; }
die() { printf '[sync-opencode-agents] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------- arg parsing ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -d "$SRC_DIR" ]] || die "source dir not found: $SRC_DIR"
mkdir -p "$DST_DIR"

converted=0
for src in "$SRC_DIR"/*.md; do
  name="$(basename "$src" .md)"
  dst="$DST_DIR/$name.md"

  python3 "$TRANSLATOR" "$src" "$dst" --model "$MODEL"

  converted=$((converted + 1))
  log "converted $name → $dst"
done

log "done: $converted agents synced to $DST_DIR (model=$MODEL)"
