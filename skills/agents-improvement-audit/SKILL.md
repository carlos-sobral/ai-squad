---
name: agents-improvement-audit
description: "Observes the health of the auto-research loop across all ai-squad agents over time. Reads run logs, eval score trends, accept/reject patterns, source quality, and drift indicators. Produces a digest of operational findings and applies a narrow set of T1 tuning changes (only purely additive — never loosens guards). Escalates everything else as recommendations. Use when triggered by sdlc-orchestrator heuristics, when the user types /agents-improvement-audit, or when the user wants a periodic check on whether the self-improvement mechanism is producing value or noise."
---

You are running a structured audit of the **auto-research loop's health** across all ai-squad agents.

This is meta-observation: you do **not** critique any agent's domain output. You observe whether the SELF-IMPROVEMENT MECHANISM is producing value, regressing, drifting, or wasting cycles. The skill is intentionally conservative — most findings escalate to the user. Only purely additive query tuning is auto-applied.

---

## Inputs

The user invokes with:
- `/agents-improvement-audit` — full audit (default window: last 30 days)
- `/agents-improvement-audit --since=YYYY-MM-DD` — audit since a specific date

---

## Pre-flight

Stop and report if any check fails.

1. `~/.claude/agents/` is a git repo (required for the auto-research mechanism)
2. `~/.claude/logs/auto-research/` exists with **at least 5 total run logs** across all agents — auditing too little data produces noise, not signal. If under 5, return "insufficient data — wait for more auto-research runs" and exit cleanly
3. Compute window start (`--since` arg or default 30 days ago)
4. The working tree of `~/.claude/agents/` is clean enough to make focused commits — if dirty with unrelated changes, ask before proceeding

---

## What you read

For each agent in `~/.claude/agents/*.md` whose `Auto-Research Scope > enabled` is `true`:

1. Log files in `~/.claude/logs/auto-research/` matching the agent within the window
2. Git history of the agent file: `git -C ~/.claude/agents log --since={start} --pretty=format:'%H %s' -- {agent}.md`
3. Current state of the agent file (size, section structure, current `Auto-Research Scope` topics)

---

## What you analyze

### A. Run statistics per agent
- Total runs, commits (auto-commit), proposes (uncommitted left for user), reverts, no-ops
- Average baseline score, average post-edit score
- Score trend: rising / flat / falling
- Time since last run (gaps in scheduling are themselves a signal)

### B. Topic productivity
For each topic in the agent's `Auto-Research Scope > topics`:
- Percentage of runs that produced eligible findings from this topic
- Topics empty for **5+ consecutive runs** → tuning candidate (T1)
- Topics empty for **15+ consecutive runs** → disable candidate (T3, escalate)

### C. Source quality
- Domain-frequency of cited sources across the window
- Authoritative sources (OWASP, NIST, MITRE, official vendor docs, RFCs, accepted academic venues) vs casual (blog posts, social media, marketing)
- Flag any agent where >40% of recent sources are non-authoritative (T3, escalate)

### D. Drift indicators
- Agent file size growth rate (lines added per week)
- Constraint violations attempted per log (rejected by the auto-research skill itself)
- Editable section size growth — proxy for mandate scope creep (T3, escalate if any section grew > 50% in window)

### E. Cross-agent signals
- Same source URL cited convergently by 2+ agents → convergence (good — surface as positive finding)
- Edits in domains where agent mandates overlap producing contradictory guidance → ALERT (T3, escalate with file:line refs)

### F. Eval health
- Eval cases that fail reproducibly across runs → stale or actually broken (T3, escalate for review)
- Cases where post-edit score consistently >= baseline + 0.1 across 5+ runs → opportunity to raise threshold (T3, escalate)
- Cases where baseline score occasionally drops below the agent's `pass_threshold` → instability signal (T3, escalate)

---

## T1 actions (auto-apply, narrow scope)

**Only these mutations.** They never loosen any guard.

### T1.A — Broaden empty topic queries
If a topic has been empty for 5+ consecutive runs but its declared `why` is still relevant to the agent's domain, **add** a more general query alongside the existing narrow ones. **Do not remove queries.** Cite the rationale in the commit message.

### T1.B — Add a complementary query
If your audit surfaced a query pattern that's been productive in adjacent topics or other agents' related topics, **add** it to the underperforming topic. Additive only.

### Application rules
For every T1 change:
1. Make the edit in the agent file via the `Edit` tool
2. Commit immediately: `git -C ~/.claude/agents add {agent}.md && git commit -m "agents-improvement-audit: T1 — {what} ({why-1-line})"`
3. **Hard cap: 3 T1 changes per run** — the rest queue for next audit

---

## T3 escalation list (write to digest, do NOT apply)

Collect these into the digest. Each entry includes file:line refs (when applicable) and a rationale.

- Threshold change candidates (eval scores justify raising `pass_threshold`)
- Policy promotion candidates (agent ran `propose` for 5+ runs without user rollback)
- Topic disable candidates (empty for 15+ runs)
- Topic split candidates (one topic produces too many overlapping findings)
- Eval case review candidates (failing reproducibly with a consistent pattern)
- Cross-agent contradictions
- Source quality concerns
- Mandate scope creep alerts

**Never auto-apply any of these.** They affect the safety mechanism itself; bad autonomous changes here would silently degrade quality across all agents.

---

## Versioning

Before any T1 mutation:
```
git -C ~/.claude/agents tag pre-agents-improvement-audit-{YYYYMMDD-HHMM}
```

After all T1 mutations (even if 0):
```
git -C ~/.claude/agents tag post-agents-improvement-audit-{YYYYMMDD-HHMM}
```

Document rollback in the digest output, exact command included.

---

## Output

Write a digest to `~/.claude/logs/agents-improvement-audit/{YYYY-MM-DD}.md`:

```markdown
---
date: YYYY-MM-DD
window_start: YYYY-MM-DD
agents_audited: N
total_runs_in_window: N
t1_applied: M
t3_escalated: K
checkpoint_pre: pre-agents-improvement-audit-{ts}
checkpoint_post: post-agents-improvement-audit-{ts}
---

## Per-agent summary
| agent | runs | commits | proposes | reverts | no-ops | baseline avg | post-edit avg | trend |
|---|---|---|---|---|---|---|---|---|
| ... | | | | | | | | |

## Topics needing attention
| agent | topic | runs empty | recommendation | tier |
|---|---|---|---|---|

## Source quality concerns
[per-agent breakdown when authoritative-source ratio < 60%]

## Drift indicators
[agents with file size or section growth above threshold]

## Cross-agent signals
### Convergence (positive)
- [source URL] cited by [agent A, agent B] in [topic A, topic B] — converging on [observation]

### Contradiction (alert)
- [agent A {file:line}] vs [agent B {file:line}] — [contradiction description]

## Eval health
[per-agent eval observations]

## T1 applied (auto-committed)
- {agent}: {what} — {commit sha}

## T3 escalations (require your decision)
### {kind} — {agent}
**Detail:** [refs]
**Recommendation:** [specific action]
**Rationale:** [why now]

## Rollback
git -C ~/.claude/agents reset --hard pre-agents-improvement-audit-{ts}
```

After writing the digest, surface a 5-line summary in the conversation:
```
agents-improvement-audit complete:
- N agents audited, M T1 changes auto-applied, K T3 items escalated
- {brief health summary in one sentence}
- Top escalation: [the most important one in 1 line]
- Full digest: ~/.claude/logs/agents-improvement-audit/{date}.md
- Rollback if needed: {git command}
```

---

## Hard rules

- **Never** edit anything other than `topics[].queries` in T1 mode
- **Never** disable a topic, change a threshold, promote a policy, or edit an eval case in T1 — these always escalate
- **Never** edit any section other than the agent's `Auto-Research Scope` block
- **Never** remove existing queries — only add to them
- **Always** include rationale (why this tuning) in the commit message
- **Always** cite file:line references for every T3 escalation that points at specific content
- **If insufficient data** (< 5 total runs across all agents), exit cleanly without creating a digest — auditing 1-2 runs produces noise

---

## Failure modes to watch

- **All agents trending flat at perfect score:** likely the eval cases are too easy, not that the agents are perfect. Surface as T3.
- **Consistent reverts on one agent:** the eval is doing its job, but research is producing low-quality findings. Surface the topic-level rejection patterns as T3.
- **No findings ever from a topic that gets queries every day:** queries may be over-specified or the domain is genuinely stable; T1 broaden once, then if still empty, T3 disable.
