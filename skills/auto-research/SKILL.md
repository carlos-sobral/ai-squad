---
name: auto-research
description: "Runs the daily self-improvement loop for an ai-squad agent. Reads the agent's Auto-Research Scope, fetches the latest authoritative sources for each topic, proposes edits to non-frozen sections, validates the change against the agent's Eval Suite, and either commits the improvement or reverts. Inspired by Karpathy's autoresearch pattern: editable asset (the agent prompt) + scalar metric (eval pass rate) + time-boxed cycle (one daily run per agent). Use when the user types /auto-research, when a scheduler triggers it, or when the user asks to refresh an agent's knowledge."
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
4. `git` is available and the directory is clean enough to commit safely (no unrelated staged changes; if there are, ask before proceeding)
5. The user is not in the middle of another task that would conflict with the eval invocations

---

## The loop

Execute these steps in order. Each step has a clear stopping condition.

### Step 1 — Parse the agent's contract

Read `~/.claude/agents/{agent_name}.md` and extract:
- The full YAML block under `## Auto-Research Scope` (topics, frozen_sections, editable_sections, constraints, update_policy)
- The full YAML block under `## Eval Suite` (cases, pass_threshold, judge)

Stop if either block is malformed. Do not attempt to fix YAML errors — report them and exit.

### Step 2 — Compute baseline eval score

Before any edit, run the Eval Suite on the **current** prompt to establish a baseline:

For each case in `Eval Suite > cases`:
1. Spawn the target agent as a subagent (`Agent` tool with `subagent_type: {agent_name}`) and pass the case's `input` as the only diff/code to review. Frame the prompt so the agent treats it as a normal review request.
2. Capture the agent's output (the findings it produced).
3. Apply the case's `expect` rules to determine pass/fail:
   - If `expect.severity` is set: the output must contain a finding at that severity level **and** the finding must cite at least one category from `expect.categories_any_of` (case-insensitive substring match).
   - If `expect.severity_max` is set: the output must contain **no** finding above that severity (used for clean-code false-positive cases).
   - If `expect.verdict` is set: the agent's verdict line must match (`approved`, `approved-with-conditions`, or `blocked`).
   - All applicable rules must hold for the case to pass.
4. Record `case_id → pass | fail` and the reasoning.

Compute `baseline_score = passed_cases / total_cases`.

If `baseline_score < pass_threshold`, **stop**. The agent is already failing its own eval, which means either the eval is broken or the prompt is broken — neither is something this skill should silently paper over. Log the failure and exit.

### Step 3 — Research each topic

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
- **Always** include source URLs in the diff itself, not just the log.
- **Always** report regressions explicitly so the human can investigate why the new content degraded performance.

---

## Failure modes to watch

- **Eval cases that drift out of date:** if the same case fails 3 runs in a row, surface a warning that the case may need updating (e.g., the agent legitimately changed how it formats severity and the eval grader is now matching the wrong string).
- **Baseline already below threshold:** indicates the agent is broken or the eval is broken; do not run research.
- **Web search returns the same content every day:** topic queries may be too narrow; surface as a hint to broaden them.
- **Constraint cap (500 lines) hit:** likely over-eager edits; reject and log so a human can review what was attempted.
- **Net no-op runs:** several days in a row with "no edits proposed" is healthy if the domain is stable, but if it persists for weeks, the topic queries may need refresh.
