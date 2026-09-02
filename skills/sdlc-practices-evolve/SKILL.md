---
name: sdlc-practices-evolve
description: "Observes coverage of practices in the SDLC vs the wider universe of known practices in each agent's domain. Researches state-of-the-art per discipline (QA, performance, security, architecture, docs, etc), identifies gaps, applies T1/T2 changes within bounds, and escalates T3 structural changes for user decision. Distinct from auto-research: that improves DEPTH (each agent at what it already does); this improves SCOPE (questioning whether the agent is doing the right things). Use when triggered by sdlc-orchestrator, when the user types /sdlc-practices-evolve, or when the user wants to question whether the SDLC has blind-spot disciplines."
---

You are running a **structural audit of the SDLC's practice coverage** and applying bounded evolutions where safe.

This skill questions WHAT the system does, not HOW WELL. For each agent, it asks: "what is the wider universe of practices in your domain, and what subset are you currently doing?" Gaps that fit within existing structure are auto-applied (T1/T2). Gaps that change structure are escalated (T3).

This is **breadth/scope evolution** — the complement to `auto-research` (which is depth evolution within an agent's existing mandate). Do not collapse the two.

---

## Inputs

- `/sdlc-practices-evolve` — full run with default cap (5 changes)
- `/sdlc-practices-evolve --cap=N` — change per-run cap
- `/sdlc-practices-evolve --t1-only` — conservative mode (used during cooldown)
- `/sdlc-practices-evolve --agent={name}` — restrict to one agent

---

## Pre-flight

Stop and report if any check fails.

1. **Both repos initialized:**
   - `~/.claude/agents/` is a git repo (already exists from auto-research setup)
   - `~/.claude/skills/` is a git repo — if not: `git -C ~/.claude/skills init -b main && git add -A && git commit -m "snapshot before first sdlc-practices-evolve"`

2. **Cooldown check:** read `~/.claude/logs/sdlc-practices-evolve/last-run.json`. If `decision == "rolled-back"` for the most recent run, **force `--t1-only` mode**. Announce this in the run output so the user knows they're in cooldown.

3. **Tag both repos:**
   ```
   TS=$(date +%Y%m%d-%H%M)
   git -C ~/.claude/agents tag pre-sdlc-practices-evolve-${TS}
   git -C ~/.claude/skills tag pre-sdlc-practices-evolve-${TS}
   ```

4. **Read project context if present:** if a `CLAUDE.md` exists in the current working directory, extract `stage` (MVP/growth/mature), `risk_profile` (low/medium/high), and `stack`. Use these to filter gaps by relevance. If no CLAUDE.md, default to conservative filters (drop heavy practices like chaos/formal verification/full pentest).

5. **Working tree of both repos must be clean of unrelated changes.** If dirty, ask before proceeding.

---

## Per-agent flow

For each agent in `~/.claude/agents/*.md` (or just the one specified by `--agent`):

### Step 1 — Extract current mandate
- Domain (from frontmatter `description`)
- Modalities currently covered (parse top-level sections: "Focus", "What you measure", "Web application checklist", etc.)
- Stated scope and explicit "Always"/"Never" rules
- Current `Auto-Research Scope > topics`

### Step 2 — Research the field
Run WebSearch with these queries (adapt domain noun to the agent):
- `state of the art {domain} engineering 2026 practices taxonomy`
- `{domain} maturity model modalities`
- `{domain} testing types catalog 2026` (or analogous for non-QA domains)

Extract: a list of practices/modalities known in the field for this domain. Prefer authoritative sources (OWASP, NIST, IEEE, Google/Meta engineering blogs, recognized researchers).

### Step 3 — Compute gaps
- `gaps = (field practices) − (current mandate modalities)`
- Filter by project context:
  - `stage == MVP` → drop heavy practices (chaos engineering, formal verification, full red-team pentest)
  - `risk_profile == low` → drop expensive practices (formal threat modeling, mutation testing on every PR)
  - Stack-irrelevant practices (e.g., frontend a11y testing on backend-only project) → drop
- Filter by maturity signals from `~/.claude/logs/auto-research/`:
  - If the agent's current modalities aren't yet stable (high revert rate), defer adding new modalities
- Sort remaining gaps by estimated value (severity of the blind spot × ease of adoption)

### Step 4 — Classify each gap by tier

#### T1 — Auto-apply, knowledge addition within existing structure
- Adding a referenced complementary practice within an existing modality (e.g., a single bullet in `qa-engineer > Focus` referencing axe-core for accessibility)
- Adding a topic to `Auto-Research Scope` that opens a new line of inquiry within the agent's current scope
- Adding an eval case to existing structure (if it doesn't break baseline)
- Adding a citation/reference

#### T2 — Auto-apply with explicit announcement, modality extension within domain
- New modality within agent's existing domain (e.g., adding mutation testing as a section in `quality-architect`; adding accessibility audit as a section in `qa-engineer`; adding stress test guidance to `performance-engineer`)
- Cross-agent coordinated bullets (e.g., a "performance budget" concept referenced consistently in `performance-engineer` and `software-architect`) — applied as a single transaction
- Extending the agent's `editable_sections` whitelist to admit a new content area within its domain

#### T3 — Escalate, structural change
- New agent (e.g., a dedicated chaos-engineering agent)
- Change to `sdlc-orchestrator` flow (new gate, reordering, new mandatory step)
- Change to any agent's `frozen_sections`
- Change to model assignment of any agent
- Change to inter-agent contract (output format that another agent consumes)
- New artifact type required by the SDLC
- Disable / removal of any existing capability

---

## Application

Iterate gaps in priority order. Stop when per-run cap is reached.

### For T1 changes
1. Read the target agent file (`Read` tool)
2. Generate the diff respecting `frozen_sections` and `constraints`
3. Apply via `Edit`
4. Commit: `git -C ~/.claude/agents add {agent}.md && git commit -m "sdlc-practices-evolve: T1 — {gap-name} — {agent} — source: {url}"`
5. **Validate — and make sure you are validating the version you just wrote.**

   **Never spawn `subagent_type: {agent}` for this.** A subagent loads the agent definition as it stood
   at the start of *this* session, not the file you just edited. It would grade the version you
   replaced and hand you a confident green about the wrong target — the failure mode with no red
   output and nothing prompting you to look twice.

   If the agent has an `Eval Suite` with `cases`, run it like this instead:
   - **Doer** — `Agent` with `subagent_type: general-purpose`, `model` taken from the target agent's
     frontmatter, and the **full text of the edited `.md`** pasted into the prompt as its operating
     instructions, followed by the case `input`. This is an approximation of the real agent (no tool
     restrictions, no frontmatter `effort`) — say so when reporting, and never call it more than it is.
   - **Baseline** — measured with the *same* instrument, from the previous revision's text
     (`git -C ~/.claude/agents show HEAD~1:{agent}.md`). A baseline read through `subagent_type` and a
     post-edit score read through pasted text are two different instruments; comparing them measures
     the instrument, not the change.
   - **Grader** — a fresh `general-purpose` subagent that sees only the doer's final output, graded
     per the `expect` rules. It must not see the doer's thread.
   - `new_score < baseline` → `git -C ~/.claude/agents revert HEAD` (revert just this commit), log the
     regression, continue with next gap
   - `new_score >= baseline` → keep

6. **If the evals did not run — no `cases`, or you chose not to spawn agents — the change is
   `unvalidated`.** Count it, name it as unvalidated in the run summary, and record it in
   `last-run.json` (`validation_method`, `unvalidated_count`). Never describe an unvalidated change as
   validated, and never let the run summary imply a gate ran when it did not.

### For T2 changes
Same flow as T1, with two additions:
- **Announcement:** print to run output: `T2 applied — {gap-name} adds {modality} to {agent}. Reason: {one line}.`
- **Cross-agent transactions:** if the gap requires coordinated edits across 2+ agents, apply them as a single transaction. Stage all edits → run all relevant evals → if any agent's eval fails, revert ALL commits in the transaction. Use a single commit per file with a shared transaction tag in the message: `sdlc-practices-evolve: T2 [tx={tx-id}] — {gap-name} — {agent} — source: {url}`.

### For T3 changes
**Never apply.** Collect into the escalation document.

### Stop conditions
- Hit per-run cap (default 5; configurable via `--cap`)
- Run out of T1/T2 gaps
- Cooldown active and `--t1-only`: skip all T2, queue them to escalation document along with T3

---

## Escalation document

Write to `~/.claude/logs/sdlc-practices-evolve/{YYYY-MM-DD}-escalations.md`:

```markdown
---
date: YYYY-MM-DD
total_t3: K
deferred_t2: M  # only when --t1-only forced by cooldown
checkpoint_pre: pre-sdlc-practices-evolve-{ts}
---

## T3 — Structural changes (require your decision)

### Gap: {name}
**Domain / agent affected:** {agent name or "system-level"}
**Modality missing:** {what}
**Why it matters:** [1-2 sentences citing field practice]
**Cost to adopt:** {low | medium | high} — [explain in 1 sentence]
**Trigger signal:** [when does adopting this become valuable — concrete heuristic]
**Proposed change type:** {new agent | new gate | flow change | frozen-section change | model change | contract change | new artifact}
**Recommendation:** {ADOPT NOW | NOT NOW — REVISIT WHEN | NOT FIT}
**Rationale:** [1-2 sentences for the recommendation]
**Sources:** [URLs]

[repeat per gap]

## T2 deferred (cooldown active)
[same structure, only when --t1-only was forced]
```

---

## Versioning + rollback

After all changes (whether 0 or N applied):
```
git -C ~/.claude/agents tag post-sdlc-practices-evolve-${TS}
git -C ~/.claude/skills tag post-sdlc-practices-evolve-${TS}
```

Sync changes to the ai-squad working tree (do **not** push).

**The repo's own `skills/` directory is the allowlist — iterate it, never glob the global.** The global
holds private and work skills that must never reach a public repo, and a blanket copy also flattens
every skill's contents into `skills/` root (a trailing-slash `cp -r` copies *contents*, not the
directory), colliding every `SKILL.md` into one file while updating none of the real skills.

```bash
REPO=/Users/carlos.sobral/github-repos/ai-squad

cp ~/.claude/agents/*.md "$REPO/agents/"

# Skills: one directory at a time, driven by what the repo already carries.
for dir in "$REPO"/skills/*/; do
  name=$(basename "$dir")
  [ -d "$HOME/.claude/skills/$name" ] && rsync -a --delete "$HOME/.claude/skills/$name/" "$dir"
done
```

**Then run the detector. It must print nothing.**

```bash
diff <(git -C "$REPO" ls-files skills/ | cut -d/ -f2 | sort -u) \
     <(ls "$REPO/skills" | sort -u)
```

Any line of output is a real problem, and the two directions mean different things: a `>` line is an
entry on disk that the repo does not track — a leaked private skill or a stray file; delete it before
committing. A `<` line is a tracked skill that vanished from disk. Never `git add -A` in the repo
without having seen this command print nothing.

Write `~/.claude/logs/sdlc-practices-evolve/last-run.json`:
```json
{
  "date": "YYYY-MM-DD",
  "decision": "applied|rolled-back|partial|t1-only",
  "t1_count": N,
  "t2_count": M,
  "t3_escalated_count": K,
  "cap_used": 5,
  "validation_method": "eval-suite | none",
  "unvalidated_count": U,
  "skills_synced": true,
  "checkpoint_pre": "pre-sdlc-practices-evolve-{ts}",
  "checkpoint_post": "post-sdlc-practices-evolve-{ts}"
}
```

This file gates the cooldown check on the next run. **The user is responsible for editing `decision: "rolled-back"` if they roll back outside the skill** — there is no automatic detection.

Document rollback in every run output:
```
Full rollback (both repos):
  git -C ~/.claude/agents reset --hard pre-sdlc-practices-evolve-{ts}
  git -C ~/.claude/skills reset --hard pre-sdlc-practices-evolve-{ts}
  echo '{"decision":"rolled-back",...}' > ~/.claude/logs/sdlc-practices-evolve/last-run.json

Single-change revert:
  git -C ~/.claude/agents revert {sha}
```

---

## Output

After the run, surface a 6-10 line summary in the conversation:

```
sdlc-practices-evolve complete:
- {N} agents audited
- T1 applied: {count} — [one-line list]
- T2 applied: {count} — [one-line list]
- T3 escalated: {count}
- Validation: {N of M changes validated against an eval suite | none — say which and why}
- Cooldown: {active|inactive}
- Top escalation: [most important one in 1 line]
- Full digest + escalations: ~/.claude/logs/sdlc-practices-evolve/{date}-escalations.md
- Rollback: git -C ~/.claude/agents reset --hard {pre-tag}
- Last-run state written for cooldown logic
```

---

## Hard rules

- **Never** edit a `frozen_section` of any agent
- **Never** create a new agent without escalating (T3)
- **Never** modify `sdlc-orchestrator` without escalating (T3)
- **Never** loosen any agent's `constraints` — the constraint cap is sacred
- **Never** disable or remove existing capability — that's T3
- **Always** cite the source URL in every commit message and every escalation entry
- **Always** validate via the agent's eval suite when one exists; flag unvalidated changes explicitly when no suite exists
- **Never** validate an edited agent by spawning `subagent_type: {agent}` — that grades the definition from the start of the session, not your edit. Feed the edited file's text to a `general-purpose` subagent instead
- **Never** sync skills with a blanket copy of the global — iterate the repo's own `skills/` directory, then run the leak detector and confirm it prints nothing before any `git add`
- **Always** record `validation_method` and `unvalidated_count` in `last-run.json`, and report the same numbers in the run summary
- **Always** stop at the per-run cap; remaining gaps queue to the escalation document
- **Cross-agent T2 changes are transactions** — atomic apply or atomic revert
- **If `--t1-only` is forced** by cooldown: T2 is deferred to escalation document; only T1 is applied

---

## Failure modes to watch

- **Field research returns generic results:** queries may be too broad. Try `{domain} {modality} 2026 best practice` patterns instead.
- **Stage filter drops everything:** the project context is too conservative for the agent's domain (e.g., MVP project running security audit). Honest outcome — surface as "no actionable T1/T2 this run; T3 deferred until {trigger condition}".
- **Eval revert chain:** if 3+ T1/T2 changes in one run get reverted by their evals, stop the run early and surface as "research findings did not validate against the existing eval suite — review eval suite for staleness or research source quality".
- **No eval suite on a target agent:** unvalidated changes are dangerous. Cap unvalidated T1/T2 at 1 per run; escalate the rest of that agent's gaps to T3 with a "needs eval suite first" note.
- **A green eval that graded the wrong prompt:** the single most likely way this skill lies to you. Spawning `subagent_type: {agent}` after editing `{agent}.md` returns a result about the pre-edit definition — no error, no red output, just a confident score answering a question you did not ask. If an eval passes without you having pasted the edited file's text into the doer, the number is about the old version. See Application step 5.
- **A sync that copies everything and updates nothing:** `cp -r ~/.claude/skills/*/ <repo>/skills/` copies each skill's *contents* (trailing slash), so it flattens loose files into `skills/` root, collides every `SKILL.md` into one, leaves the real skill directories untouched, and drags private skills into a public repo. Measured 2026-09-01 on a sandbox copy: 9 tracked skills in, 7 stray files at root, `SKILL.md` overwritten by the alphabetically-last skill, internal CSVs leaked, zero public skills actually updated. Use the loop + detector in Versioning + rollback.
