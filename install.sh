#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --version: echo the snapshot this repo represents (last commit + date), then exit.
# Lets an adopter know exactly which ai-squad snapshot a project is running.
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "-v" ]; then
  if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    sha="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
    date="$(git -C "$SCRIPT_DIR" log -1 --format=%cs 2>/dev/null || echo "unknown")"
    echo "ai-squad snapshot: $sha ($date)"
  else
    echo "ai-squad snapshot: unknown (not a git checkout)"
  fi
  exit 0
fi

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

  # sem a barra final: no cp do BSD/macOS, "dir/" copia o CONTEÚDO para a raiz de $SKILLS_DIR
  cp -R "${skill_dir%/}" "$SKILLS_DIR/"
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
echo "Installing ai-squad agents for OpenCode v2 (translated)..."
echo ""

# Gera ~/.config/opencode/agents/*.md a partir do MESMO agents/ canônico.
# Tradução (plano second-brain-agnostico, D3/Fase 3):
#   - model: <claude-model>  -> model: glm/glm (gateway Sensedia)
#   - mode: subagent entra (se ausente)
#   - effort:/version: saem (o OpenCode ignora campos extra; sem eles a cópia bate byte a byte)
#   - CLAUDE.md -> AGENTS.md no arquivo inteiro (o OpenCode v2 não lê CLAUDE.md)
OPENCODE_AGENTS_DIR="$HOME/.config/opencode/agents"

oc_agent_count=0
if mkdir -p "$OPENCODE_AGENTS_DIR" 2>/dev/null && command -v python3 >/dev/null 2>&1; then
  for agent_file in "$SCRIPT_DIR/agents"/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file")
    dest="$OPENCODE_AGENTS_DIR/$agent_name"

    if [ -f "$dest" ]; then
      echo "  updating  $agent_name"
    else
      echo "  installing $agent_name"
    fi

    AGENT_SRC="$agent_file" AGENT_DEST="$dest" python3 - <<'PYEOF'
import os, re, pathlib

src = pathlib.Path(os.environ["AGENT_SRC"]).read_text(encoding="utf-8")
parts = src.split("---", 2)
fm, body = parts[1], parts[2]

fm = re.sub(r"^model: .*$", "model: glm/glm", fm, flags=re.M)
fm = re.sub(r"^(effort|version): .*\n", "", fm, flags=re.M)
if not re.search(r"^mode:", fm, flags=re.M):
    fm = fm.rstrip("\n") + "\nmode: subagent\n"

out = (fm + body).replace("CLAUDE.md", "AGENTS.md")  # troca no arquivo inteiro (description incluida)

pathlib.Path(os.environ["AGENT_DEST"]).write_text(f"---{out}", encoding="utf-8")
PYEOF
    oc_agent_count=$((oc_agent_count + 1))
  done
else
  echo "  ! pulado (sem ~/.config/opencode ou sem python3)"
fi

echo ""
echo "Installing OpenCode global AGENTS.md (ai-squad core)..."
echo ""

# Deploy do núcleo agnóstico do ai-squad no OpenCode (decisão D3).
# Fonte canônica: opencode/AGENTS.md neste repo — edite lá, NÃO no destino.
OPENCODE_GLOBAL="$HOME/.config/opencode/AGENTS.md"
if [ -f "$SCRIPT_DIR/opencode/AGENTS.md" ] && mkdir -p "$HOME/.config/opencode" 2>/dev/null; then
  if [ -f "$OPENCODE_GLOBAL" ]; then
    echo "  updating  AGENTS.md (global OpenCode)"
  else
    echo "  installing AGENTS.md (global OpenCode)"
  fi
  cp "$SCRIPT_DIR/opencode/AGENTS.md" "$OPENCODE_GLOBAL"
fi

echo ""
echo "Installing ai-squad maintenance scripts..."
echo ""

SCRIPTS_DIR="$HOME/.claude/scripts"
script_count=0
if [ -d "$SCRIPT_DIR/scripts/maintenance" ]; then
  mkdir -p "$SCRIPTS_DIR"
  for maint_file in "$SCRIPT_DIR/scripts/maintenance"/*.sh; do
    [ -f "$maint_file" ] || continue
    maint_name=$(basename "$maint_file")
    if [ -f "$SCRIPTS_DIR/$maint_name" ]; then
      echo "  updating  $maint_name"
    else
      echo "  installing $maint_name"
    fi
    cp "$maint_file" "$SCRIPTS_DIR/"
    chmod +x "$SCRIPTS_DIR/$maint_name"
    script_count=$((script_count + 1))
  done
fi

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
echo "Done! $skill_count skills + $agent_count agents + $oc_agent_count opencode-agents + $hook_count hooks installed"
echo ""
echo "Next steps:"
echo "  1. Copy templates/CLAUDE.md into your project root"
echo "  2. (opcional, recomendado) Copy templates/.mcp.json into your project root"
echo "     → ativa shadcn + context7 + lighthouse + sentry MCPs (verifique com /mcp)"
echo "  3. Open Claude Code inside your project folder"
echo "  4. Type: /sdlc-orchestrator"
echo ""
echo "Skills OBRIGATORIAS do product-designer (sem as tres ele para em 'blocked'):"
echo "  - ui-ux-pro-max:"
echo "      npx -y skills add https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max"
echo "  - design-taste-frontend (taste-skill; precisa de Node 22+ e Chrome):"
echo "      npx -y skills add https://github.com/Leonxlnx/taste-skill --skill design-taste-frontend"
echo "  - impeccable:"
echo "      npx -y skills add pbakaus/impeccable"
echo "      O engine baixa um binario na 1a execucao. Para nao executar binario baixado: compile do fonte"
echo "      (cargo build --release --locked -p impeccable) e copie para <skill>/scripts/bin/<os>-<arch>/impeccable."
echo "      Telemetria: <skill>/scripts/impeccable telemetry off  |  update-check: IMPECCABLE_NO_UPDATE_CHECK=1"
echo ""
echo "Skills condicionais ao stack:"
echo "  - supabase-postgres-best-practices (OBRIGATORIA quando o banco e PostgreSQL — backend/performance param em 'blocked' sem ela):"
echo "      npx -y skills add supabase/agent-skills --skill supabase-postgres-best-practices"
echo "  - vercel-react-best-practices (opt-in, React/Next — frontend-engineer):"
echo "      npx -y skills add https://github.com/vercel-labs/agent-skills --skill vercel-react-best-practices"
echo "  - terraform-test + terraform-style-guide (opt-in, Terraform — cloud-architect):"
echo "      claude plugin marketplace add hashicorp/agent-skills && claude plugin install terraform@hashicorp"
echo "  - evals-skills (opt-in, Risk Surface LLM/agent/RAG — quality-architect):"
echo "      claude plugin marketplace add ai-evals-course/evals-skills   # plugin 'evals'"
echo "  - copywriting (opt-in, launch copy — product-marketing-manager):"
echo "      npx -y skills add https://github.com/coreyhaines31/marketingskills --skill copywriting"
echo "  Para o OpenCode, copie as mesmas pastas para ~/.config/opencode/skills/ (todas sao markdown puro)."
echo ""
echo "Tooling externo opcional (mapa completo em templates/tooling.md):"
echo "  - Trail of Bits SAST (engine do security-engineer; precisa de semgrep):"
echo "      claude plugin marketplace add trailofbits/skills"
echo "      claude plugin install static-analysis@trailofbits && brew install semgrep"
echo "  - 21st.dev Magic (scaffold de componentes, precisa de API key):"
echo "      claude mcp add magic --scope user --env API_KEY=\"...\" -- npx -y @21st-dev/magic@latest"
echo ""
