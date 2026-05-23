---
name: systematic-debugging
description: Use when an agent encounters a test failure, bug, unexpected behavior, build failure, or performance regression and is tempted to propose a fix before fully understanding the root cause
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues and ship them downstream as someone else's regression.

**Core principle:** find the root cause before proposing any fix. Symptom fixes are not fixes — they are debt with a UI on top.

**Invoked by:** `qa-engineer` when a test fails during E2E verification, `backend-engineer` / `frontend-engineer` when implementation hits unexpected runtime behavior, or directly by the Tech Lead investigating a production bug. Not auto-triggered — the calling agent decides to reach for this skill and announces it.

## The Iron Law

```
NO FIX PROPOSALS BEFORE PHASE 1 IS COMPLETE
```

If you haven't read the error in full, reproduced the failure, checked recent changes, and traced the data path to where it actually breaks, you don't have a root cause — you have a guess. Guesses go in the rationalization table, not in the fix commit.

## The four phases

Complete each phase before moving to the next. Skipping ahead is the failure mode this skill exists to prevent.

### Phase 1 — Root cause investigation

Before proposing any fix:

1. **Read the error completely.** Stack trace, file paths, line numbers, error codes. The literal error text frequently names the fix. Don't paraphrase the error in your head — read it.
2. **Reproduce consistently.** What exact steps trigger it? Every time, or intermittent? If you can't reproduce, you can't fix — gather more data first.
3. **Check recent changes.** `git log --oneline -10`, `git diff HEAD~5`, dependency bumps, config changes, environmental differences (Node version, env vars, OS). Recent change correlation is the cheapest hypothesis source.
4. **Gather evidence at component boundaries** (when the system has multiple layers — CI → build → sign, API → service → DB, frontend → IPC → backend). Instrument BEFORE proposing fixes:
   - Log what enters each component
   - Log what exits each component
   - Verify env/config propagation across boundaries
   - Run once to see WHICH boundary fails, then investigate that specific one
5. **Trace data flow backward.** When the bad value appears deep in the stack, walk upward: where did this value originate? What called this with the bad value? Keep tracing until you find the source. Fix at the source — never at the symptom.

### Phase 2 — Pattern analysis

Before forming a hypothesis:

1. **Find working examples in the same codebase.** Similar code that DOES work tells you what the broken code is missing.
2. **Read reference implementations completely.** If you're applying a documented pattern (framework idiom, library example), read it end-to-end — don't skim. Partial reads cause silent miscopies.
3. **List every difference between working and broken.** Every difference, however small. "That can't matter" is the phrase that precedes the fix.
4. **Map dependencies.** What other components, env vars, configs, assumptions does this code rely on? Missing context is invisible until it bites.

### Phase 3 — Hypothesis and minimal test

1. **State one hypothesis explicitly.** "I think X is the root cause because Y." Written down. Specific, not vague.
2. **Test minimally.** The smallest possible change that would falsify the hypothesis. One variable at a time. Don't fix three things at once and lose the signal.
3. **Verify before continuing.** Worked → Phase 4. Didn't work → form a NEW hypothesis from scratch. Never pile fixes on top of an unconfirmed hypothesis.
4. **Say "I don't know" when you don't.** Pretending costs more than asking. Research more or ask the Tech Lead.

### Phase 4 — Fix and verify

1. **Write the failing test first.** Smallest possible reproduction. Automated when the framework allows; one-off script when it doesn't. The test must FAIL with the bug present — that proves it actually exercises the code path.
2. **Implement one fix.** Address the root cause, not the symptom. One change at a time. No bundled "while I'm here" improvements — those go in a separate commit if they're worth doing at all.
3. **Verify the fix.** Test passes? No other tests broken? Issue actually resolved (not just suppressed)?
4. **If the fix doesn't work, stop.** Don't pile fix #2 on top. Return to Phase 1 with the new information. Count attempts.
5. **If 3+ fixes failed, question the architecture.** When each fix reveals a new symptom in a different place, the bug isn't local — the pattern is wrong. Stop trying to patch. Surface the architectural question to `software-architect` and the Tech Lead before attempting fix #4.

## Red flags — stop and return to Phase 1

If you catch yourself thinking any of these, you're skipping the process:

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- "Pattern says X but I'll adapt it differently"
- "Here are the main problems: [proposes 3 fixes without investigation]"
- "One more fix attempt" (after 2+ already failed)
- Each fix reveals a new symptom in a different file/component

All of these mean: return to Phase 1.

## Common rationalizations

| Excuse | Reality |
|---|---|
| "Issue is simple, skip the process" | Simple bugs have root causes too. Process is FAST for simple bugs — that's the point. |
| "Emergency, no time for process" | Systematic debugging is faster than guess-and-check thrashing. Always. |
| "I'll write the test after the fix is confirmed" | Untested fixes don't stick. Test-first proves the fix actually addresses the symptom. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "Reference is too long, I'll adapt the pattern" | Partial reads guarantee miscopies. Read the whole thing. |
| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question the pattern; don't fix again. |

## Quick reference

| Phase | Key activity | Exit criterion |
|---|---|---|
| 1. Root cause | Read errors, reproduce, check changes, gather evidence, trace backward | Understand WHAT broke and WHY |
| 2. Pattern | Find working examples, compare, list differences | Identify the specific divergence |
| 3. Hypothesis | State one theory, test minimally | Theory confirmed OR new theory needed |
| 4. Fix | Write failing test, fix root cause, verify | Test passes, no regressions, bug actually gone |

## When the process reveals "no root cause"

If a complete investigation shows the issue is genuinely environmental, timing-dependent, or external (flaky network, race in a third-party library, hardware quirk):

1. Document what you investigated (the negative result is data)
2. Implement appropriate handling (retry with backoff, timeout, clear error message, monitoring hook)
3. Add a regression test if the failure mode is reproducible at all

**Important:** roughly 95% of "no root cause" claims are incomplete investigations. Before declaring environmental, ask the Tech Lead to sanity-check the trace.

## Interaction with other agents/skills

- **Failing test as proof:** Phase 4 step 1 (write the failing test first) follows the same discipline as the test-first technique in `backend-engineer` / `frontend-engineer` prompts.
- **Verification before claiming done:** Phase 4 step 3 (verify the fix) is governed by the `Operational guardrails → Verification before completion claims` section in the global `~/.claude/CLAUDE.md`.
- **Architectural escalation:** Phase 4 step 5 escalates to `software-architect`, not to a parallel debugging agent. Architecture is a single-owner decision.

## Real-world impact

From observed debugging sessions:
- Systematic approach: 15-30 minutes to a confirmed fix
- Random-fix thrashing: 2-3 hours, frequently introducing new bugs
- First-time-fix rate: ~95% systematic vs ~40% guess-and-check
- New bugs introduced: near zero systematic vs common with guess-and-check
