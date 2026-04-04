#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "Installing ai-squad skills..."
echo ""

mkdir -p "$SKILLS_DIR"

count=0
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  dest="$SKILLS_DIR/$skill_name"

  if [ -d "$dest" ]; then
    echo "  updating  $skill_name"
  else
    echo "  installing $skill_name"
  fi

  cp -r "$skill_dir" "$SKILLS_DIR/"
  count=$((count + 1))
done

echo ""
echo "Done! $count skills installed to $SKILLS_DIR"
echo ""
echo "Next steps:"
echo "  1. Copy templates/CLAUDE.md into your project root"
echo "  2. Open Claude Code inside your project folder"
echo "  3. Type: /sdlc-orchestrator"
echo ""
