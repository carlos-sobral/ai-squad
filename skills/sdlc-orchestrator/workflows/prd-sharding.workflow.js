export const meta = {
  name: 'sdlc-prd-sharding',
  description: 'Implement N independent PRD-shard modules in parallel (worktree-isolated), one owner agent per module. Closes the named gap "sharding produces independent modules but the orchestrator processes them serially." Returns per-module results — the orchestrator integrates + runs the retro gate per module (learning stays serial).',
  phases: [
    { title: 'Implement', detail: 'one owner agent per independent module, isolated worktrees' },
    { title: 'Collect', detail: 'gather per-module status (no merge, no gate here)' },
  ],
}

// ---------------------------------------------------------------------------
// Fit #2 from SKILL.md "Execution engine for well-posed sub-phases".
// Parallelizes EXECUTION of independent modules only. The retrospective gate
// keeps serializing the LEARNING between modules (per the boundary rule and
// the synthesis: parallelize execution, not learning).
//
//   Workflow({
//     scriptPath: ".../prd-sharding.workflow.js",
//     args: {
//       repoPath: "/abs/path/to/repo",     // required
//       baseSha:  "<BASE_SHA>",            // required (cache-stale guard)
//       modules: [                          // required, each must be INDEPENDENTLY deliverable
//         { slug, specPath, planPath, ownerAgent },
//         ...
//       ],
//     },
//   })
//
// BOUNDARY RULE: no merge, no human gate. Returns per-module status; the
// orchestrator + Tech Lead own integration, review-team, and the retro gate.
// Each module ships through its own pipeline AFTER this workflow returns.
// ---------------------------------------------------------------------------

const a = args || {}
if (!a.repoPath) throw new Error('prd-sharding requires args.repoPath')
if (!a.baseSha) throw new Error('prd-sharding requires args.baseSha (cache-stale guard)')
if (!Array.isArray(a.modules) || !a.modules.length) {
  throw new Error('prd-sharding requires a non-empty args.modules array of {slug, specPath, planPath, ownerAgent}')
}

const VALID_OWNERS = ['backend-engineer', 'frontend-engineer', 'cloud-architect']

const MODULE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['slug', 'status', 'summary', 'commitsProduced'],
  properties: {
    slug: { type: 'string' },
    status: { type: 'string', enum: ['IMPLEMENTED', 'BLOCKED', 'NO_OP'] },
    summary: { type: 'string', description: 'what was built, in 2-3 sentences' },
    commitsProduced: { type: 'boolean', description: 'true if at least one commit landed in the worktree' },
    blockers: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['summary'],
        properties: { summary: { type: 'string' }, location: { type: 'string' } },
      },
    },
  },
}

function modulePrompt(m) {
  const owner = VALID_OWNERS.includes(m.ownerAgent) ? m.ownerAgent : 'backend-engineer'
  return `You are the ${owner} implementing ONE independent PRD-shard module in an isolated git worktree of ${a.repoPath} (branch base: ${a.baseSha}).

Module: ${m.slug}
- Tech spec: ${m.specPath || '(none — refuse and report BLOCKED if implementation needs a spec)'}
- Implementation plan: ${m.planPath || '(none — work from the spec)'}

Rules:
- Implement ONLY this module. It is independently deliverable; do not touch other modules' files.
- Quote file paths / schema columns / migration paths from the spec literally — do not paraphrase.
- Commit per task as you go. Write your own output report at docs/agents/${owner}/<date>-${m.slug}.md in the SAME worktree.
- If the spec is missing or ambiguous enough to force an arbitrary decision, stop and report status BLOCKED with the blocker — do not guess.

Return the structured object. status=NO_OP only if there was genuinely nothing to implement.`
}

phase('Implement')
// worktree isolation: each module mutates files in parallel without conflict.
// EXPENSIVE (per-agent worktree setup) — justified here precisely because the
// modules are independent and would otherwise collide on a shared tree.
const results = await parallel(
  a.modules.map((m) => () =>
    agent(modulePrompt(m), {
      label: `module:${m.slug}`,
      phase: 'Implement',
      agentType: VALID_OWNERS.includes(m.ownerAgent) ? m.ownerAgent : 'backend-engineer',
      isolation: 'worktree',
      schema: MODULE_SCHEMA,
    }).catch(() => ({ slug: m.slug, status: 'BLOCKED', summary: 'agent errored or was skipped', commitsProduced: false, blockers: [{ summary: 'no result returned' }] }))
  )
)

phase('Collect')
const ok = results.filter(Boolean)
const implemented = ok.filter((r) => r.status === 'IMPLEMENTED')
const blocked = ok.filter((r) => r.status === 'BLOCKED')

log(`${implemented.length}/${a.modules.length} modules implemented; ${blocked.length} blocked. Integration + per-module review + retro gate are the orchestrator's job (not done here).`)

return {
  isExecutionOnly: true,
  note: 'EXECUTION ONLY. No merge, no review, no retro happened here (boundary rule). The orchestrator must run review-team per module and the retrospective gate serially — the learning loop stays serial even though execution parallelized.',
  baseSha: a.baseSha,
  total: a.modules.length,
  implemented: implemented.map((r) => r.slug),
  blocked: blocked.map((r) => ({ slug: r.slug, blockers: r.blockers || [] })),
  modules: ok,
}
