#!/usr/bin/env bash
# sync-reasonix-skills.sh — ai-squad agents → Reasonix
#
# Converts the 13 ai-squad agents from the Claude global source of truth
# (~/.claude/agents/*.md) into Reasonix subagent skills
# (~/.reasonix/skills/<name>/SKILL.md).
#
# Why: Reasonix reads ~/.claude/skills/*/SKILL.md natively (Claude-compatible
# skill format), so skills need no conversion. It does NOT read
# ~/.claude/agents/. Its analogue for an agent is a skill with `runAs: subagent`
# in the frontmatter: the model invokes it and Reasonix runs the body in an
# isolated subagent, with the model from `subagent_model` in config.toml.
#
# Conversion rules (Claude agent → Reasonix skill):
#   - frontmatter: keep name + description; drop model / effort / version
#     (Reasonix picks the model from its own config); add `runAs: subagent`
#   - body: preserved byte-for-byte
#
# Usage: bash scripts/sync-reasonix-skills.sh
#
# Idempotent: regenerates every directory named after a global agent (they are
# copies of that agent, however old) and dirs carrying a .from-claude-agent
# marker. Any other directory in ~/.reasonix/skills — a skill authored by hand
# or copied from a project's .claude/agents — is left alone.

set -euo pipefail
export LC_ALL=C
export LANG=C

SRC_DIR="${HOME}/.claude/agents"
DST_DIR="${REASONIX_HOME:-${HOME}/.reasonix}/skills"
MARKER=".from-claude-agent"

log() { printf '[sync-reasonix-skills] %s\n' "$*"; }
die() { printf '[sync-reasonix-skills] ERROR: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die "unknown argument: $1"
[[ -d "$SRC_DIR" ]] || die "source dir not found: $SRC_DIR"
mkdir -p "$DST_DIR"

# ---------- clean previous run (only what we own) ----------
for entry in "$DST_DIR"/*/; do
  [[ -d "$entry" ]] || continue
  name="$(basename "$entry")"
  if [[ -f "$entry/$MARKER" || -f "$SRC_DIR/$name.md" ]]; then rm -rf "${entry%/}"; fi
done

converted=0
for src in "$SRC_DIR"/*.md; do
  name="$(basename "$src" .md)"
  dst="$DST_DIR/$name"
  mkdir -p "$dst"
  : > "$dst/$MARKER"

  # Frontmatter keeps only name/description and gains runAs; body is verbatim.
  awk '
    BEGIN { fm=0; body=0 }
    body { print; next }
    NR==1 && $0=="---" { fm=1; print "---"; next }
    fm && $0=="---" { fm=0; body=1; print "runAs: subagent"; print "---"; next }
    fm { if ($0 ~ /^(name|description):/) print; next }
    { print }
  ' "$src" > "$dst/SKILL.md"

  converted=$((converted + 1))
  log "converted $name → $dst/SKILL.md"
done

log "done: $converted agents synced to $DST_DIR"
