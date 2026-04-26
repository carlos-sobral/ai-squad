# Plano de Melhorias

Diagnóstico feito em abril/2026. Implementar as melhorias abaixo em ordem de prioridade.

---

## ~~1. Custom Agents (`.claude/agents/`) — FEITO~~

12 agents criados em `agents/` com frontmatter (`name`, `description`, `model`). `install.sh` atualizado para copiar para `~/.claude/agents/`. Modelo roteado automaticamente por papel (Opus/Sonnet/Haiku). `refactoring-engineer` foi eliminado — sua funcionalidade agora é o Mode 5 (Refactor) do `software-architect`.

---

## 2. Template de projeto com `.claude/` pré-configurado — Aguardando priorização

**Problema:** O `install.sh` instala as skills globalmente, mas não configura o projeto do dev com `settings.json`, TeamMode ou `.claude/` adequado.

**Status:** Parcialmente coberto por `/onboard-brownfield` em brownfield. Para greenfield, ainda é manual — copiar `templates/CLAUDE.md` e editar `~/.claude/settings.json` manualmente.

**O que fazer (opcional):**
- Criar `init-project.sh` que pergunte greenfield vs brownfield
- Se greenfield: copiar template + guiar pré-requisitos
- Se brownfield: recomendar `/onboard-brownfield` e validar pré-reqs

---

## 3. MCPs úteis para o fluxo — Média prioridade

**Problema:** Nenhum MCP configurado. O fluxo spec-driven se beneficiaria de ferramentas externas integradas.

**O que fazer:**
- Avaliar e documentar MCPs relevantes para o processo:
  - **Asana MCP** — criar/atualizar tarefas diretamente do fluxo SDLC
  - **OpenAPI validator MCP** — validar contratos de API durante o review
  - **GitHub MCP** — criar PRs, comentar issues, verificar CI direto do fluxo
- Criar seção no README com MCPs recomendados e como configurá-los
- Adicionar configuração opcional ao `install.sh`

**Resultado esperado:** Devs podem integrar ferramentas do seu stack no fluxo agentic sem configuração manual.

---

## 4. Onboarding greenfield aprimorado — Média prioridade (substitui item anterior)

**Problema:** O README explica o que é o framework, mas não guia o dev no primeiro uso de forma prática.

**Status:** `/onboard-brownfield` cobre 100% do case brownfield. Para greenfield, falta guia step-by-step de setup + primeiro módulo.

**O que fazer:**
- Criar `QUICKSTART.md` com fluxo do zero (greenfield):
  1. Instalar ai-squad
  2. Copiar template CLAUDE.md + preencher seções chave
  3. Validar pré-requisitos (tmux, settings.json, git init)
  4. Abrir Claude + `/sdlc-orchestrator` → primeiro módulo passo a passo
- Adicionar checklist de "pré-requisitos" (tmux, modelo configurado, CLAUDE.md preenchido)

**Resultado esperado:** Dev novo consegue rodar o primeiro módulo em menos de 30 minutos.

---

## 5. Skill de setup/validação do ambiente — Baixa prioridade

**Problema:** Não há forma de um dev verificar se o ambiente está configurado corretamente.

**O que fazer:**
- Criar skill `setup-validator` que verifica:
  - Skills instaladas em `~/.claude/skills/`
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` habilitado
  - tmux disponível
  - `CLAUDE.md` do projeto preenchido com as seções obrigatórias
- Retorna relatório com o que está OK e o que precisa corrigir

**Resultado esperado:** Dev roda `/setup-validator` e sabe exatamente o que falta antes de começar.
