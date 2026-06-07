export const meta = {
  name: 'sdlc-brownfield-inventory',
  description: 'Read-only fan-out inventory of a pre-existing repo across N dimensions (stack, CI/CD, conventions, hotspots, test strategy, maturity signals). Feeds the /onboard-brownfield skill. Produces structured findings — the skill + Tech Lead write the baseline docs and decide maturity claims.',
  phases: [
    { title: 'Inventory', detail: 'one read-only agent per dimension, in parallel' },
  ],
}

// ---------------------------------------------------------------------------
// Fit #3 from SKILL.md "Execution engine for well-posed sub-phases".
// Read-only, well-posed on entry, no human gate mid-flight — near-perfect fit.
// Cheap to re-run when the repo changes little (resume cache hit).
//
//   Workflow({
//     scriptPath: ".../brownfield-inventory.workflow.js",
//     args: {
//       repoPath: "/abs/path/to/repo",   // required
//       headSha:  "<HEAD_SHA>",          // required (cache-stale guard)
//       dimensions: ["stack", ...],       // optional; defaults below
//     },
//   })
//
// BOUNDARY RULE: inventory only. It does NOT write baseline docs and does NOT
// claim maturity levels — /onboard-brownfield + Tech Lead own those decisions.
// ---------------------------------------------------------------------------

const a = args || {}
if (!a.repoPath) throw new Error('brownfield-inventory requires args.repoPath')
if (!a.headSha) throw new Error('brownfield-inventory requires args.headSha (cache-stale guard)')

const DEFAULT_DIMENSIONS = [
  { key: 'stack', ask: 'Languages, frameworks, runtimes, package managers, and notable libraries. How the app is built and run.' },
  { key: 'ci-cd', ask: 'CI/CD configuration: pipelines, build/test/deploy steps, environments, IaC presence. Is there a deploy path?' },
  { key: 'conventions', ask: 'Code conventions actually in use: directory layout, naming, error handling, module boundaries, lint/format config.' },
  { key: 'hotspots', ask: 'Risk hotspots: largest/most-churned files, areas with no tests, TODO/FIXME density, files touched by many recent commits.' },
  { key: 'test-strategy', ask: 'Test reality: frameworks, where tests live, rough coverage signal, unit vs integration vs e2e balance, flakiness markers.' },
  { key: 'maturity-signals', ask: 'Objective signals only (NO level claim): presence of CI gates, observability/telemetry, ADRs/docs, review process artifacts, release cadence in git log.' },
]

const dimensions = Array.isArray(a.dimensions) && a.dimensions.length
  ? a.dimensions.map((d) => (typeof d === 'string' ? (DEFAULT_DIMENSIONS.find((x) => x.key === d) || { key: d, ask: d }) : d))
  : DEFAULT_DIMENSIONS

const DIM_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['dimension', 'findings', 'evidence'],
  properties: {
    dimension: { type: 'string' },
    findings: { type: 'string', description: 'concise prose summary of what was found for this dimension' },
    evidence: {
      type: 'array',
      description: 'concrete file paths / config locations backing the findings',
      items: { type: 'string' },
    },
    gaps: {
      type: 'array',
      description: 'things absent that the onboarding skill should flag as TO DEFINE',
      items: { type: 'string' },
    },
  },
}

function dimPrompt(d) {
  // headSha embedded verbatim = cache-stale guard: when the repo state changes,
  // the prompt text changes and the journal cannot serve stale cache.
  return `You are inventorying ONE dimension of a pre-existing repository, READ-ONLY. Do not modify anything.

Repo: ${a.repoPath}  (HEAD: ${a.headSha})
Dimension: "${d.key}" — ${d.ask}

Investigate by reading files, configs, and git history (read-only commands only: git log, git ls-files, ripgrep, reading files). Be concrete and cite real paths. Make NO maturity-level claim — only report objective signals. Return the structured object.`
}

phase('Inventory')
const results = await parallel(
  dimensions.map((d) => () =>
    agent(dimPrompt(d), {
      label: `inventory:${d.key}`,
      phase: 'Inventory',
      schema: DIM_SCHEMA,
    }).catch(() => ({ dimension: d.key, findings: '(agent errored or skipped)', evidence: [], gaps: ['inventory incomplete for this dimension'] }))
  )
)

const ok = results.filter(Boolean)
log(`Inventoried ${ok.length}/${dimensions.length} dimensions for ${a.repoPath} @ ${a.headSha}.`)

return {
  isInventoryOnly: true,
  note: 'Inventory only. /onboard-brownfield + Tech Lead write the baseline docs (CLAUDE.md, ADR, engineering-patterns, maturity-assessment) and decide any maturity claim — this workflow makes none.',
  repoPath: a.repoPath,
  headSha: a.headSha,
  dimensions: ok,
}
