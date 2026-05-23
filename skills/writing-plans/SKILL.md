---
name: writing-plans
description: Use when a tech spec is approved and the implementation needs to be decomposed into bite-sized executable tasks before any engineer touches code
---

# Writing Plans

## Overview

A tech spec defines **what** to build. A plan defines **how** to build it — decomposed into 2-5 minute tasks, each with exact file paths, real code blocks, exact commands, and explicit success criteria. The plan is the contract the implementing agents work from.

**Core principle:** assume the implementing engineer has zero context for this codebase and questionable taste. Document everything they need: which files to touch, the actual code, the actual test, the exact command to verify. No "TBD". No "add appropriate error handling". No "similar to Task N".

**Invoked by:** `software-architect` after a tech spec is approved by the Tech Lead, before delegating to `backend-engineer` / `frontend-engineer` / `cloud-architect`. The orchestrator schedules this step; the architect runs it; the impl agents consume it.

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-slug>.md` in the project repo.

## Scope check before writing

If the tech spec covers multiple independent subsystems (e.g., backend API + frontend dashboard + background worker), split into one plan per subsystem. Each plan must produce working, testable software on its own — that is what allows `backend-engineer` and `frontend-engineer` to run in parallel as a `TeamCreate` team without stepping on each other.

If the spec is one subsystem with internal layering, keep it as one plan.

## File structure pass

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This locks the decomposition before you commit to task ordering.

- One responsibility per file. Files that change together live together.
- Smaller focused files over large ones — the implementing agent reasons better about code it can hold in context at once.
- Follow established patterns in the codebase. If the codebase uses large files, don't unilaterally restructure — but if a file you're modifying is already unwieldy, including a split in the plan is reasonable.

The file map informs the task list. Each task should produce self-contained changes that make sense on their own.

## Bite-sized task granularity

Each step is **one action, 2-5 minutes**:

- "Write the failing test" — step
- "Run it to confirm it fails" — step
- "Implement the minimal code to make it pass" — step
- "Run the tests to confirm they pass" — step
- "Commit" — step

If a step is longer than 5 minutes, split it. Long steps hide intent and produce diffs the reviewer can't follow.

## Plan document header

Every plan starts with this header verbatim:

```markdown
# [Feature Name] — Implementation Plan

**Tech spec:** `docs/specs/<date>-<slug>.md` (link to the source of truth)
**Owner agent:** [backend-engineer | frontend-engineer | cloud-architect]
**Goal:** [one sentence describing what this builds]
**Architecture:** [2-3 sentences about approach]
**Tech stack:** [key technologies/libraries in scope]

---
```

The `Owner agent` field tells the orchestrator who to spawn. The `Tech spec` link prevents the impl agent from working off the plan alone — they must read the spec too.

## Task structure

````markdown
### Task N: [Component name]

**Files:**
- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts:123-145`
- Test: `tests/exact/path/to/test.ts`

- [ ] **Step 1: Write the failing test**

```ts
test("specific behavior", () => {
  const result = fn(input);
  expect(result).toEqual(expected);
});
```

- [ ] **Step 2: Run test to confirm it fails**

Run: `pnpm test tests/path/test.ts -t "specific behavior"`
Expected: FAIL with `fn is not defined`

- [ ] **Step 3: Write minimal implementation**

```ts
export function fn(input: Input): Output {
  return expected;
}
```

- [ ] **Step 4: Run test to confirm it passes**

Run: `pnpm test tests/path/test.ts -t "specific behavior"`
Expected: PASS — exit 0, 1 passed

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.ts src/path/file.ts
git commit -m "feat(<scope>): add specific behavior"
```
````

The test-first ordering matches the test-first technique declared in `backend-engineer` / `frontend-engineer` prompts. The plan should not contradict it.

## No placeholders — plan failures to never write

These patterns are plan failures. The plan is incomplete if any survive into the saved file:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases" without the actual code
- "Write tests for the above" without the actual test code
- "Similar to Task N" — repeat the code; the impl agent may read tasks out of order or in isolation
- Steps that describe what to do without showing how (code steps require code blocks)
- References to types, functions, or methods not defined in any task

If you find one of these while writing, stop and write the actual content.

## Remember

- Exact file paths always
- Complete code in every step that touches code
- Exact commands with expected output (exit code, count of tests passed, key log line)
- DRY, YAGNI, TDD, frequent commits — each task = 1 commit minimum

## Self-review before saving

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a single-pass checklist — not a subagent dispatch.

1. **Spec coverage** — skim each section/requirement in the spec. Can you point to a specific task that implements it? List any gaps and add tasks for them.
2. **Placeholder scan** — search the plan for the red flags from the "No placeholders" section. Fix any you find.
3. **Type consistency** — do types, method signatures, and property names you used in Task 7 match what you defined in Task 3? A function called `clearLayers()` in one task and `clearFullLayers()` in another is a bug.
4. **Shared-type boundaries** — does any task introduce a shared type (interface, abstract class, DI token) that downstream tasks extend? If yes, those tasks may not be independently typecheck-able — flag in the task description and consider merging or adding a temporary shim (see the `backend-engineer` "Batch consolidation when batches share types" rule).
5. **Test commands are runnable as written** — paste the exact `pnpm test ...` / `pytest ...` / `cargo test ...` command into the step. The impl agent should not have to translate "run the tests" into the project's actual command.

Fix issues inline. No need to re-review — just fix and move on.

## Handoff

After saving the plan, the orchestrator dispatches the `Owner agent` declared in the header to consume it. The plan is the contract — the impl agent works through the tasks in order, checking each `- [ ]` as it commits. If the impl agent finds a defect in the plan (missing type, wrong file path, mistaken test command), they STOP and flag back to `software-architect` rather than guessing — the plan is meant to be authoritative.

For parallel-eligible work (backend + frontend of the same feature), the orchestrator creates separate plans per `Owner agent`, then spawns them as a `TeamCreate` team per the rules in `~/.claude/CLAUDE.md` "Agent invocation".

## Anti-patterns

- **Plan that paraphrases the spec.** If the plan is just the spec in different words, it adds no value. The plan adds value by decomposing into commits and quoting exact commands.
- **Plan that omits the test step.** Test-first ordering is the default per `backend-engineer` / `frontend-engineer` prompts; the plan reinforces it, never bypasses it.
- **Plan with steps that can't be commit-bounded.** If a "step" spans 4 files and 80 lines, it's a phase, not a step. Split it.
- **Plan written without reading the codebase.** File-structure pass requires you to know what already exists. Reading the spec is not enough.
