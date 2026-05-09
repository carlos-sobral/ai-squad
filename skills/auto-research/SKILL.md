---
name: auto-research
description: "Runs the self-improvement loop for an ai-squad agent (manual invocation — no scheduler is installed). Reads the agent's Auto-Research Scope, fetches the latest authoritative sources for each topic, proposes edits to non-frozen sections, validates the change against the agent's Eval Suite, and either commits the improvement or reverts. Inspired by Karpathy's autoresearch pattern: editable asset (the agent prompt) + scalar metric (eval pass rate) + time-boxed cycle (one run per agent). Use when the user types /auto-research or asks to refresh an agent's knowledge."
---

You are running the **auto-research loop** for one agent in the ai-squad system. Your job is to refresh that agent's knowledge from authoritative public sources, validate the change against its Eval Suite, and either commit the improvement or revert.

This is a high-stakes operation: a bad edit silently degrades every future invocation of the agent. The Eval Suite is the gate that makes auto-commit safe. **Never bypass the eval.**

---

## Inputs

The user invokes this skill with an argument:

```
/auto-research {agent_name}
/auto-research all          # iterate over every agent in ~/.claude/agents/ that has Auto-Research Scope enabled: true
```

If no argument is provided, ask which agent to research (or `all`).

---

## Pre-flight checks

Before starting, verify all of the following. Stop and report if any fail:

1. The file `~/.claude/agents/{agent_name}.md` exists
2. The file contains a `## Auto-Research Scope` section with a YAML block where `enabled: true`
3. The file contains an `## Eval Suite` section with at least one case
4. **Each case has either `expect` or `rubric`, never both.** If a case has both, abort — the schemas are exclusive and mixing them is undefined.
5. **If any case uses `rubric`, the `Eval Suite > judge` field must be set** (e.g., `judge: claude-opus-4-7`). Rubric grading without a declared judge is undefined; abort.
6. **If `update_policy: auto-commit`, the Eval Suite must contain at least 3 cases.** Auto-commit with fewer cases lacks the statistical margin to detect regressions — abort and require either lowering the policy to `propose` or adding cases first.
7. `git` is available and the directory is clean enough to commit safely (no unrelated staged changes; if there are, ask before proceeding)
8. The user is not in the middle of another task that would conflict with the eval invocations

---

## The loop

Execute these steps in order. Each step has a clear stopping condition.

### Step 1 — Parse the agent's contract

Read `~/.claude/agents/{agent_name}.md` and extract:
- The full YAML block under `## Auto-Research Scope` (topics, frozen_sections, editable_sections, constraints, update_policy, optional `signal_sources`)
- The full YAML block under `## Eval Suite` (cases, pass_threshold, judge)

The optional `signal_sources` block declares which real-world signal sources Step 3a should mine. Example:

```yaml
signal_sources:
  - team_events           # .claude/team-events/**/events.jsonl
  - agent_evolution       # docs/agent-evolution/*.md filtered by agent
  - consistency_reports   # docs/agents/software-architect/*consistency*.md
  - metrics_history       # docs/metrics/history/*.md
  - git_failures          # revert/hotfix/fix commits in window
  # Optional per-agent project paths:
  # escaped_bugs_dir: docs/incidents
```

If `signal_sources` is absent, Step 3a is a no-op and the agent only learns from external sources.

Stop if either block is malformed. Do not attempt to fix YAML errors — report them and exit.

### Step 2 — Compute baseline eval score

Before any edit, run the Eval Suite on the **current** prompt to establish a baseline:

For each case in `Eval Suite > cases`:
1. Spawn the **agent under test** as a subagent (`Agent` tool with `subagent_type: {agent_name}`) and pass the case's `input` as the only diff/code to review. Frame the prompt so the agent treats it as a normal review request. This is the **doer**.
2. Capture the agent's output (the findings it produced).
3. **Grade the output.** A case has either `expect` (rule-based grading) or `rubric` (LLM-as-judge grading) — never both. Apply whichever is present:

   **Rule-based grading (`expect` block — default for binary, structured outputs):**
   - If `expect.severity` is set: the output must contain a finding at that severity level **and** the finding must cite at least one category from `expect.categories_any_of` (case-insensitive substring match).
   - If `expect.severity_max` is set: the output must contain **no** finding above that severity (used for clean-code false-positive cases).
   - If `expect.verdict` is set: the agent's verdict line must match (`approved`, `approved-with-conditions`, or `blocked`).
   - If `expect.verdict_contains` is set: the verdict line must contain that substring (case-sensitive).
   - If `expect.output_contains_any_of` is set: the output must contain at least one of the listed substrings (case-insensitive).
   - All applicable rules must hold for the case to pass.

   **LLM-as-judge grading (`rubric` block — for subjective outputs where rules don't fit):**
   - Spawn a **fresh subagent** as the **grader** (`Agent` tool with `subagent_type: general-purpose` or whatever the `Eval Suite > judge` field declares). The grader is a different invocation with **no access to the doer's thread or reasoning** — it sees only the doer's final output. This isolation is the entire point: the doer can't argue with its own grader.
   - The grader's prompt has exactly three parts: (a) the case input the doer was given, (b) the doer's output verbatim, (c) the case's `rubric.criteria` list. No other context.
   - Each criterion is phrased as a **specific, falsifiable question** (e.g., "Does the output identify the SQL injection on line 14?") — not a subjective question (avoid "is the response good?"). The grader returns one YES/NO per criterion plus a one-sentence reason.
   - The case passes if `count(YES) >= rubric.threshold` (default: all criteria must hold; explicit threshold optional).
   - The grader's full output (criterion-by-criterion verdicts + reasons) is appended to the run log so a human can audit any failed case.
4. Record `case_id → pass | fail`, the grading method used (`expect` or `rubric`), and the reasoning.

Compute `baseline_score = passed_cases / total_cases`.

If `baseline_score < pass_threshold`, **stop**. The agent is already failing its own eval, which means either the eval is broken or the prompt is broken — neither is something this skill should silently paper over. Log the failure and exit.

### Step 3 — Gather signals (real-world + external)

Two input streams feed this step. Run both, aggregate findings into a single list, then move to Step 4. External authoritative sources teach the agent about *what is changing in its domain at large*; real-world signals teach it about *what is going wrong (or working) in this specific project's actual use*. The first prevents staleness; the second prevents abstract drift.

#### Step 3a — Real-world signals from the project

If the agent's `Auto-Research Scope > signal_sources` block declares any of the sources below, gather signals from each. Skip any source not declared (or missing). This step is optional — agents without a `signal_sources` block skip it entirely and proceed to Step 3b.

**Available signal sources:**

| Source key | What you read | What you extract |
|---|---|---|
| `team_events` | `.claude/team-events/**/events.jsonl` from teams completed since the last auto-research run for this agent | recurring `blocked` events whose payload mentions topics in this agent's scope; `finding` events at severity `blocker`/`critical` |
| `agent_evolution` | `docs/agent-evolution/*.md` whose `agent:` frontmatter matches the agent under research | the "Rationale" section of each diff — these describe *why* a real blocker happened, the strongest possible signal for what the agent should learn |
| `consistency_reports` | `docs/agents/software-architect/*consistency*.md` since last run | (c) and (d) classified deviations — they point to spec→code gaps the agent could prevent |
| `metrics_history` | `docs/metrics/history/*.md` last 3 snapshots | metrics regressing in this agent's lane (e.g., rising rework rate for an implementation agent; rising CFR for a review agent) |
| `git_failures` | `git log --since="{since-last-run}" --pretty=format:%s` filtered by `^(revert|hotfix|fix)(\([^)]+\))?!?:` | commit subjects that mention topics in this agent's scope (e.g., for `security-engineer`, "fix(auth): ..." or "revert(jwt): ...") |
| `escaped_bugs` | `docs/incidents/*.md` or equivalent (path declared per project) | post-mortems whose root cause lands in this agent's domain |

**Extraction rules:**
1. Group signals by recurrence — a single occurrence is noise; **3+ occurrences of the same pattern across the window** is a finding worth proposing.
2. Each finding must cite at least one concrete file:line or commit SHA from the project (the project itself is the source — no external citation needed for these).
3. Real-world findings get priority over external findings when they overlap — concrete evidence beats abstract literature.

If a project does not yet have any of these data sources populated, this step is a no-op — the agent learns purely from external sources until usage history accumulates.

#### Step 3b — External authoritative sources

For each topic in `Auto-Research Scope > topics`:

1. Run a `WebSearch` for each query in `topic.queries`.
2. From the results, extract concrete, citable claims:
   - A new CVE with ID, affected component, CVSS score, and a public advisory URL
   - A new entry or a confirmed change to an OWASP / CWE / NIST publication, with the source URL and a quote of the change
   - A new attack pattern with at least one reputable source (academic paper, vendor security advisory, recognized researcher writeup) — **not** blog opinion or social media
3. Reject anything that fails the source quality bar set in `Auto-Research Scope > constraints`.
4. Aggregate findings per topic. If a topic produces no high-quality findings, skip it for this run — do not invent content.

### Step 4 — Propose edits

With the findings in hand:

1. Identify which `editable_sections` of the agent prompt should be updated. Map each finding to the most relevant section.
2. For each edit, produce a concrete diff (the exact `old_string` to find and the `new_string` to write).
3. Check every diff against `Auto-Research Scope > constraints`:
   - No edits to `frozen_sections` (reject the diff if it touches one)
   - No removal of existing checklist items
   - No severity downgrades without an authoritative source
   - Total net additions across all diffs ≤ 500 lines (per-run cap)
   - Every claim must have a citation in the diff itself
4. If no findings produce eligible diffs, log "no edits proposed" and exit cleanly. This is a normal outcome.

### Step 5 — Apply the edits

Use the `Edit` tool to apply each diff to `~/.claude/agents/{agent_name}.md`. Apply them in order. If any diff fails to apply (e.g., the surrounding text changed), abort the entire batch — do not partial-apply.

### Step 6 — Re-run the eval on the modified prompt

Repeat Step 2 with the now-modified agent file. Compute `new_score`.

### Step 7 — Decide and act

Apply this decision rule:

| Condition | Action |
|---|---|
| `new_score >= baseline_score` AND `new_score >= pass_threshold` | **Commit.** Run `git add ~/.claude/agents/{agent_name}.md` then `git commit -m "auto-research({agent_name}): {one-line summary of topics that produced findings}"`. The commit message body should list the topics with non-empty findings. |
| `new_score < baseline_score` OR `new_score < pass_threshold` | **Revert.** Run `git checkout -- ~/.claude/agents/{agent_name}.md` to restore the pre-edit state. Log the regression with details. |

Do not commit if `update_policy: propose` — instead, leave the diff applied (uncommitted) and present it to the user for review.

### Step 8 — Log the run

Write a structured log to `~/.claude/logs/auto-research/{YYYY-MM-DD}-{agent_name}.md`:

```markdown
---
agent: {agent_name}
date: {YYYY-MM-DD}
duration_seconds: {elapsed}
baseline_score: {0.00-1.00}
new_score: {0.00-1.00}
decision: committed | reverted | no-op | aborted
commit_sha: {sha or "n/a"}
---

## Topics researched
- {topic_name}: {N findings | no high-quality findings}

## Findings incorporated
- [{section name}] {short description of the change} — source: {URL}

## Eval results
| case_id | baseline | after edit |
|---|---|---|
| {case_id} | pass/fail | pass/fail |

## Reasoning
{one paragraph explaining the decision, including any constraint violations or quality concerns}
```

Create the log directory if it does not exist.

---

## Batch mode (`/auto-research all`)

When invoked with `all`:

1. List every file in `~/.claude/agents/*.md`
2. For each, parse the `## Auto-Research Scope` block. Skip files where the block is missing or `enabled: false`.
3. Run the full loop (Steps 1-8) for each eligible agent **sequentially**, not in parallel — concurrent edits to the agents directory plus concurrent git commits is a recipe for a tangled history.
4. After the last agent, write a roll-up summary to `~/.claude/logs/auto-research/{YYYY-MM-DD}-summary.md` listing each agent and its decision.

---

## Hard rules

- **Never** bypass the eval. If the eval is broken, fix the eval — do not commit prompt changes blind.
- **Never** edit a frozen section. The frozen list is the contract that the rest of the SDLC depends on.
- **Never** invent findings. If web search returns nothing of value, the run produces no edits — that is fine.
- **Never** make destructive git operations beyond `git checkout -- {single file}` for revert. No reset, no force, no branch operations.
- **Never** commit unrelated changes. If the working tree is dirty before the run, ask before proceeding.
- **Never** let the doer and the grader share context. When a case uses `rubric`, the grader must be a fresh subagent invocation seeded only with: the case input, the doer's output, and the rubric criteria. The grader does not see the doer's reasoning, the auto-research log, or the agent prompt. Sharing context defeats the entire purpose — the doer would effectively be grading itself.
- **Never** phrase a rubric criterion as a subjective question ("is this good?", "is the response high-quality?"). Every criterion must be a falsifiable yes/no question pointing at a specific, observable property of the output.
- **Always** include source URLs in the diff itself, not just the log.
- **Always** report regressions explicitly so the human can investigate why the new content degraded performance.
- **Always** log the grader's per-criterion verdicts when `rubric` was used, so a human can audit any failed case without re-running the eval.

---

## Failure modes to watch

- **Eval cases that drift out of date:** if the same case fails 3 runs in a row, surface a warning that the case may need updating (e.g., the agent legitimately changed how it formats severity and the eval grader is now matching the wrong string).
- **Baseline already below threshold:** indicates the agent is broken or the eval is broken; do not run research.
- **Web search returns the same content every day:** topic queries may be too narrow; surface as a hint to broaden them.
- **Constraint cap (500 lines) hit:** likely over-eager edits; reject and log so a human can review what was attempted.
- **Net no-op runs:** several days in a row with "no edits proposed" is healthy if the domain is stable, but if it persists for weeks, the topic queries may need refresh.
- **Rubric grader always says YES on every criterion:** likely the criteria are too easy or too vague — surface as T3 escalation candidate for the audit skill. A grader that never finds a problem is not validating anything.
- **Rubric grader produces wildly inconsistent verdicts on identical inputs across runs:** suggests the criteria are too subjective. Tighten the phrasing or move the case to `expect`-based grading.

---

## Eval Suite schema reference

A case uses **either** `expect` (rule-based) **or** `rubric` (LLM-as-judge) — never both. Choose based on the agent's output shape:

- **`expect`** — for agents whose output has structured, machine-checkable properties (severity levels, verdicts, named categories, presence of specific strings). Examples: `security-engineer` (finds-vuln-X-at-severity-Y), `performance-engineer` (verdict PASS/FAIL).
- **`rubric`** — for agents whose output is subjective enough that no rule can capture quality. Examples: `product-manager` (PRD completeness), `product-designer` (UX flow soundness), `software-architect` (tech-spec design quality).

```yaml
## Eval Suite

pass_threshold: 0.7
judge: claude-opus-4-7   # required when ANY case uses `rubric`

cases:
  # Rule-based grading (expect) — preferred when output has structure
  - id: sql-injection-detected
    description: "Agent must flag SQLi at high severity in injection-vulnerable code"
    input: |
      Review this Express handler:
      app.get('/users', (req, res) => {
        db.query(`SELECT * FROM users WHERE name = '${req.query.name}'`);
      });
    expect:
      severity: high
      categories_any_of: [injection, sqli, sql injection]

  # Rubric grading — for subjective outputs
  - id: prd-covers-edge-cases
    description: "PRD for refund flow must address the documented edge cases"
    input: |
      Write a PRD for a feature that lets users request a refund within 30 days
      of purchase, with manual review for refunds over $500.
    rubric:
      threshold: 3   # at least 3 of 4 criteria must hold; default = all
      criteria:
        - "Does the PRD enumerate at least one edge case for orders that would partially refund (e.g., used-in-part subscription, returned-after-30-days)?"
        - "Does the PRD specify what happens when manual review takes longer than the SLA?"
        - "Does the PRD declare which user role can initiate refunds (customer self-service vs. CS agent only)?"
        - "Does the PRD include success metrics for refund processing time?"
```

**Rubric design rules:**
- Phrase every criterion as a yes/no question pointing at a specific property of the output.
- Avoid "is the X good/clear/comprehensive?" — those are subjective and the grader's verdict will drift across runs.
- 3-6 criteria per case is the sweet spot. Fewer = the case grades too coarse. More = the grader's reliability degrades.
- The `threshold` is optional. If absent, all criteria must hold. Set explicitly when you want the case to be tolerant of one missing criterion.
