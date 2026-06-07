export const meta = {
  name: 'sdlc-refactor-by-module',
  description: 'Run software-architect refactor mode over N independent modules in parallel, worktree-isolated, NO behavior change. Returns per-module refactor results. The review-team + Tech Lead verify behavior preservation and own the merge — this workflow never merges.',
  phases: [
    { title: 'Refactor', detail: 'one software-architect (refactor mode) per module, isolated worktrees' },
    { title: 'Collect', detail: 'gather per-module results (behavior-change verification stays human)' },
  ],
}

// ---------------------------------------------------------------------------
// Fit #4 (refactor half) from SKILL.md "Execution engine for well-posed
// sub-phases". worktree isolation enforces the manual "don't parallelize
// agents that edit the same file" rule by construction.
//
//   Workflow({
//     scriptPath: ".../refactor-by-module.workflow.js",
//     args: {
//       repoPath: "/abs/path/to/repo",   // required
//       baseSha:  "<BASE_SHA>",          // required (cache-stale guard)
//       modules: [ { slug, scope, specRef }, ... ],  // required; scope = paths/area to refactor
//     },
//   })
//
// BOUNDARY RULE: NO behavior change, NO merge, NO gate. The review-team must
// confirm behavior preservation afterward; the orchestrator + Tech Lead merge.
// ---------------------------------------------------------------------------

const a = args || {}
if (!a.repoPath) throw new Error('refactor-by-module requires args.repoPath')
if (!a.baseSha) throw new Error('refactor-by-module requires args.baseSha (cache-stale guard)')
if (!Array.isArray(a.modules) || !a.modules.length) {
  throw new Error('refactor-by-module requires a non-empty args.modules array of {slug, scope, specRef?}')
}

const MODULE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['slug', 'changed', 'summary', 'behaviorChangeRisk', 'testsRun'],
  properties: {
    slug: { type: 'string' },
    changed: { type: 'boolean', description: 'true if any refactor was applied' },
    summary: { type: 'string', description: 'what was cleaned up, in 2-3 sentences' },
    behaviorChangeRisk: {
      type: 'string',
      enum: ['none', 'low', 'needs-review'],
      description: 'self-assessed risk that behavior changed despite intent — needs-review forces a closer review-team look',
    },
    testsRun: { type: 'boolean', description: 'true if the existing test suite was run and stayed green after refactor' },
  },
}

function modulePrompt(m) {
  return `You are software-architect in REFACTOR MODE on ONE module, in an isolated git worktree of ${a.repoPath} (base ${a.baseSha}).

Module: ${m.slug}
Scope to refactor: ${m.scope}
${m.specRef ? `Spec reference (for intended behavior): ${m.specRef}` : ''}

Hard rule: NO behavior change. Improve structure, naming, duplication, cohesion only. After refactoring:
- Run the existing test suite. It MUST stay green. If you cannot run it, say so and set testsRun=false.
- If a change risks altering behavior, prefer NOT making it and flag behaviorChangeRisk=needs-review.
- Touch ONLY this module's scope; do not bleed into other modules.
Commit the refactor in the worktree. Return the structured object honestly — do not claim tests passed without running them.`
}

phase('Refactor')
const results = await parallel(
  a.modules.map((m) => () =>
    agent(modulePrompt(m), {
      label: `refactor:${m.slug}`,
      phase: 'Refactor',
      agentType: 'software-architect',
      isolation: 'worktree',
      schema: MODULE_SCHEMA,
    }).catch(() => ({ slug: m.slug, changed: false, summary: 'agent errored or skipped', behaviorChangeRisk: 'needs-review', testsRun: false }))
  )
)

phase('Collect')
const ok = results.filter(Boolean)
const needsReview = ok.filter((r) => r.behaviorChangeRisk === 'needs-review')
const untested = ok.filter((r) => r.changed && !r.testsRun)

if (needsReview.length) log(`${needsReview.length} module(s) flagged behaviorChangeRisk=needs-review: ${needsReview.map((r) => r.slug).join(', ')} — review-team must look closely.`)
if (untested.length) log(`${untested.length} changed module(s) without a green test run: ${untested.map((r) => r.slug).join(', ')} — do NOT merge until verified.`)
log(`Refactored ${ok.filter((r) => r.changed).length}/${a.modules.length} modules. Behavior preservation + merge are the orchestrator's job.`)

return {
  isExecutionOnly: true,
  note: 'EXECUTION ONLY. NO behavior change is intended, but verification of behavior preservation is NOT done here — the review-team must confirm, and the orchestrator + Tech Lead own the merge (boundary rule).',
  baseSha: a.baseSha,
  total: a.modules.length,
  needsReview: needsReview.map((r) => r.slug),
  untested: untested.map((r) => r.slug),
  modules: ok,
}
