#!/usr/bin/env bash
# sync-dsh-skills.sh — ai-squad skills + agents → DeepSeek Harness (dsh)
#
# Mirrors the Claude global source of truth into the skill root the
# DeepSeek Harness scans (~/.dsh/skills):
#
#   ~/.claude/skills/<name>/SKILL.md  → symlink  ~/.dsh/skills/<name>
#   ~/.claude/agents/<name>.md        → generated ~/.dsh/skills/<name>/SKILL.md
#
# Why: dsh does NOT read ~/.claude/. It discovers skills from ~/.dsh/skills
# and ~/.agents/skills, top level only, as <name>/SKILL.md with YAML
# frontmatter (name + description). That is the Claude skill format, so skills
# need no conversion — only a symlink per skill (a symlinked root would work
# too, but then generated agents would land inside ~/.claude/skills, which is a
# git repo). dsh has no file-based agent definitions: its native analogue is an
# agent preset (a directory with agent.cordis.yml + persona), too heavy for 13
# roles. So, as opencode and reasonix do, each agent becomes a skill the model
# loads to assume the role, delegating through the `subagent` tool when the
# task needs an isolated context. The `subagent` tool ships enabled in the
# `standard` preset.
#
# Conversion rules (Claude agent → dsh skill):
#   - frontmatter: keep name + description; drop model / effort / version
#     (dsh routes every request to the model selected in the UI)
#   - a one-line note at the top of the body: assume the role, or delegate
#   - body: preserved byte-for-byte after the note
#
# Usage: bash scripts/sync-dsh-skills.sh
#
# Idempotent: removes only what it created (symlinks and dirs carrying a
# .from-claude-agent marker), so skills authored directly in ~/.dsh/skills
# survive. dsh watches the root — no restart needed.

set -euo pipefail
export LC_ALL=C
export LANG=C

SRC_SKILLS="${HOME}/.claude/skills"
SRC_AGENTS="${HOME}/.claude/agents"
DST_DIR="${DSH_HOME:-${HOME}/.dsh}/skills"
MARKER=".from-claude-agent"
NOTE='> Este é um **agent** do Claude Code espelhado como skill. Assuma o papel abaixo. Se a tarefa pedir isolamento de contexto, delegue via tool `subagent` passando estas instruções.'

log() { printf '[sync-dsh-skills] %s\n' "$*"; }
die() { printf '[sync-dsh-skills] ERROR: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die "unknown argument: $1"
[[ -d "$SRC_SKILLS" ]] || die "source dir not found: $SRC_SKILLS"
[[ -d "$SRC_AGENTS" ]] || die "source dir not found: $SRC_AGENTS"
mkdir -p "$DST_DIR"

# ---------- clean previous run (only what we own) ----------
for entry in "$DST_DIR"/*; do
  [[ -e "$entry" || -L "$entry" ]] || continue
  if [[ -L "$entry" || -f "$entry/$MARKER" ]]; then rm -rf "$entry"; fi
done

# ---------- skills: one symlink each ----------
skills=0
for dir in "$SRC_SKILLS"/*/; do
  name="$(basename "$dir")"
  [[ -f "$dir/SKILL.md" ]] || continue
  ln -s "${dir%/}" "$DST_DIR/$name"
  skills=$((skills + 1))
done

# ---------- agents: generated SKILL.md ----------
agents=0
for src in "$SRC_AGENTS"/*.md; do
  name="$(basename "$src" .md)"
  dst="$DST_DIR/$name"
  if [[ -e "$dst" ]]; then
    log "skip $name: a skill with the same name already exists"
    continue
  fi
  mkdir -p "$dst"
  : > "$dst/$MARKER"

  # Frontmatter keeps only name/description; the body follows a role note.
  awk -v note="$NOTE" '
    BEGIN { fm=0; body=0 }
    body { print; next }
    NR==1 && $0=="---" { fm=1; print "---"; next }
    fm && $0=="---" { fm=0; body=1; print "---"; print ""; print note; print ""; next }
    fm { if ($0 ~ /^(name|description):/) print; next }
    { print }
  ' "$src" > "$dst/SKILL.md"

  agents=$((agents + 1))
  log "converted $name → $dst/SKILL.md"
done

log "done: $skills skills linked, $agents agents converted → $DST_DIR"
