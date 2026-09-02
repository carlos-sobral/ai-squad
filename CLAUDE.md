# ai-squad — Project Context

ai-squad é um framework de desenvolvimento ágil spec-driven para Claude Code. Fornece 13 agents especializados + 9 skills (3 user-invocáveis: sdlc-orchestrator + onboard-brownfield + product-backlog; 3 agent-invocáveis: systematic-debugging + writing-plans + deliberate-confrontation; 3 de self-improvement: auto-research + sdlc-practices-evolve + agents-improvement-audit) + 1 slash pattern (`/goal` para handoff autônomo), um processo completo de SDLC com gates de qualidade, suporte a paralelismo via TeamMode + tmux (com Workflow tool como motor determinístico para sub-fases bem-postas), e onboarding automático de codebases pré-existentes.

## Stack

- **Distribuição:** shell script (`install.sh`) + arquivos `.skill` (zip)
- **Skills:** Markdown (`.claude/skills/{nome}/SKILL.md`)
- **CI/CD:** não configurado ainda
- **Linguagem de documentação:** Português (BR) + English

## Estrutura do projeto

```
ai-squad/
├── skills/                  # 9 skills (sdlc-orchestrator, onboard-brownfield, product-backlog,
│   │                        #   systematic-debugging, writing-plans, deliberate-confrontation,
│   │                        #   auto-research, sdlc-practices-evolve, agents-improvement-audit)
│   ├── {nome}/SKILL.md
│   └── sdlc-orchestrator/workflows/  # Scripts de referência do Workflow tool (review-team, prd-sharding, ...)
├── agents/                  # 13 custom agents (.md) — modelo fixo por papel
│   └── {nome}.md
├── scripts/
│   ├── hooks/               # Enforcement hooks (guard-bash, guard-stop)
│   ├── maintenance/         # reap-orphan-teammates.sh — varre teammates vazados
│   ├── metrics/             # collect.sh — DORA + engineering metrics
│   │                        # validate-events.sh — conformidade do event log
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
- **O repo é espelho byte-identical do global** — inclusive o campo `version` no frontmatter, quando o global o carrega. Versionamento é responsabilidade do global: bump lá, copie inteiro pra cá. Não edite nem remova `version` no repo, e não adicione onde o global não tem (hoje 4 de 9 skills e 9 de 13 agents carregam o campo; a assimetria é histórica, não regra). O teste de sync é `diff` limpo, não inspeção de frontmatter.
- **Commit imediato no global após cada edição.** Após editar qualquer arquivo em `~/.claude/agents/` ou `~/.claude/skills/`, commit no git local do diretório global antes de prosseguir. Working tree dirty no global é perigoso: o próximo `git add` em uma operação não relacionada pode arrastar a drift junto e produzir commit com escopo enganoso (já aconteceu em 2026-05-01 — `ba7fda4` rolou 73 linhas de patterns de Apr-27 dentro de um commit rotulado "5 T1 changes"). Verificar `cd ~/.claude/agents && git status` antes de iniciar nova edição.
- **Toda sync global → repo deve revisar `README.md` E `docs/site/index.html`.** Os dois são hand-written (nenhum é gerado do outro nem do markdown das skills), então a fonte da drift é sempre a mesma — um conceito nasce num agent/skill do global — e **os dois são downstream**. Não presuma que o README lidera e o HTML segue: em 2026-09-02 o HTML ficou à frente do README em seis conceitos (`fitness function`, `isolation: worktree`, `provenance`, `SBOM`, `progressive`, estratégia de release), exatamente a direção que a redação anterior desta regra não previa.

  O check tem duas partes, e a primeira é mecânica:

  1. **Contagens e nomes** — `ls agents/*.md | wc -l` e `ls skills/` conferem contra o que os dois docs afirmam ("N agentes", "N skills"); e todo agent/skill precisa aparecer nos dois. Um agente novo entra no grid do HTML e na tabela do README, não em um só (`product-marketing-manager` entrou em `1587b46` e só apareceu no HTML quando alguém percebeu na mão).
  2. **Conceitos** — extraia os substantivos novos do diff que você acabou de sincronizar e faça `grep -ci` de cada um nos dois arquivos. Zero em qualquer um dos dois é drift. Vale para slash e pattern operacional também (`/goal` chegou ao README em `062f502` e ficou fora do HTML até `8edf989`).

     **Um zero exige uma segunda olhada antes de virar achado.** Agents e skills são escritos em inglês; README e HTML, em português. `grep -ci "release strategy"` devolve 0 nos dois arquivos e o conceito está presente nos dois, como "estratégia de release" — falso positivo puro, e foi assim que este próprio check falhou na primeira vez que rodou (2026-09-02). Grepe pelo termo **como ele aparece na língua do doc**, ou por um identificador que não traduz (nome de flag, valor de config, nome de arquivo: `isolation: worktree`, `all-at-once`, `SBOM`). Zero num identificador que não traduz é drift de verdade.

  Nem todo conceito merece os dois lugares com o mesmo peso: o README documenta o mecanismo, o HTML vende a disciplina. Detalhe granular (ex: ler flame graph no gate de perf) pode viver só no README — mas isso é uma **decisão declarada no commit**, não uma omissão silenciosa. Feche a drift em commit separado do sync.

## O que NÃO fazer

- Não colocar contexto de projeto específico dentro das skills — elas devem ser universais
- Não hardcodar caminhos absolutos no `install.sh`
- Não remover a retrospective gate do sdlc-orchestrator — é o mecanismo de aprendizado
- Não editar skills diretamente no repo sem verificar se o global está em sincronia

## Referências externas

- Plano de melhorias: [docs/improvements.md](docs/improvements.md)
- Log de outputs de agents: [docs/agent-outputs-log.md](docs/agent-outputs-log.md)

## Agent Outputs

- [performance-engineer — gate — Module: Settings](docs/agents/performance-engineer/2026-05-31-gate-settings.md) — 2026-05-31
