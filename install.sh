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
echo "Installing ai-squad enforcement hooks..."
echo ""

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

hook_count=0
if [ -d "$SCRIPT_DIR/scripts/hooks" ]; then
  mkdir -p "$HOOKS_DIR"
  for hook_file in "$SCRIPT_DIR/scripts/hooks"/*.py; do
    [ -f "$hook_file" ] || continue
    hook_name=$(basename "$hook_file")
    if [ -f "$HOOKS_DIR/$hook_name" ]; then
      echo "  updating  $hook_name"
    else
      echo "  installing $hook_name"
    fi
    cp "$hook_file" "$HOOKS_DIR/"
    hook_count=$((hook_count + 1))
  done

  # Merge hook wiring into settings.json idempotently — never clobber existing
  # config, never duplicate on re-run. Matches entries by command substring.
  if command -v python3 >/dev/null 2>&1; then
    SETTINGS_FILE="$SETTINGS_FILE" python3 - <<'PYEOF'
import json, os, sys

path = os.environ["SETTINGS_FILE"]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except Exception as e:
    print(f"  ! settings.json invalido, hooks NAO conectados: {e}")
    sys.exit(0)  # fail-open: never break install over a malformed settings file

hooks = data.setdefault("hooks", {})

def already_wired(event, needle):
    for group in hooks.get(event, []):
        for h in group.get("hooks", []):
            if needle in h.get("command", ""):
                return True
    return False

changed = False

if not already_wired("PreToolUse", "guard-bash.py"):
    hooks.setdefault("PreToolUse", []).append({
        "matcher": "Bash",
        "hooks": [{"type": "command",
                   "command": 'python3 "$HOME/.claude/hooks/guard-bash.py"'}],
    })
    changed = True

if not already_wired("Stop", "guard-stop.py"):
    hooks.setdefault("Stop", []).append({
        "hooks": [{"type": "command",
                   "command": 'python3 "$HOME/.claude/hooks/guard-stop.py"'}],
    })
    changed = True

if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("  wired     guard-bash + guard-stop into settings.json")
else:
    print("  ok        hooks already wired in settings.json")
PYEOF
  else
    echo "  ! python3 nao encontrado — hooks copiados mas NAO conectados."
    echo "    Adicione manualmente em ~/.claude/settings.json (ver README)."
  fi
fi

echo ""
echo "Done! $skill_count skills + $agent_count agents + $hook_count hooks installed"
echo ""
echo "Next steps:"
echo "  1. Copy templates/CLAUDE.md into your project root"
echo "  2. Open Claude Code inside your project folder"
echo "  3. Type: /sdlc-orchestrator"
echo ""
