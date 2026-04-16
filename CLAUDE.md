# ai-squad — Project Context

ai-squad é um framework de desenvolvimento ágil spec-driven para Claude Code. Fornece 12 agents especializados + 2 skills (sdlc-orchestrator + onboard-brownfield), um processo completo de SDLC com gates de qualidade, suporte a paralelismo via TeamMode + tmux, e onboarding automático de codebases pré-existentes.

## Stack

- **Distribuição:** shell script (`install.sh`) + arquivos `.skill` (zip)
- **Skills:** Markdown (`.claude/skills/{nome}/SKILL.md`)
- **CI/CD:** não configurado ainda
- **Linguagem de documentação:** Português (BR) + English

## Estrutura do projeto

```
ai-squad/
├── skills/                  # 2 skills (sdlc-orchestrator + onboard-brownfield)
│   └── {nome}/SKILL.md
├── agents/                  # 12 custom agents (.md) — modelo fixo por papel
│   └── {nome}.md
├── scripts/
│   └── metrics/             # collect.sh — coleta DORA + engineering metrics
├── templates/
│   ├── CLAUDE.md            # Template de contexto para projetos que usam o framework
│   └── docs/
│       └── maturity-assessment.md  # Rubrica 5×4 de maturidade SDLC
├── docs/
│   └── integrations/        # Recipes de engineering-metrics providers
├── install.sh               # Instala skills + agents em ~/.claude/
├── TEAMMODE.md              # Guia de paralelismo com tmux
└── README.md
```

## Fonte da verdade das skills e agents

**`~/.claude/skills/` e `~/.claude/agents/` são a fonte da verdade. O repo é o espelho de distribuição.**

As skills e agents evoluem continuamente via uso em projetos reais. Cada projeto que usa o framework pode melhorar uma skill/agent — a melhoria vai para o global primeiro, depois é sincronizada para o repo antes de cada release.

### Fluxo de evolução

```
projeto real descobre padrão novo
  → skill/agent global atualizado (~/.claude/skills/ ou ~/.claude/agents/)
  → ao preparar release: diff global vs repo
  → conteúdo universal → repo/skills/ e repo/agents/
  → conteúdo projeto-específico → docs/engineering-patterns.md do projeto
  → commit + push
```

### Regras de sincronização

- **Global → repo:** sempre antes de um release. Usar `diff -rq ~/.claude/skills/ skills/` e `diff -rq ~/.claude/agents/ agents/` para identificar diffs.
- **Repo → global:** quando uma skill é reescrita com base em referências externas (como aconteceu com security-engineer e quality-architect). Copiar manualmente após revisão.
- **Conteúdo projeto-específico** (nomes de bibliotecas, campos de domínio, stack particular) **nunca entra no repo** — fica no `docs/engineering-patterns.md` do projeto de origem.
- Skills no repo **não têm** campo `version` no frontmatter — versionamento é responsabilidade do global.

## O que NÃO fazer

- Não colocar contexto de projeto específico dentro das skills — elas devem ser universais
- Não hardcodar caminhos absolutos no `install.sh`
- Não remover a retrospective gate do sdlc-orchestrator — é o mecanismo de aprendizado
- Não editar skills diretamente no repo sem verificar se o global está em sincronia

---

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

---

## Agent Outputs

Log de trabalho executado por agents especializados.

- [tech-writer — README + CLAUDE.md sync para brownfield + new skills + gates](docs/agents/tech-writer/2026-04-15-readme-claude-sync.md) — 2026-04-15
