# Superpowers + Karpathy integration plan

**Data:** 2026-05-23
**Status:** T1 em execução · T2 sob demanda · T3 deferred

## Contexto

Avaliação de dois repositórios externos de skills para incorporação no ai-squad:

- [obra/superpowers](https://github.com/obra/superpowers) — 16 skills cobrindo o ciclo de discovery → finish. Alto valor: cobre o gap "como executar bem dentro de cada fase" que o `sdlc-orchestrator` não detalha.
- [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) — 1 arquivo com 4 princípios comportamentais. Valor conceitual; sem LICENSE no repo, então **reescrever do zero com palavras próprias**.

Relatório completo de análise produzido pelo Explore antes do plano (não persistido — síntese abaixo).

## Decisões fechadas

| # | Decisão | Escolha |
|---|---|---|
| 1 | TDD enforcement | Técnica nos prompts de `backend-engineer` e `frontend-engineer`, com exceções narrow (hotfix/infra/scripts/spikes) — **não** vira skill separada |
| 2 | Brainstorming overlap | Upgrade do `idea-researcher` existente com metodologia socrática do Superpowers — **não** criar skill `/brainstorm` paralela |
| 3 | Filosofia agent-centric vs skill-centric | Manter agent-centric — skills do Superpowers reescritas como ferramentas invocadas por agents nomeados, **não** como reflexos auto-disparados |
| 4 | Licença Karpathy | Reescrever os 4 princípios do zero — repo não tem LICENSE explícita |

## Tier 1 — executado em 2026-05-23

- [x] **T1.1** — `verification-before-completion` guardrail → `~/.claude/CLAUDE.md` (seção "Operational guardrails → Verification before completion claims")
- [x] **T1.2** — `receiving-code-review` guardrail → `~/.claude/CLAUDE.md` (seção "Operational guardrails → Code review reception")
- [x] **T1.3** — `writing-skills` (TDD pra skills) → `~/.claude/CLAUDE.md` (seção "Operational guardrails → Writing or editing skills")
- [x] **T1.4** — Worktree safety checklist → `TEAMMODE.md` (seção "Worktree safety")
- [x] **T1.5** — `dispatching-parallel-agents` decision tree → `TEAMMODE.md` (seção "Quando dispatch paralelo vale")
- [x] **T1.6** — 4 princípios Karpathy reescritos do zero → `templates/CLAUDE.md` (seção "Agent behavioral principles")

## Tier 2 — executado em 2026-05-23

- [x] **T2.1** — `idea-researcher` v1.1 — socratic 1-pergunta-por-vez, 2-3 abordagens explícitas, design gate em 3 sub-passos (apresenta seção-por-seção, self-review, user approval antes de PRD)
- [x] **T2.2** — Test-first como técnica nos `Always` de `backend-engineer` v1.10 e `frontend-engineer` v1.4 — default em features novas, exceções narrow (hotfix/infra/scripts/spikes) com justificativa
- [x] **T2.3** — Nova skill `systematic-debugging` — 4-fases (root cause → pattern → hypothesis → fix), invocada por qa/engineers/Tech Lead
- [x] **T2.4** — Nova skill `writing-plans` — bite-sized tasks (2-5min) com paths exatos e código real, invocada por `software-architect` após spec aprovada, output em `docs/plans/`
- [x] **T2.5** — `sdlc-orchestrator` v1.3 — finish-branch gate entre consistency-check e retrospective, 4-option menu (merge/PR/keep/discard) com env detection e cleanup provenance-based
- [x] **T2.6** — `software-architect` v1.11 + `sdlc-orchestrator` v1.4 — review dispatch agora exige BASE_SHA/HEAD_SHA, reviewer lê diff via `git diff`, não de prompt; orchestrator regra parallel adicionada

**Regra aplicada em todas as T2:** seção "when to use" reescrita para "invocada por `<agent>` em `<fase>`" — preservando agent-centric.

## Tier 3 — executado em 2026-05-23

- [x] **T3.1** — `sdlc-orchestrator` v1.5 — novo "task-by-task impl execution mode" como subseção do impl phase. Auto-ativada em T3 + alta Risk Surface; opt-in em T2 standard; skip em T1. Per-task loop: dispatch owner agent com 1 task → commit → review-team com BASE_SHA/HEAD_SHA daquele task → BLOCK loop com retry cap 3 → módulo-level review depois do último task. Coexiste com `/goal` (auto-ativa conforme Risk Surface declarada). Fecha o loop com `writing-plans` (T2.4) — sem essa mode, os bite-sized tasks eram só artefato organizacional.

## Skills do Superpowers descartadas

| Skill | Motivo |
|---|---|
| `using-superpowers` | Filosofia skill-centric com auto-invocação — incompatível com modelo agent-centric do ai-squad |
| `executing-plans` | Já coberto por `/goal` + `sdlc-orchestrator` (com pauses vs autônomo) |

## Source materials

- `/tmp/superpowers/skills/` — clone do Superpowers (licença open source no repo)
- `/tmp/karpathy-skills/` — clone do Karpathy skills (sem LICENSE; conteúdo reescrito do zero)

## Rastreamento de progresso

Cada item T1/T2 deve ser marcado conforme executado. Use checkbox markdown.
Quando todos os T1 estiverem completos, commit consolidado. T2 commits atômicos individuais.
