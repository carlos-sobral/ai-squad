---
name: onboard-brownfield
description: "One-shot onboarding of ai-squad on a pre-existing codebase. Inventories the repo (stack, CI, conventions, hotspots, maturity), produces baseline docs (CLAUDE.md, ADR, engineering-patterns.md, maturity-assessment.md), and surfaces TO DEFINEs that block the first module. Use whenever the user opens Claude in an existing codebase that lacks a CLAUDE.md, says 'onboard this repo', types '/onboard-brownfield', 'I want to start using ai-squad here', or mentions a pre-existing project that needs setup — run once per repo, before /sdlc-orchestrator."
---

You orchestrate the brownfield onboarding flow. You do NOT do discovery yourself — you spawn `software-architect` (Mode 4: Discovery) and `cloud-architect` (Mode 3: Inventory) in parallel via a `discovery-team`, then surface the result to the Tech Lead.

## When to run

- Once per repo, on first install of ai-squad in a pre-existing codebase
- NOT on greenfield projects — `/sdlc-orchestrator` already handles those
- NOT after `/sdlc-orchestrator` has already run a module — the artifacts you produce would conflict

## Prerequisites

- Repo is a git repository (`git rev-parse --git-dir` succeeds)
- At least one of: a manifest file (`package.json`, `pyproject.toml`, `Gemfile`, `go.mod`, `pom.xml`, etc.) OR `README.md` is present
- Current working directory is the repo root

If any prerequisite fails, stop and tell the Tech Lead exactly what's missing.

## Steps

1. **Check for existing CLAUDE.md.** If `CLAUDE.md` exists at the repo root, ask the Tech Lead whether to overwrite. If they decline, stop.

2. **Copy templates from ai-squad install.** Copy `templates/CLAUDE.md` (from the ai-squad install location, typically `~/.claude/` or wherever `install.sh` was sourced) to `./CLAUDE.md`. Copy `templates/docs/maturity-assessment.md` to `./docs/maturity-assessment.md`. Create the `./docs/onboarding/` and `./docs/adr/` directories if missing.

3. **Create the discovery team.**
   ```
   TeamCreate({ team_name: "discovery-team", layout: "tiled" })
   ```

4. **Spawn both agents in parallel** (single message, two `Agent` calls):
   - `Agent({ subagent_type: "software-architect", team_name: "discovery-team", name: "discovery", model: "opus", prompt: "Run Mode 4: Discovery on the current repo (cwd). Output to the files specified in your agent definition: CLAUDE.md (fill Stack + Tooling slots you can infer + project_context block), docs/architecture.md, docs/adr/0001-baseline.md, docs/engineering-patterns.md, docs/maturity-assessment.md (fill Brownfield baseline row), docs/onboarding/discovery-report.md. Mark every uncertain inference as [TO DEFINE]. Critical TO DEFINEs (auth, multi-tenancy, secrets, data retention) go at the top of discovery-report.md. Do NOT write code, do NOT open a PR, do NOT refactor." })`
   - `Agent({ subagent_type: "cloud-architect", team_name: "discovery-team", name: "inventory", model: "sonnet", prompt: "Run Mode 3: Inventory on the current repo (cwd). Populate ## Tooling > ci_cd in CLAUDE.md with the provider and workflow files detected. Populate ## Tooling > observability if obs deps detected; mark [TO DEFINE] if ambiguous. Append an Infrastructure baseline block to docs/adr/0001-baseline.md (the file is created by software-architect; append, do not overwrite). Do NOT create new infrastructure. Do NOT run setup mode. If CI is missing, just note it in the Infrastructure baseline." })`

5. **Wait for both to complete.**

6. **Detect UI presence.** Check for `*.tsx`, `*.vue`, `*.svelte`, or `*.html` files under `src/`, `app/`, or `components/`. If found, note it for the next-steps section.

7. **Shut down teammates.**
   ```
   SendMessage({ to: "discovery", type: "shutdown_request" })
   SendMessage({ to: "inventory", type: "shutdown_request" })
   TeamDelete({ team_name: "discovery-team" })
   ```

8. **Read** the produced `docs/onboarding/discovery-report.md` to extract the critical TO DEFINEs.

9. **Present the summary to the Tech Lead** (see Output format below).

## Output to the Tech Lead

```
## Brownfield onboarding complete

Files created:
- CLAUDE.md (project_context.codebase_age: brownfield)
- docs/architecture.md
- docs/adr/0001-baseline.md
- docs/engineering-patterns.md
- docs/maturity-assessment.md (auto-claimed: <list of dimensions>)
- docs/onboarding/discovery-report.md

Critical TO DEFINEs (resolve before first module):
- [list extracted from discovery-report.md top section]

Non-critical TO DEFINEs (resolve in next 2 weeks):
- [count] items in docs/onboarding/discovery-report.md

Next steps:
1. Resolve the critical TO DEFINEs above (edit CLAUDE.md and engineering-patterns.md)
2. (If UI present) Run product-designer in design-system-extract mode
3. Run /sdlc-orchestrator to start your first module
```

## Hard constraints

- Do NOT invoke `/sdlc-orchestrator` automatically
- Do NOT run `cloud-architect` setup mode, even if CI is missing — only signal it in the report
- Do NOT spawn `discovery` and `inventory` as loose background subagents — they MUST be teammates inside `discovery-team`
- Do NOT skip the shutdown + TeamDelete cleanup

## Expected wall-clock time

≤30 minutes total: ~5 min agent execution + ~15 min Tech Lead review + ~10 min resolving critical TO DEFINEs. If discovery is taking longer, the repo is likely large/exotic — recommend running again with `--depth shallow` on the agent prompts.
