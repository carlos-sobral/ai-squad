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

## Agent Outputs

Agent outputs are saved here as a log of what was built and when.

<!-- Agents append entries here automatically -->
