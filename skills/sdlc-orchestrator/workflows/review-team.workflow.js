export const meta = {
  name: 'sdlc-review-team',
  description: 'Run the SDLC review-team as a deterministic fan-out: N reviewers over the same BASE..HEAD SHAs, each returning a schema-validated verdict. Returns a RECOMMENDED verdict — the merge gate stays with the orchestrator + Tech Lead.',
  phases: [
    { title: 'Review', detail: 'reviewers fan out over the same diff, in parallel' },
    { title: 'Aggregate', detail: 'combine verdicts into a recommendation (no human gate here)' },
  ],
}

// ---------------------------------------------------------------------------
// Reference implementation of the "review-team" fit from the sdlc-orchestrator
// SKILL.md ("Execution engine for well-posed sub-phases"). Invoke with:
//
//   Workflow({
//     scriptPath: ".../review-team.workflow.js",
//     args: {
//       baseSha:  "<BASE_SHA>",            // required
//       headSha:  "<HEAD_SHA>",            // required
//       description: "one paragraph: what this PR is supposed to do",  // required
//       specPath: "docs/architecture.md#section",  // link to spec/plan it implements
//       variant:  "critical",             // standard | critical | infra | full
//       repoPath: "/abs/path/to/repo",    // optional; reviewers cd here before git diff
//       reviewers: ["software-architect", "security-engineer"], // optional explicit override
//     },
//   })
//
// BOUNDARY RULE (load-bearing): this workflow contains NO human gate and does
// NOT own the merge decision. It returns findings + a recommended verdict; the
// orchestrator holds the actual verdict and every human checkpoint.
// ---------------------------------------------------------------------------

const a = args || {}
if (!a.baseSha || !a.headSha) {
  throw new Error('review-team workflow requires args.baseSha and args.headSha (see header for the full args shape).')
}

const VARIANT = a.variant || 'standard'

// Risk-Surface → reviewer set (mirrors the "Team roster by stage" + "Review
// depth by Risk Surface" tables in SKILL.md). software-architect always runs
// in code-review mode; security-engineer always runs.
const VARIANT_ROSTER = {
  standard: ['software-architect', 'security-engineer'],
  critical: ['software-architect', 'security-engineer', 'quality-architect'],
  infra:    ['software-architect', 'security-engineer', 'cloud-architect'],
  full:     ['software-architect', 'security-engineer', 'quality-architect', 'cloud-architect'],
}

const REVIEWERS = Array.isArray(a.reviewers) && a.reviewers.length
  ? a.reviewers
  : (VARIANT_ROSTER[VARIANT] || VARIANT_ROSTER.standard)

// Per-reviewer mode/scope hint so the same prompt template stays accurate.
const ROLE_SCOPE = {
  'software-architect': 'Run in CODE REVIEW mode (Mode 2). Judge correctness, contract fidelity to the spec, structural soundness, and drift from the approved design.',
  'security-engineer': 'Run a security review grounded in OWASP Top 10 / API Top 10 / CWE Top 25. If the diff touches LLM/agent/RAG code, also apply OWASP LLM Top 10 (llm-review mode).',
  'quality-architect': 'Judge test coverage, mutation resistance, flakiness, and whether the quality gates the spec implies are actually enforced.',
  'cloud-architect': 'Review IaC / pipeline / infra changes for compliance with the approved cloud patterns and the security baseline.',
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['verdict', 'summary', 'findings'],
  properties: {
    verdict: {
      type: 'string',
      enum: ['PASS', 'PASS_WITH_WARNINGS', 'BLOCK'],
      description: 'PASS = no issues; PASS_WITH_WARNINGS = non-blocking issues; BLOCK = at least one issue that must be fixed before merge',
    },
    summary: { type: 'string', description: 'one-paragraph verdict rationale' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'location', 'summary'],
        properties: {
          severity: { type: 'string', enum: ['blocker', 'warning', 'suggestion'] },
          location: { type: 'string', description: 'file:line or spec section the finding refers to' },
          summary: { type: 'string' },
          recommendation: { type: 'string', description: 'concrete fix, if any' },
        },
      },
    },
  },
}

const repoHint = a.repoPath ? `\nFirst: cd ${a.repoPath}\n` : ''
const specHint = a.specPath ? `\n- Spec / plan it implements: ${a.specPath} (read it before judging fidelity).` : ''

function reviewerPrompt(role) {
  const scope = ROLE_SCOPE[role] || 'Review the change within your area of expertise.'
  // BASE/HEAD SHAs are embedded VERBATIM on purpose: they ground the reviewer
  // AND act as the cache-stale guard — when the diff changes, the SHAs change,
  // the prompt text changes, and the resume journal cannot serve stale cache.
  return `You are the ${role} on an SDLC review-team. ${scope}
${repoHint}
Read the diff yourself from git — do NOT expect it inline:
  git diff ${a.baseSha}..${a.headSha}

Context:
- What this change is supposed to do: ${a.description || '(no description provided)'}
- BASE_SHA: ${a.baseSha}
- HEAD_SHA: ${a.headSha}
- Review variant: ${VARIANT}${specHint}

Produce your verdict as the structured object. Severity discipline:
- blocker  → must be fixed before merge (verdict BLOCK)
- warning  → should be addressed; non-blocking (verdict PASS_WITH_WARNINGS)
- suggestion → optional improvement (does not affect verdict)
Set verdict to the worst severity present (any blocker → BLOCK; else any warning → PASS_WITH_WARNINGS; else PASS).
Be specific: cite file:line or spec section in every finding. Do not invent issues to seem thorough.`
}

phase('Review')
const reviews = await parallel(
  REVIEWERS.map((role) => () =>
    agent(reviewerPrompt(role), {
      label: `review:${role}`,
      phase: 'Review',
      agentType: role,
      schema: VERDICT_SCHEMA,
    }).then((v) => ({ role, ...v }))
  )
)

phase('Aggregate')
// Deterministic aggregation — no model, no human gate. Worst verdict wins.
const ok = reviews.filter(Boolean)
const failed = REVIEWERS.filter((r) => !ok.some((x) => x.role === r))

const RANK = { PASS: 0, PASS_WITH_WARNINGS: 1, BLOCK: 2 }
const NAME = ['PASS', 'PASS_WITH_WARNINGS', 'BLOCK']
const worst = ok.reduce((acc, r) => Math.max(acc, RANK[r.verdict] ?? 0), 0)
const recommendedVerdict = ok.length ? NAME[worst] : 'BLOCK'

const allFindings = ok.flatMap((r) =>
  (r.findings || []).map((f) => ({ role: r.role, ...f }))
)
const blockerCount = allFindings.filter((f) => f.severity === 'blocker').length
const warningCount = allFindings.filter((f) => f.severity === 'warning').length

if (failed.length) {
  log(`WARNING: ${failed.length} reviewer(s) did not return a verdict: ${failed.join(', ')}. Recommendation forced to BLOCK — orchestrator must re-dispatch or decide manually.`)
}
log(`Recommended verdict: ${recommendedVerdict} (${blockerCount} blocker(s), ${warningCount} warning(s) across ${ok.length}/${REVIEWERS.length} reviewers).`)

return {
  // The orchestrator consumes this; the merge gate is NOT decided here.
  recommendedVerdict,
  isRecommendationOnly: true,
  note: 'Recommendation only. The orchestrator + Tech Lead own the merge gate (boundary rule). Treat BLOCK as a hard stop; PASS_WITH_WARNINGS still requires Tech Lead acknowledgement per the DoD.',
  variant: VARIANT,
  baseSha: a.baseSha,
  headSha: a.headSha,
  blockerCount,
  warningCount,
  reviewersMissing: failed,
  reviews: ok.map((r) => ({ role: r.role, verdict: r.verdict, summary: r.summary, findings: r.findings })),
}
