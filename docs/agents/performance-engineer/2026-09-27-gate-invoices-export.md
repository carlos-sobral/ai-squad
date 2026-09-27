---
skill: performance-engineer
date: 2026-09-27
mode: gate
task: "gate — invoices-export"
status: complete
verdict: BLOCKED (cannot evaluate — no CI output)
---

## Performance Report — invoices-export — 2026-09-27
**Mode:** gate
**Overall verdict:** BLOCKED — cannot evaluate (no CI output available)

### Missing measurement artifacts (first line of status)

**Missing artifact: CI performance output for `invoices-export`** — no Lighthouse report (JSON) and no load-test (k6/artillery) output exists for this module. A performance gate cannot be evaluated from measurements that do not exist, and this agent does not invent metrics. **Owner: Tech Lead** (action: wire Lighthouse CI + backend load test into the CI pipeline, or paste existing report JSON). **Proposed module target: `invoices-export`** — must be re-measured and re-dispatched to this gate with the CI output before shipping.

### Why this is a blocker, not a finding

- Gate mode requires CI-produced measurements under defined test conditions. "Works fast on my machine" is not evidence, and neither is this report.
- Severity semantics do not apply here: nothing breached a threshold because nothing was measured. Marking PASS would be fabrication; marking FAIL would falsely imply a threshold breach.

### Frontend

| Metric | Value | Threshold | Status |
|---|---|---|---|
| Lighthouse Performance | — | from CLAUDE.md | ❔ no CI output |
| LCP / INP / CLS | — | from CLAUDE.md | ❔ no CI output |
| Bundle size (initial JS) | — | from CLAUDE.md | ❔ no CI output |

### Backend

| Endpoint | p50 | p95 | p99 | Status |
|---|---|---|---|---|
| (endpoints touched by invoices-export) | — | — | — | ❔ no load-test output |

### Findings

- **Blocker (gate-level):** No Lighthouse report and no load-test output for `invoices-export`. Fix: run the module's CI performance suite (Lighthouse against the module routes; k6/artillery against the export endpoints), attach the JSON output to the dispatch, and re-run this gate. Do not merge the module under a gate verdict until then.

### Suggested alerts for this module (gate mode only)

Deferred — alerts must be grounded in a measured baseline (p95 response times, 5xx rates), which does not exist yet. Propose after the re-measurement.

### Notes for the re-run

- When CI output is available, confirm `git log --oneline -1` on the measured revision so results map to the right commit.
- If the export feature streams or generates large files, ensure the load test covers payload size for the export endpoints — large response bodies block rendering.
