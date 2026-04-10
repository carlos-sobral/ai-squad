#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Installing ai-squad skills..."
echo ""

mkdir -p "$SKILLS_DIR"

skill_count=0
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  dest="$SKILLS_DIR/$skill_name"

  if [ -d "$dest" ]; then
    echo "  updating  $skill_name"
  else
    echo "  installing $skill_name"
  fi

  cp -r "$skill_dir" "$SKILLS_DIR/"
  skill_count=$((skill_count + 1))
done

echo ""
echo "Installing ai-squad agents..."
echo ""

mkdir -p "$AGENTS_DIR"

agent_count=0
for agent_file in "$SCRIPT_DIR/agents"/*.md; do
  [ -f "$agent_file" ] || continue
  agent_name=$(basename "$agent_file")
  dest="$AGENTS_DIR/$agent_name"

  if [ -f "$dest" ]; then
    echo "  updating  $agent_name"
  else
    echo "  installing $agent_name"
  fi

  cp "$agent_file" "$AGENTS_DIR/"
  agent_count=$((agent_count + 1))
done

echo ""
echo "Done! $skill_count skills + $agent_count agents installed"
echo ""
echo "Next steps:"
echo "  1. Copy templates/CLAUDE.md into your project root"
echo "  2. Open Claude Code inside your project folder"
echo "  3. Type: /sdlc-orchestrator"
echo ""
