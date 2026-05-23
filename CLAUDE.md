# ai-squad — Project Context

ai-squad é um framework de desenvolvimento ágil spec-driven para Claude Code. Fornece 13 agents especializados + 4 skills (2 user-invocáveis: sdlc-orchestrator + onboard-brownfield; 2 agent-invocáveis: systematic-debugging + writing-plans) + 1 slash pattern (`/goal` para handoff autônomo), um processo completo de SDLC com gates de qualidade, suporte a paralelismo via TeamMode + tmux, e onboarding automático de codebases pré-existentes.

## Stack

- **Distribuição:** shell script (`install.sh`) + arquivos `.skill` (zip)
- **Skills:** Markdown (`.claude/skills/{nome}/SKILL.md`)
- **CI/CD:** não configurado ainda
- **Linguagem de documentação:** Português (BR) + English

## Estrutura do projeto

```
ai-squad/
├── skills/                  # 4 skills (sdlc-orchestrator, onboard-brownfield, systematic-debugging, writing-plans)
│   └── {nome}/SKILL.md
├── agents/                  # 13 custom agents (.md) — modelo fixo por papel
│   └── {nome}.md
├── scripts/
│   ├── metrics/             # collect.sh — coleta DORA + engineering metrics
│   └── observability/       # render-dashboard.sh — HTML stakeholder dashboard (opcional)
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
- **Commit imediato no global após cada edição.** Após editar qualquer arquivo em `~/.claude/agents/` ou `~/.claude/skills/`, commit no git local do diretório global antes de prosseguir. Working tree dirty no global é perigoso: o próximo `git add` em uma operação não relacionada pode arrastar a drift junto e produzir commit com escopo enganoso (já aconteceu em 2026-05-01 — `ba7fda4` rolou 73 linhas de patterns de Apr-27 dentro de um commit rotulado "5 T1 changes"). Verificar `cd ~/.claude/agents && git status` antes de iniciar nova edição.
- **Toda sync global → repo deve revisar `docs/site/index.html`.** O HTML doc é hand-written (não é gerado de markdown), então drift entre o conteúdo universal sincronizado e a página de pitch acumula silenciosamente. Após copiar agents/skills do global, fazer um pass de revisão buscando por: (a) contagem de agents (procurar "N agentes" / "N agents"), (b) chips/cards de agents novos (ex: `product-marketing-manager` foi adicionado em `1587b46` e só apareceu no HTML quando alguém percebeu manualmente), (c) novos slashes ou patterns operacionais (ex: `/goal` chegou ao README em `062f502` mas ficou ausente do HTML até `8edf989`). Se o HTML não menciona um conceito que o README/CLAUDE.md menciona, é drift — commit separado pra fechar.

## O que NÃO fazer

- Não colocar contexto de projeto específico dentro das skills — elas devem ser universais
- Não hardcodar caminhos absolutos no `install.sh`
- Não remover a retrospective gate do sdlc-orchestrator — é o mecanismo de aprendizado
- Não editar skills diretamente no repo sem verificar se o global está em sincronia

## Referências externas

- Plano de melhorias: [docs/improvements.md](docs/improvements.md)
- Log de outputs de agents: [docs/agent-outputs-log.md](docs/agent-outputs-log.md)
