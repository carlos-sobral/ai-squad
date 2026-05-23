# CLAUDE.md — [Project Name]

> This file tells Claude Code everything it needs to know about your project.
> Fill in the sections below. The more specific you are, the better the agents will work.
> Delete any section that doesn't apply to your project.

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

project_context:
  codebase_age: greenfield   # greenfield | brownfield
  legacy_coverage_baseline_pct: 0   # only meaningful when brownfield — coverage at onboarding; new code must not regress it
  hotspots_doc: null         # path to discovery-report when brownfield (e.g., docs/onboarding/discovery-report.md); null when greenfield
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
