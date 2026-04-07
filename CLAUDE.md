# ai-squad — Project Context

ai-squad é um framework de desenvolvimento ágil spec-driven para Claude Code. Fornece 14 skills especializadas (agentes com papéis definidos), um processo completo de SDLC com gates de qualidade, e suporte a paralelismo via TeamMode + tmux.

## Stack

- **Distribuição:** shell script (`install.sh`) + arquivos `.skill` (zip)
- **Skills:** Markdown (`.claude/skills/{nome}/SKILL.md`)
- **CI/CD:** não configurado ainda
- **Linguagem de documentação:** Português (BR) + English

## Estrutura do projeto

```
ai-squad/
├── skills/                  # Fonte das 14 skills
│   └── {nome}/SKILL.md
├── templates/
│   └── CLAUDE.md            # Template de contexto para projetos que usam o framework
├── install.sh               # Instala skills em ~/.claude/skills/
├── TEAMMODE.md              # Guia de paralelismo com tmux
└── README.md
```

## O que NÃO fazer

- Não colocar contexto de projeto específico dentro das skills — elas devem ser universais
- Não hardcodar caminhos absolutos no `install.sh`
- Não remover a retrospective gate do sdlc-orchestrator — é o mecanismo de aprendizado

---

# Plano de Melhorias

Diagnóstico feito em abril/2026. Implementar as melhorias abaixo em ordem de prioridade.

---

## 1. Custom Agents (`.claude/agents/`) — Alta prioridade

**Problema:** Hoje os agentes são criados via skill-como-persona. Não há restrição de ferramentas nem modelo fixo por agente.

**O que fazer:**
- Criar `.claude/agents/` no repo com um arquivo `.md` por agente
- Cada arquivo deve ter frontmatter com `model`, `tools` permitidas e `description`
- Os agentes devem espelhar as skills existentes, mas usando a estrutura nativa do Claude Code
- Adicionar ao `install.sh` a cópia desses arquivos para `~/.claude/agents/`

**Resultado esperado:** Modelo roteado automaticamente (Opus/Sonnet/Haiku) sem depender do prompt; ferramentas restritas por papel; mais confiável para outros devs.

**Referência:** [Custom agents — Claude Code docs](https://docs.anthropic.com/en/docs/claude-code/agents)

---

## 2. Template de projeto com `.claude/` pré-configurado — Alta prioridade

**Problema:** O `install.sh` instala as skills globalmente, mas não configura o projeto do dev com `settings.json`, TeamMode ou `.claude/` adequado.

**O que fazer:**
- Criar `templates/project/.claude/settings.json` com TeamMode habilitado:
  ```json
  {
    "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
    "Preferences": { "tmuxSplitPanes": true },
    "teammateMode": "tmux"
  }
  ```
- Atualizar o `install.sh` para perguntar se quer inicializar um projeto novo e copiar o template
- Ou criar um comando separado: `bash init-project.sh /caminho/do/projeto`

**Resultado esperado:** Dev clona o ai-squad, roda o init, abre o Claude no projeto e já tem TeamMode funcionando.

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

## 4. Onboarding aprimorado — Média prioridade

**Problema:** O README explica o que é o framework, mas não guia o dev no primeiro uso de forma prática.

**O que fazer:**
- Criar `QUICKSTART.md` com fluxo do zero:
  1. Instalar ai-squad
  2. Inicializar projeto
  3. Abrir Claude + `/sdlc-orchestrator`
  4. Primeiro módulo passo a passo
- Adicionar checklist de "pré-requisitos" (tmux, modelo configurado, CLAUDE.md preenchido)
- Considerar um comando `/ai-squad-setup` como skill de onboarding que valida o ambiente

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
