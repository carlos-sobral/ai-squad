# Engineering Maturity Assessment

This document tracks the engineering maturity of this squad along **5 dimensions**, each scored on **4 levels** (L1 Ad-hoc → L4 Optimizing). It is the squad's honest mirror — not a marketing artifact.

## What this is

A rubric-driven view of how the squad executes the SDLC. It is not a performance review of people; it is a measurement of the *system* (process + agents + tooling). Each dimension answers a single question:

- **Spec Discipline** — are we writing specs before code, with enough rigor?
- **Review Coverage** — are we running the right reviewers, at the right depth?
- **Learning Loop** — are blockers from one module preventing blockers in the next?
- **Delivery Stability** — are we shipping changes that stick (low CFR, short lead time)?
- **Observability Maturity** — do we know in production what we promised to know in the spec?

## How it is maintained

- **Owner:** the Tech Lead. The `sdlc-orchestrator` proposes updates at the end of every retrospective gate (module N completion). The Tech Lead approves any transition before it is recorded here.
- **Source of evidence:** `docs/metrics/latest.md` (produced by `performance-engineer` audit mode running `scripts/metrics/collect.sh`) plus the orchestrator's own observation of which gates ran for the module just shipped.
- **Cadence:** updated on every retrospective gate. Audit-based metrics refresh every 2 weeks via the biweekly performance audit.

## Promotion / regression rules

- **Promotion (L → L+1):** 3 modules consecutively cumprindo a evidência objetiva do próximo nível. No single-module promotions.
- **Regressão (L → L-1):** 2 módulos consecutivos falhando o critério do nível atual. Não punir falha isolada — uma só não regride.
- **Auto-claim permitido com evidência citada** — o orchestrator pode propor uma transição apontando para os módulos e métricas que a sustentam, mas qualquer mudança precisa ser assinada pelo Tech Lead.
- **L4 não é meta.** Squad pequeno mora confortável em L2-L3. Buscar L4 onde traz valor real (ex.: Delivery Stability em produto regulado), aceitar L2 onde o custo de chegar a L3 é maior que o ganho.

---

## Status atual

| Dimension | Current Level | Since | Evidence (last assessment) | Next-level criteria |
|---|---|---|---|---|
| Spec Discipline | L1 | <project-start> | no modules shipped yet | ≥80% módulos com PRD antes do código |
| Review Coverage | L1 | <project-start> | no modules shipped yet | review-team standard rodando em 100% dos módulos |
| Learning Loop | L1 | <project-start> | no modules shipped yet | retrospective gate em ≥80% dos módulos |
| Delivery Stability | L1 | <project-start> | no modules shipped yet | CFR ≤20%; lead time medido |
| Observability Maturity | L1 | <project-start> | no modules shipped yet | stack escolhida e declarada em `## Tooling > observability` |

---

## Brownfield baseline

If this project was onboarded via `/onboard-brownfield`, the initial Status above was auto-claimed from observable evidence in the existing codebase. Auto-claim rules:

| Dimension | Auto-claim possible | Evidence required |
|---|---|---|
| Spec Discipline | **L1 always** | Reviews/PRDs predating ai-squad don't follow the framework format. Starts from zero — honest. |
| Review Coverage | **L1 always** | Same reason. |
| Learning Loop | **L1 always** | No retrospective gates pre-onboarding to baseline against. |
| Delivery Stability | **L2 or L3** | L2: CI ran 90d with >100 PRs merged AND <20% commits matching `^(revert\|hotfix\|fix:)`. L3: also p95 PR open→merge ≤5 days. Cite the exact `git log` / `gh pr list` command output. |
| Observability Maturity | **L2 or L3** | L2: an obs stack is detected in deps + env vars configured. L3: also alerts configured (e.g., `pagerduty.yml`, `alerts/` dir present). Cite the file. |

**Rules:**
- Anything auto-claimed above L1 must cite the module/command/file that proved it. No claim without evidence.
- Spec Discipline / Review Coverage / Learning Loop assessments are **not retroactive** — they only count modules shipped after onboarding.
- The first `performance-engineer` audit biweekly validates auto-claimed levels above L1. If evidence doesn't hold, regress immediately (exception to the 2-consecutive rule).

---

## Histórico de transições

| Date | Dimension | From | To | Trigger module(s) | Evidence ref |
|---|---|---|---|---|---|
| (append-only — never edit past rows) | | | | | |

---

## Rubrica completa (referência)

| Dimensão | L1 Ad-hoc | L2 Repeatable | L3 Defined | L4 Optimizing |
|---|---|---|---|---|
| **Spec Discipline** | <50% módulos têm PRD antes do código | ≥80% PRD; <50% T2/T3 com clarify | ≥80% T2+ com clarify executado; Spec-Fidelity ≥70% por 3 módulos | Spec-Fidelity ≥85% por 6 módulos; clarify ≤2 perguntas média |
| **Review Coverage** | Review-team em <60% | Standard em 100%; modos críticos ad-hoc | Depth correta em ≥90%; 0 LLM-review pulado quando signals presentes | 0 críticos pós-merge/trimestre; <1 blocker/módulo |
| **Learning Loop** | Retrospective skipado | ≥80% módulos; <30% blockers viram diff | Conversion ≥40%; cada agent ≥1 bump em 90d | Conversion ≥60%; 0 blockers repetidos nos últimos 3 módulos |
| **Delivery Stability** | CFR não medido OU >25% | CFR ≤20%; lead time medido | CFR ≤15%, p95 ≤5d por 3 módulos | CFR ≤10%, p95 ≤3d por 6 módulos; 0 rollbacks/trimestre |
| **Observability Maturity** | Sem `## Tooling > observability` configurado | Stack escolhida; health check definido mas pulado | 100% deploys validados; 0 catalog gap por 3 módulos | Audit biweekly encontra ≥1 problema antes de virar incidente |

### Como ler a rubrica

- Cada célula descreve a evidência **objetiva** que sustenta o nível. Se a evidência não está disponível em `docs/metrics/latest.md` ou no histórico de retrospectives, o nível não pode ser promovido — fica onde está.
- Critérios "por N módulos" exigem N **consecutivos**. Quebrar a sequência reinicia a contagem para promoção (mas não regride automaticamente — regressão tem regra própria de 2 consecutivos).
- "Conversion" em Learning Loop = (blockers que viraram diff aprovado em agent definition / docs / ADR) ÷ (total de blockers do módulo).
- "Spec-Fidelity" em Spec Discipline vem do consistency-check gate: módulos sem itens (c) ou (d) não-resolvidos contam como fidelidade alta. Pode ser computado como % de módulos sem deviation/gap residual.
