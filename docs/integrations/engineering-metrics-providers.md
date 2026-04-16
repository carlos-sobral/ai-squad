# Engineering Metrics — Provider Recipes

The ai-squad framework reads `engineering_metrics.provider` from the project's `CLAUDE.md > ## Tooling` block. Swapping providers is a one-line change. This doc gives concrete recipes for each supported provider so you can move from the default (`ai-squad-local`) to a tool of your choice when the squad outgrows it.

**Decision matrix (start here):**

| You are... | Use |
|---|---|
| Solo dev or squad ≤ 2 | `ai-squad-local` (default) |
| Squad 3-10, want DORA + flow without paying | `devlake` (self-hosted) or `github_actions_native` |
| Squad already pays LinearB/Jellyfish/Swarmia | plug it in via the relevant adapter |
| You only care about DORA + already on GitHub | `github_actions_native` |

Adapter contract is the same regardless of provider: agents read `provider` and `config`; nothing else changes.

---

## Provider 1 — `ai-squad-local` (default)

**When to use.** Solo dev, squad ≤ 2, projects where source code privacy matters more than dashboards. Zero external dependencies, zero cost.

**`## Tooling` block:**

```yaml
engineering_metrics:
  provider: ai-squad-local
  config:
    script: scripts/metrics/collect.sh
    output: docs/metrics/latest.md
```

**Setup.** Install the script (already in the ai-squad repo) and run it manually or in CI:

```bash
bash scripts/metrics/collect.sh --window 30d
```

**What it covers.** All 9 ai-squad metrics (lead time, CFR, rework rate, spec-fidelity, stage cycle time, agent coverage, retro→diff conversion, agent versioning, plus the ones you read from `docs/metrics/latest.md`). Reads `git log`, `gh pr list`, and frontmatter of `docs/agents/`.

**Gaps.** No web dashboard. No alerts on metric drift. No multi-repo aggregation.

**Cost.** $0. **Setup time.** < 10 min.

**Security note.** All processing local. `gh` CLI uses your existing GitHub auth; no third party sees anything.

---

## Provider 2 — `devlake` (self-hosted, open-source)

**When to use.** Squad 3-10 devs. You already have somewhere to run a Docker stack (homelab, small VPS, internal infra). You want a real dashboard for DORA + flow metrics across multiple repos, and you don't want to pay per-seat.

**`## Tooling` block:**

```yaml
engineering_metrics:
  provider: devlake
  config:
    api_url: http://devlake.local:8080/api
    project_name: ai-squad-projects
    dashboard_url: http://devlake.local:3002/d/dora
    # Optional: path where ai-squad collect.sh dumps a complementary
    # snapshot of agentic metrics that DevLake doesn't see.
    local_supplement: docs/metrics/latest.md
```

**Setup (skeleton — see [DevLake docs](https://devlake.apache.org/docs/QuickStart/LocalSetup) for full):**

1. `git clone https://github.com/apache/incubator-devlake && cd incubator-devlake/deployment/docker-compose`
2. `docker compose up -d` — brings up Postgres + Grafana + DevLake API
3. In the DevLake UI, create a project and add a GitHub data source (uses a personal access token, scope `repo`).
4. Configure scope: which repos to ingest. Trigger first sync (~10-30 min depending on history depth).
5. Open the bundled DORA dashboard in Grafana. That's your DORA snapshot.

**What it covers.** Lead time for change, deploy frequency, change failure rate, MTTR — across all repos you point it at. Cycle time per stage if you ingest the issue tracker too (Jira/GitHub Issues/Linear).

**Gaps.** **DevLake does not see `docs/agents/` or `docs/agent-evolution/`** — the agentic-specific family (rework rate, retro→diff, agent coverage, versioning velocity) is invisible to it. Recommended pattern: keep `ai-squad-local` `collect.sh` running too, and link its output (`docs/metrics/latest.md`) from your DevLake dashboard or alongside in your team space. The two are complementary, not competing.

**Cost.** $0 software + your hosting (homelab ≈ $0; small VPS $5-15/month; cloud Postgres adds ~$15-25/month if managed).

**Setup time.** ~1 day for a working dashboard, more if you want polished alerts/segmentation.

**Security note.** Uses GitHub PAT with `repo` scope (read all). Self-hosted means data stays in your infra. You own the Postgres — back it up.

**Migration from `ai-squad-local`.** Run both in parallel for 1 month. Validate that DORA numbers in DevLake match `collect.sh` output (they should, both read git). Once aligned, swap `provider: devlake` and keep `local_supplement` pointing at `collect.sh` output for the agentic family.

---

## Provider 3 — `github_actions_native`

**When to use.** You're already on GitHub, don't want to host anything, and only need DORA + lead time. No dashboard server. Output is a markdown file in the repo (or GitHub Pages).

**`## Tooling` block:**

```yaml
engineering_metrics:
  provider: github_actions_native
  config:
    workflow_file: .github/workflows/metrics.yml
    output: docs/metrics/latest.md
    # Optional: publish to GitHub Pages
    pages_branch: gh-pages
    pages_path: metrics/
```

**Setup.** Add a workflow that runs `collect.sh` on schedule and commits the output:

```yaml
# .github/workflows/metrics.yml
name: engineering-metrics
on:
  schedule:
    - cron: "0 6 * * 1"   # Monday 06:00 UTC
  workflow_dispatch:
permissions:
  contents: write
jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Install yq
        run: sudo snap install yq
      - name: Run collector
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: bash scripts/metrics/collect.sh --window 30d --quiet
      - name: Commit snapshot
        run: |
          git config user.name "metrics-bot"
          git config user.email "metrics-bot@users.noreply.github.com"
          git add docs/metrics/latest.md docs/metrics/history/
          git diff --cached --quiet || git commit -m "chore(metrics): weekly snapshot"
          git push
```

**What it covers.** Same 9 metrics as `ai-squad-local` (it literally runs the same script). Difference: scheduled, version-controlled history, optional Pages publishing.

**Gaps.** No live dashboard — output is markdown. No anomaly alerting (you can add a step that opens an issue if a threshold breaks).

**Cost.** $0 on public repos; included Actions minutes on private repos cover this easily (~30 sec/run, weekly = trivial usage).

**Setup time.** ~30 min.

**Security note.** Uses repo's built-in `GITHUB_TOKEN`. Stays inside GitHub. Nothing external.

**Migration from `ai-squad-local`.** This is `ai-squad-local` + automation. Switch when you stop wanting to remember to run the script.

---

## Provider 4 — `linearb` (commercial SaaS)

**When to use.** Your company already pays for LinearB. Don't sign up just for a personal project — it's enterprise-priced and asks for broad GitHub permissions.

**`## Tooling` block:**

```yaml
engineering_metrics:
  provider: linearb
  config:
    api_base: https://public-api.linearb.io/api/v1
    api_key_env: LINEARB_API_KEY        # never inline the key
    team_id: 42
    # Optional: keep the local supplement for agentic metrics LinearB
    # doesn't track (retro→diff, agent versioning, etc).
    local_supplement: docs/metrics/latest.md
```

**Setup.**
1. In LinearB UI, create an API token (scope: read team metrics).
2. Export `LINEARB_API_KEY` in your environment.
3. The agent's audit mode will hit `https://public-api.linearb.io/api/v1/measurements?team_id=...` and parse the response.

**What it covers.** Cycle time, lead time, deploy frequency, change failure rate, PR throughput, code review depth — across the team. Has a polished dashboard.

**Gaps.** Same as DevLake: doesn't see `docs/agents/` or learning-loop metrics. Same workaround — keep `local_supplement`.

**Cost.** Enterprise pricing (no public number; expect $20-50+/dev/month minimum). **Confirm pricing before adopting.**

**Setup time.** < 1 day if your org already has the contract.

**Security note.** SaaS. LinearB ingests commits, PRs, and issue data. Confirm your org has approved the data residency.

**Migration.** If your org pays for it and your squad uses ai-squad as a team augmentation, plug it in as the primary provider. Keep `collect.sh` running in CI to fill the agentic gap.

---

## Provider 5 — `none`

**When to use.** You explicitly don't want metrics collection. Maybe a throwaway prototype, or a private workflow exploration.

**`## Tooling` block:**

```yaml
engineering_metrics:
  provider: none
```

The orchestrator's retrospective gate Step 7 (maturity assessment) is skipped silently. The post-deploy health check still runs (it reads from `observability`, not from this slot).

---

## Choosing — quick decision flow

1. **Do you have a real squad (≥3 devs) and want a dashboard?**
   - Yes, and you can host: `devlake`
   - Yes, and you already pay LinearB/etc: that provider
   - No: stay on `ai-squad-local`
2. **Do you forget to run `collect.sh`?** → `github_actions_native`
3. **Personal project, just want the framework not to nag?** → `none`

When in doubt, start with `ai-squad-local`. Migration to any provider is one config line + (optionally) keeping the local supplement for the agentic-specific metrics that no SaaS sees.

---

## Adapter contract (for adding a new provider)

If you want to add a provider not in this list, the adapter contract is small:

- The agent (`performance-engineer` audit mode) reads `engineering_metrics.provider` and dispatches by name.
- For the new provider, you need:
  - A way to invoke collection: a `config.script` to run, a `config.cli` command, or a `config.api_url` to call.
  - A way to read the result: either the provider writes to `config.output` (markdown table), or the agent fetches and renders inline.
  - Optionally `config.local_supplement` pointing at `collect.sh` output for the agentic-specific metrics no external tool sees.
- Open a PR to ai-squad with: this doc updated + a section in `performance-engineer.md` describing how the new provider is dispatched.

The point of the adapter is that **the agent code does not change** — only the provider table grows.
