---
skill: idea-researcher
date: 2026-09-27
task: Idea brief — CLI tool that reviews Terraform plans and comments cost estimates on the PR
status: complete
---

# Idea Brief: PlanCost — cost estimates on every Terraform PR

## Overview
PlanCost is a CLI tool (with a thin CI wrapper) that ingests `terraform plan` JSON output, computes the monthly cost impact per resource by mapping plan resources to cloud provider public pricing, and posts a Markdown comment on the pull request — total, delta vs the base branch, and per-resource breakdown. It puts cost review into code review, the one moment where an infrastructure change is still cheap to reject. Demand is validated: three teams confirmed the workflow gap. The open risk is not whether the problem is real — it is why this tool beats Infracost, whose free CLI already does much of this.

## Problem Statement
- **Who has this problem?** Platform/DevOps engineers who maintain Terraform (or OpenTofu) modules in git repos and own PR review; secondarily the engineering managers and FinOps owners accountable for the cloud bill those changes create.
- **What is the problem?** The cost impact of an infrastructure change becomes visible only after merge and apply — on the next invoice or a Budgets alert days later. Cost is the only review dimension (correctness, security, style) with no presence in the PR itself.
- **Why does it matter?** Overprovisioning and forgotten resources compound silently; the fix after apply costs engineering time and often real money. A $3k/mo change caught in review is a comment; caught at the invoice, it is a retro and a cleanup ticket.
- **Current workaround:** Nothing (surprise bill), after-the-fact Budgets/alerts, manual spreadsheets at planning time, or — for teams on paid tiers — HCP Terraform Enterprise's built-in cost estimation. Free-tier teams either wire up Infracost or live without it.

## Target Users

| User Type | Description | Key Goal | Main Pain Point |
|-----------|-------------|----------|-----------------|
| Primary | Platform/DevOps engineers reviewing Terraform PRs | See monthly cost delta of a change in the review surface, with zero extra tooling | Cost context lives outside the PR; running cost tooling manually is friction nobody sustains |
| Secondary | Eng managers / FinOps owners | Organization-wide cost discipline and enforcement (thresholds, "why is this PR +$2k/mo?") | No lever to make cost a first-class review criterion without buying a platform |

## Proposed Solution
A self-contained CLI that:
1. Accepts `terraform show -json <plan>` (and optionally HCL directly) as input.
2. Maps resource types to cloud provider public price books (AWS first; GCP/Azure later), covering the resource types that dominate real plans — start with the top ~20 (EC2, RDS, ALB, S3, EKS, CloudWatch, etc.).
3. Emits a Markdown cost comment: monthly total, **delta vs base branch**, per-resource table, and explicit flags for resources it could not price (no silent gaps).
4. Ships as one binary plus a copy-paste GitHub Action / GitLab CI job. No SaaS account, no pricing API keys, no infrastructure of ours.

Design principle: cost estimation from public data only, running where the CI runner already runs. Estimates are labeled as estimates (public pricing, no negotiated discounts) and the comment says so.

### Alternative Approaches Considered
- **Option A (chosen): independent open-source CLI on public price books** — full control, no vendor dependency, sells to the privacy/self-hosted segment. *Trade-off: estimate accuracy is limited to list prices; the pricing-data pipeline (price books change weekly) is ongoing maintenance we own.*
- **Option B: thin wrapper around Infracost** — fastest path to accurate estimates, battle-tested parser. *Trade-off: we build nothing defensible; we inherit Infracost's product boundary (its Cloud features — private pricing, policy/gating — are SaaS), and users can just use Infracost directly.*
- **Option C: account-credentialed estimator using negotiated pricing (CUR / billing exports)** — most accurate numbers, enables "real cost" not "estimate". *Trade-off: requires cloud credentials and org access in CI, heavier security review, much slower to v1; overkill for the primary use case (relative deltas in review).*

## Success Signals
- **Adoption:** the 3 validating teams run it on ≥80% of their Terraform PRs two weeks after install, and are still running it 60 days later (the classic fate of CI cost tools is silent disablement).
- **Accuracy:** posted deltas land within ±15% of actual invoice impact for covered resource types — tracked against a small sample of applied changes.
- **Review value:** reviewers cite the comment in review threads (e.g., "resize this before merge"); measurable drop in post-apply "what did this cost us" surprises reported by the pilot teams.
- **Coverage:** unpriced-resource flags trend toward zero for the pilot repos; top-20 resource types cover >90% of their plan lines.

## Open Questions & Assumptions
- [ ] **LEAP-OF-FAITH — the differentiation assumption.** The 3 teams' demand must be for *what Infracost's free CLI doesn't give them* (no SaaS, data stays in CI, extensible pricing, no Cloud upsell), not merely for *the category*. If Infracost free-tier as-is would satisfy them, this idea has no reason to exist. Validate first: ask each team specifically why Infracost doesn't already solve this for them.
- [ ] **Pricing-data freshness:** can public price books be kept current (weekly changes) without a hosted backend? Who updates them — automated pipeline vs. manual?
- [ ] **Gating or not:** does "comment only" satisfy the teams, or do they expect budget thresholds that fail the PR? Policy/gating roughly doubles scope and is exactly Infracost Cloud's paid territory — decide deliberately, don't drift into it.
- [ ] **Comment hygiene:** edit-in-place on force-push vs. new comment per run? Comment spam is a documented complaint about CI comment bots and can get the check muted by teams.
- [ ] **Resource coverage:** do the top ~20 AWS resource types cover >90% of the 3 teams' actual plan lines? Measure on their real repos before committing to a parser investment.

## Context & Research
- **Infracost** is the category default: parses plan JSON / HCL, maps resources to public price books, posts PR comments, and gates via policy. Its CLI is free; private pricing, dashboards, and governance live in **Infracost Cloud** (SaaS). This is simultaneously the proof the category works and the main competitive risk.
- **HCP Terraform / Terraform Enterprise** ships built-in cost estimation — paywalled, only relevant to existing TFC customers.
- **Open-source, no-backend alternatives** exist but are younger and less known: **OpenInfraQuote** (terrateamio — plan/state-based, no API keys), **Terracost** (Cycloid, Go library), **C3X** (markets itself explicitly as the "Infracost alternative without a SaaS"). The no-SaaS niche has at least three entrants in 2025–2026 — our wedge must be sharper than "self-hosted".
- **CI platforms** (Scalr, env0, Spacelift) bundle estimation modules — fine for teams already on those platforms.
- **Problem evidence:** sustained stream of setup tutorials and tool-comparison posts through 2026 (spendark, c3x.dev, cloudatler, oneuptime), plus recurring r/devops threads asking "how do you see infra cost before merge" — the problem is real and searches for alternatives are frequent.
- **Why now:** FinOps has gone mainstream and engineering orgs are increasingly pushed to own their cloud spend; at the same time, security/procurement pressure against sending infrastructure plans to third-party SaaS is rising, which is precisely the gap a CLI-only, public-data tool exploits.

---
*After the approval gate closes, use the `product-manager` skill to turn this brief into a full PRD with user stories and acceptance criteria.*
