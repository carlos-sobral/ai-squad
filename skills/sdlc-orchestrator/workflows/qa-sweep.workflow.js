export const meta = {
  name: 'sdlc-qa-sweep',
  description: 'Verify N acceptance criteria in parallel, one qa-engineer per AC, over the same BASE..HEAD. Returns per-AC verdicts including MANUAL_PENDING flags. NEVER decides merge: MANUAL_PENDING on a mandatory-invariant AC is a HARD orchestrator gate (Tech Lead must run-now / block / accept-risk).',
  phases: [
    { title: 'Verify', detail: 'one qa-engineer per AC, in parallel' },
    { title: 'Aggregate', detail: 'collect verdicts + surface MANUAL_PENDING (no merge here)' },
  ],
}

// ---------------------------------------------------------------------------
// Fit #4 (QA half) from SKILL.md "Execution engine for well-posed sub-phases".
//
//   Workflow({
//     scriptPath: ".../qa-sweep.workflow.js",
//     args: {
//       repoPath: "/abs/path/to/repo",   // optional
//       baseSha:  "<BASE_SHA>",          // required (cache-stale guard)
//       headSha:  "<HEAD_SHA>",          // required (cache-stale guard)
//       acs: [ { id: "AC-1", description, mandatoryInvariant: true|false }, ... ], // required
//     },
//   })
//
// BOUNDARY RULE: the workflow runs the verification and FLAGS results. It does
// NOT merge and does NOT resolve MANUAL_PENDING. Per SKILL.md, a MANUAL_PENDING
// on an AC that validates a mandatory invariant (PII isolation, security
// boundary, multi-tenant scope, data integrity) forces the orchestrator to ask
// the Tech Lead literally: run-now / block-merge / accept-risk-with-followup.
// ---------------------------------------------------------------------------

const a = args || {}
if (!a.baseSha || !a.headSha) throw new Error('qa-sweep requires args.baseSha and args.headSha (cache-stale guard)')
if (!Array.isArray(a.acs) || !a.acs.length) throw new Error('qa-sweep requires a non-empty args.acs array of {id, description, mandatoryInvariant?}')

const AC_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['acId', 'verdict', 'evidence'],
  properties: {
    acId: { type: 'string' },
    verdict: {
      type: 'string',
      enum: ['PASS', 'FAIL', 'MANUAL_PENDING'],
      description: 'MANUAL_PENDING = cannot be verified in this environment (e.g. needs a running build the CI/sandbox cannot reproduce)',
    },
    evidence: { type: 'string', description: 'the command run + observed result, or why it could not be verified' },
    notes: { type: 'string' },
  },
}

const repoHint = a.repoPath ? `\nFirst: cd ${a.repoPath}\n` : ''

function acPrompt(ac) {
  // SHAs embedded verbatim = cache-stale guard.
  return `You are a qa-engineer verifying ONE acceptance criterion against the change ${a.baseSha}..${a.headSha}.
${repoHint}
AC ${ac.id}: ${ac.description}
${ac.mandatoryInvariant ? 'This AC validates a MANDATORY INVARIANT — if you cannot verify it in this environment, return MANUAL_PENDING (do NOT guess PASS).' : ''}

Verify by the most direct reliable means: run the relevant tests, exercise the path, or inspect the diff (git diff ${a.baseSha}..${a.headSha}). Report exactly what you ran and observed.
- PASS only with concrete evidence (test output, observed behavior).
- FAIL if the criterion is not met — cite the gap.
- MANUAL_PENDING if it genuinely cannot be verified here (needs a running build/UI the environment can't reproduce).
Return the structured object. Never claim PASS without fresh evidence in your answer.`
}

phase('Verify')
const results = await parallel(
  a.acs.map((ac) => () =>
    agent(acPrompt(ac), {
      label: `qa:${ac.id}`,
      phase: 'Verify',
      agentType: 'qa-engineer',
      schema: AC_SCHEMA,
    }).then((r) => ({ ...r, mandatoryInvariant: !!ac.mandatoryInvariant }))
     .catch(() => ({ acId: ac.id, verdict: 'MANUAL_PENDING', evidence: 'agent errored or skipped', mandatoryInvariant: !!ac.mandatoryInvariant }))
  )
)

phase('Aggregate')
const ok = results.filter(Boolean)
const failed = ok.filter((r) => r.verdict === 'FAIL')
const manualPending = ok.filter((r) => r.verdict === 'MANUAL_PENDING')
// The subset the orchestrator MUST hard-gate on (mandatory invariant + unverifiable):
const hardGate = manualPending.filter((r) => r.mandatoryInvariant)

const recommendedVerdict = failed.length ? 'FAIL'
  : manualPending.length ? 'PASS_WITH_MANUAL_PENDING'
  : 'PASS'

if (hardGate.length) {
  log(`HARD GATE: ${hardGate.length} mandatory-invariant AC(s) are MANUAL_PENDING (${hardGate.map((r) => r.acId).join(', ')}). Orchestrator MUST ask the Tech Lead: run-now / block-merge / accept-risk-with-followup.`)
}
log(`QA sweep: ${failed.length} FAIL, ${manualPending.length} MANUAL_PENDING, ${ok.length - failed.length - manualPending.length} PASS across ${ok.length}/${a.acs.length} ACs.`)

return {
  isRecommendationOnly: true,
  note: 'Recommendation only. The workflow never merges and never resolves MANUAL_PENDING. requiresHardGate lists the mandatory-invariant ACs the orchestrator MUST escalate to the Tech Lead before merge.',
  recommendedVerdict,
  baseSha: a.baseSha,
  headSha: a.headSha,
  failed: failed.map((r) => r.acId),
  manualPending: manualPending.map((r) => r.acId),
  requiresHardGate: hardGate.map((r) => r.acId),
  acs: ok,
}
