# CLAUDE.md — [Project Name]

> This file tells Claude Code everything it needs to know about your project.
> Fill in the sections below. The more specific you are, the better the agents will work.
> Delete any section that doesn't apply to your project.

---

## This project runs on ai-squad

> Keep this section. It is not a placeholder — it is the process contract for anyone,
> human or agent, who opens this repo.

This repo follows the [ai-squad](https://github.com/carlos-sobral/ai-squad) spec-driven SDLC:
specialized agents and skills installed in `~/.claude/agents/` and `~/.claude/skills/`.

**Entrypoint.** Every unit of work — feature, module, hotfix, spike — starts with
`/sdlc-orchestrator`. Do not start editing code from a loose chat request. The orchestrator
triages the work (T1/T2/T3) and decides which stages actually apply; a one-line fix does not
get a PRD, but the decision to skip is the orchestrator's, not an improvisation.

**Other entrypoints.** `/onboard-brownfield` (once per pre-existing repo, before anything else),
`/product-backlog` (what to build next and why this order), `/goal` (hand an in-flight goal to
autonomous execution once the early phases are done).

**Flow.** idea brief → PRD → UX spec → tech spec → implementation → review (architecture,
security, quality) → e2e QA → merge → retrospective. Each stage has an owning agent and
writes an artifact; the artifact is the handoff, not a chat summary.

**Non-negotiable gates.** These do not get skipped for speed:
- No implementation without an approved tech spec.
- No merge without review passing and e2e verification.
- Every completion claim quotes the command and its output. A subagent's "DONE" is a claim to
  verify, not evidence to relay.
- The retrospective runs at the end of a module — it is how the squad's own prompts improve.

**If the agents are not installed** (fresh machine, teammate's laptop, CI): clone ai-squad and
run `./install.sh`. Until then, follow the flow and the gates above manually — the process is
the contract, the agents are the accelerator.

**If this repo also has an `AGENTS.md`** for other tooling, point it at this file rather than
forking the process into two descriptions that drift.

---

## What is this project?

[One paragraph describing the product: what it does, who uses it, and why it exists.]

---

## Stack

| Layer | Technology |
|---|---|
| Framework | e.g. Next.js, Django, Rails, FastAPI |
| Language | e.g. TypeScript, Python, Ruby |
| Database | e.g. PostgreSQL, MySQL, MongoDB |
| ORM | e.g. Prisma, SQLAlchemy, ActiveRecord |
| Auth | e.g. Supabase Auth, Auth0, custom JWT |
| Styling | e.g. Tailwind CSS + shadcn/ui |
| Tests | e.g. Playwright, Vitest, pytest |
| Tests | (declared above) |

> **Note:** CI/CD, hosting, and external services are declared in the `## Tooling` block below — not here. The Stack table is for runtime tech (language/framework/DB/ORM); Tooling is for integrations (issue tracker, CI, observability, metrics, alerting).

---

## Tooling

> Centralized declaration of external services and integrations. Agents read from this block instead of assuming tools — swap a provider by editing one line. Use `none` to disable a slot. Add `config` keys as needed by each provider.

```yaml
issue_tracker:
  provider: github       # github | jira | linear | asana | none
  config:
    repo: org/repo
    cli: gh

repo_host:
  provider: github       # github | gitlab | bitbucket
  config:
    repo: org/repo

ci_cd:
  provider: github_actions  # github_actions | circleci | gitlab_ci | none
  config:
    workflow_file: .github/workflows/ci.yml

design_system_project_id: none   # UUID do design-system project deste repo no Claude Design, ou `none`
# Preenchido pelo product-designer no primeiro Design System Sync Mode (que cria o projeto).
# É a ÚNICA autoridade sobre o alvo de publicação: nome parecido não é posse, e a conta
# costuma ter starter kits e sistemas de terceiros. Cada projeto cria o seu.

chat:
  provider: none         # slack | discord | teams | none
  config:
    webhook_env: SLACK_WEBHOOK

engineering_metrics:
  provider: ai-squad-local  # ai-squad-local | devlake | linearb | sleuth | none
  config:
    script: scripts/metrics/collect.sh
    output: docs/metrics/latest.md

observability:
  product_analytics:
    provider: none       # posthog | mixpanel | amplitude | none
    config:
      query_cli: ""      # how to query — agents need this for post-deploy health check
  technical:
    provider: none       # otel+grafana_cloud | datadog | honeycomb | new_relic | none
    config:
      otel_endpoint_env: OTEL_EXPORTER_OTLP_ENDPOINT
  alerting:
    provider: none       # pagerduty | opsgenie | slack_webhook | discord_webhook | none
    config:
      channel: ""

  # Default thresholds applied when a module spec doesn't override
  defaults:
    error_rate_max_pct: 1
    latency_p95_ms: 500
    alert_quiet_hours: "00:00-07:00"

  # Required: condition that forces re-evaluation of the obs stack choice
  revisit_trigger: "monthly cost > $50 OR vendor lock-in concern"

environments:
  # Deploy topology. Declared in Módulo 0 by cloud-architect. Set staging.provider: none
  # for a single-target flow (merge → prod) and keep the orchestrator's staging gate dormant.
  # Declare a staging target to activate the staging validation gate
  # (merge → deploy staging → qa e2e + smoke on staging → gated promotion → prod).
  local:
    url: http://localhost:3000
  staging:
    provider: none        # the hosting platform's staging target | none
    url: ""               # staging base URL — qa-engineer points e2e here for the staging gate
    deploy_trigger: ""    # what deploys to staging (e.g. "merge to main")
  production:
    url: ""
  # Parity: what a staging build must mirror from prod for validation to be meaningful
  parity:
    data: synthetic       # synthetic | masked-prod-snapshot | none
    notes: ""             # known divergences staging does NOT mirror (3rd-party sandboxes, reduced infra, flags)
  # Promotion: how a validated staging build reaches production
  promotion:
    gate: manual          # manual | auto-on-green | none
    smoke_command: ""     # command/URL that proves staging is healthy before promotion

project_context:
  codebase_age: greenfield   # greenfield | brownfield
  legacy_coverage_baseline_pct: 0   # only meaningful when brownfield — coverage at onboarding; new code must not regress it
  hotspots_doc: null         # path to discovery-report when brownfield (e.g., docs/onboarding/discovery-report.md); null when greenfield

# Optional: external policy your org wants agents to enforce, without baking org-specific
# rules into the universal agent definitions. The review-team agent whose domain matches a
# source's `scope` loads it and treats its mandatory rules as ADDITIONAL gates (stricter wins;
# an unreachable mandatory source is a reported missing input, not a silent pass). Omit entirely
# if you have none — the framework runs exactly the same.
policy_sources: []
  # - name: org-security-rules
  #   scope: security        # security | architecture | infra | quality | docs
  #   location: ./docs/policy/security-rules.md   # path, repo, or URL the agent can read
  #   mandatory: true
```

---

## Project structure

```
/
├── [describe your main folders here]
```

---

## Code conventions

### API Routes

[Describe the pattern your API routes follow. Example:]
- Auth: all routes check for a valid session before anything else
- Error format: `{ "error": { "code": "snake_case", "message": "Human readable" } }`
- Response keys: collections use plural (`users`), single resources use singular (`user`)

### Naming

[Any naming conventions that matter: file names, function names, variable names.]

### Tests

[Where tests live, what framework is used, what needs to be tested.]

---

## Authorization rules

[How your app handles multi-tenancy or user isolation. Example:]
- Every database query must filter by `organizationId`
- `organizationId` is always read from the authenticated session — never from the request body

---

## What NOT to do

[Hard constraints agents must never violate. Example:]
- Never use floating-point for monetary values — always use Decimal
- Never store uploaded files — process in memory and discard

---

## Agent behavioral principles

Four operating principles that apply to every agent working in this project. They override speed and the temptation to "just ship it".

### 1. Understand before changing

Before touching code, the agent must be able to state — in its own words — what the user actually wants and what success looks like. If the request is ambiguous, ask a clarifying question instead of guessing. A guess that compiles is still a guess.

Signals you skipped this step: you reach for a file before you can describe the goal in one sentence, or you start editing and discover halfway through that the requirement was different.

### 2. Simplest thing that works

Default to the smallest change that solves the stated problem. No speculative abstractions, no "while we're here" cleanups, no framework introduced for a future need that hasn't been described. Three explicit lines beat a clever helper that hides two of them.

If a more general design is genuinely needed, the agent says so explicitly and asks before introducing it.

### 3. Surgical changes

Touch only the code the task requires. Don't rename unrelated variables, don't reformat untouched files, don't refactor in passing. Each unrelated change widens the blast radius, adds noise to the diff, and forces the reviewer to verify things outside the original scope.

If you find adjacent code that's genuinely broken, surface it as a follow-up — don't bundle the fix.

### 4. Verify before claiming done

Define what "done" looks like before starting (a passing test, a working flow, a clean build) and run that exact check before reporting success. "Should work" and "looks right" are not verification. The check goes in the same message as the claim, with the actual output quoted.

This applies to results from subagents too: a subagent reporting "DONE" is a claim to verify, not evidence to relay.

---

## Agent Outputs

Agent outputs are saved here as a log of what was built and when.

<!-- Agents append entries here automatically -->
