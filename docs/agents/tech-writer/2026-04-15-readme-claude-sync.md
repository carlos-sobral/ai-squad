---
skill: tech-writer
date: 2026-04-15
task: Sync README.md and CLAUDE.md to reflect brownfield support + new skills + gates + observability
status: complete
---

## Summary

Updated project documentation (README.md and CLAUDE.md) to reflect recent features added across 6 commits (from `e06d474` back to `60ee5a1`):

- **New skill:** `onboard-brownfield` (v1.0) for one-shot discovery + inventory of pre-existing codebases
- **4th mode:** `software-architect` Mode 4 (Discovery) for brownfield onboarding
- **3rd mode:** `cloud-architect` Mode 3 (Inventory) for brownfield infrastructure discovery
- **Product Designer:** added Documentation sub-mode for brownfield UI token extraction
- **Security Engineer:** added `llm-review` mode (OWASP LLM Top 10:2025)
- **Product Manager:** added EARS notation support for event-driven acceptance criteria
- **New gates:** Clarify gate (T2/T3) and Consistency-check gate (pre-merge, 4 delta classes + brownfield class e)
- **Tooling block:** centralized YAML adapter pattern for issue tracker, repo host, CI/CD, chat, engineering metrics, observability
- **Engineering metrics:** `scripts/metrics/collect.sh` for DORA + process health + agentic signals
- **Maturity assessment:** template rubric (5 dimensions × 4 levels) with brownfield baseline auto-claim
- **Brownfield UX:** safe defaults; greenfield flow unchanged

---

## Changes by file

### `/Users/carlos.sobral/github-repos/ai-squad/README.md`

**Sections updated:**

1. **Intro (line 5):** "12 agents + 1 skill" → "12 agents + 2 skills" (onboard-brownfield is now prominent)

2. **2 skills section (line 155):** Added skill descriptions:
   - `sdlc-orchestrator` — full SDLC flow
   - `onboard-brownfield` (NEW) — one-shot brownfield discovery + inventory, baseline docs + maturity

3. **software-architect modes (line 163):** 3 modes → 4 modes:
   - Spec, Code review, Refactor (existing)
   - **Discovery (new)** — brownfield-only, used via `/onboard-brownfield`

4. **product-designer modes (line 184):** Clarified Design System vs Documentation:
   - Design System Mode (greenfield)
   - **Documentation Mode (NEW, brownfield)** — extracts tokens, marks [TO DEFINE], never modifies
   - UX Spec Mode (both)

5. **cloud-architect modes (line 203):** 2 modes → 3 modes:
   - Setup, Review (existing)
   - **Inventory mode (NEW, brownfield)** — reads existing CI/CD, populates ## Tooling

6. **Agents table (line 140–153):**
   - `security-engineer` — added LLM review mode (OWASP LLM Top 10:2025)
   - `product-manager` — added EARS notation support

7. **Repository structure (line 284):** Updated to reflect:
   - `scripts/metrics/` — collect.sh location
   - `templates/docs/` — maturity-assessment.md
   - `docs/integrations/` — provider recipes

8. **NEW section: Gates de qualidade automáticos** (inserted before "Dica"):
   - Clarify gate (T2/T3, ambiguity + legacy preservation)
   - Consistency-check gate (4 delta classes a-d, + class e brownfield)
   - Post-deploy observability gates (SLI/SLO validation)

9. **NEW section: Tooling adapter block** (inserted before "Dica"):
   - Centralized YAML in CLAUDE.md ## Tooling
   - All integrations (issue tracker, CI/CD, observability, metrics)
   - Provider swap by editing one line
   - Link to `docs/integrations/engineering-metrics-providers.md`

10. **NEW section: Engineering metrics** (inserted before "Dica"):
    - `scripts/metrics/collect.sh` — DORA + process health
    - Output: `docs/metrics/latest.md` + history
    - Rubric: 5 dimensions × 4 levels (maturity assessment)
    - Brownfield baseline auto-claim

11. **NEW section: Suporte a brownfield** (inserted before "Dica"):
    - `/onboard-brownfield` one-shot flow
    - Parallel discovery-team (software-architect Mode 4 + cloud-architect Mode 3)
    - Populates baseline CLAUDE.md, ADR, engineering-patterns, maturity-assessment
    - [TO DEFINE] markers for gaps
    - Design System Documentation Mode recommendation if UI

12. **FAQ update:** "Posso usar em projetos existentes?"
    - Clarified distinction: brownfield → run `/onboard-brownfield` first; greenfield → manual CLAUDE.md setup

### `/Users/carlos.sobral/github-repos/ai-squad/CLAUDE.md`

**Sections updated:**

1. **Intro (line 3):** "12 agents + 1 skill" → "12 agents + 2 skills (sdlc-orchestrator + onboard-brownfield)"

2. **Project structure (line 12):** Updated to include:
   - `scripts/metrics/` — collect.sh for DORA metrics
   - `templates/docs/maturity-assessment.md` — rubric template
   - `docs/integrations/` — provider recipes

3. **Improvement Plan — Item 1:** Marked as complete (was already ~~done~~)

4. **Improvement Plan — Item 2:** "Template de projeto pré-configurado"
   - Status: "Aguardando priorização" (was "Alta prioridade")
   - Added note: Partially covered by `/onboard-brownfield` for brownfield; greenfield still manual
   - Adjusted scope: optional `init-project.sh` helper (not critical path)

5. **Improvement Plan — Item 4:** Renamed from "Onboarding aprimorado" → "Onboarding greenfield aprimorado"
   - Status: "Média prioridade (substitui item anterior)"
   - Added note: `/onboard-brownfield` covers 100% of brownfield case; gap is greenfield step-by-step guide
   - Clarified scope: QUICKSTART.md for greenfield flow only

---

## Documentation gaps identified (for future work)

- **No dedicated onboarding guide (QUICKSTART.md)** for greenfield projects — manual copy + fill still required
- **No `init-project.sh` helper** — could automate template copy + settings.json scaffold
- **No MCP integration docs** — evaluating Asana/GitHub/OpenAPI MCPs still pending (Item 3 in plan)
- **Brownfield edge cases not yet documented:** monorepo strategy, multi-language repos, absent git history — examples/recommendations would help

---

## Artifacts updated

**Core files:**
- `/Users/carlos.sobral/github-repos/ai-squad/README.md` — +155 lines (gates, tooling, metrics, brownfield sections)
- `/Users/carlos.sobral/github-repos/ai-squad/CLAUDE.md` — +10 lines (clarified skills, structure, plan status)

**Output location:**
- `/Users/carlos.sobral/github-repos/ai-squad/docs/agents/tech-writer/2026-04-15-readme-claude-sync.md` (this file)

---

## Quality checklist

- [x] Intro reflects 2 skills (was 1)
- [x] All 4 software-architect modes documented
- [x] All 3 cloud-architect modes documented
- [x] Product designer modes clarified (greenfield vs brownfield)
- [x] Gates documented (clarify + consistency-check + observability)
- [x] Tooling block pattern documented with link to providers doc
- [x] Engineering metrics section added (collect.sh + maturity rubric)
- [x] Brownfield flow documented (link to `/onboard-brownfield`)
- [x] FAQ updated to distinguish greenfield vs brownfield paths
- [x] Project structure updated (scripts/, templates/docs/, docs/integrations/)
- [x] Improvement plan status updated (brownfield work complete)
- [x] Portuguese (BR) consistency maintained
- [x] Links to relevant docs verified (engineering-metrics-providers.md, onboard-brownfield/SKILL.md)
- [x] No hardcoded paths (all use relative repo structure)

---

## Notes for Tech Lead

1. **README is now 450+ lines** — consider if subsections should be broken into separate docs (e.g., `GATES.md`, `TOOLING.md`)

2. **Item 2 in Improvement Plan** is now "Aguardando priorização" — greenfield template copy is manual but straightforward; brownfield flow is fully automated. Revisit only if many devs stumble on the manual step.

3. **Item 4 renamed** to clarify it's greenfield-only — brownfield is 100% covered. QUICKSTART.md would help new users get to first module faster (estimate: 5 hours to write + test).

4. **Brownfield skill is production-ready** — deployed and tested. All adaptations gated on `codebase_age: brownfield` in CLAUDE.md ## Tooling block; greenfield path unchanged.

5. **Next doc sync should check:**
   - New QUICKSTART.md (if written)
   - Any new provider recipes added to `docs/integrations/`
   - Maturity rubric evolution after first brownfield audit cycle
