---
name: deliberate-confrontation
description: "Use when a high-stakes decision in the SDLC would benefit from a second, genuinely different angle before it locks in — a T3 module, a PRD/spec with real ambiguity, a high-cost-of-error surface (critical risk, external audience, regulated), or a recurring blocker in the retrospective. Runs a structured confrontation between the author of an artifact and a challenger with a different role perspective, then hands the decision to the Tech Lead. Covers two points in the flow: the CREATION phase (idea brief, PRD, tech spec — where today only self-review exists) and the REVIEW phase (code review — where the review-team already fans out but does not confront). NOT for objective verification gates (CI, perf, tests) — those have a fact, not a debate. NOT a default on every module — it is triggered, never routine."
---

# Deliberate Confrontation — second angle on high-stakes decisions

You run a **structured confrontation** between the author of an SDLC artifact and a challenger who brings a genuinely different role perspective, so the Tech Lead decides with both sides argued — not with a single self-reviewed angle.

This is grounded in the multi-agent debate literature: Du et al. 2023 (arXiv:2305.14325) showed multiple agents debating improves reasoning and reduces hallucination; Khan et al. 2024 (arXiv:2402.06782) showed a non-expert judge picks the truth better when two experts argue opposite sides (76% vs 48% baseline). The value is **two well-argued sides informing a judge** — not "more votes."

## Non-negotiable boundaries (read first)

1. **The confrontation INFORMS — it never DECIDES.** The final verdict is always the Tech Lead's (and, for merge/ship, the orchestrator's). You produce a recommendation; you never emit a gate verdict. This is the same boundary rule the `sdlc-orchestrator` enforces for its workflows.
2. **Angles must be genuinely different roles, not copies of the same role.** The value comes from product-vs-technical-vs-marketing perspectives, not from N instances of the same agent (which share the same bias and only reduce variance, not systematic error — see orchestrator conventions).
3. **Triggered, never routine.** Run only when a trigger fires (below). Adding confrontation to every module is over-engineering and violates the "add complexity only when it improves outcomes" principle.
4. **Never wrap an objective verification gate** (CI, perf gate, tests, a `MANUAL_PENDING` invariant). Those have a fact; there is nothing to debate. The orchestrator already forbids this ("Judgment gates are NOT a fifth fit").

## Triggers — run when ANY fires

| Trigger | Where it fires |
|---|---|
| **T3 module** (complex, multi-subsystem, public contract, regulated) | Creation phase |
| **Real ambiguity declared** — PRD or tech spec flags open questions that materially change the shape | Creation phase |
| **High cost of error** — Risk Surface `critical`/`full`, external audience, regulated domain, payments/PII | Creation + Review |
| **Recurring blocker** — the same failure class appeared in 3+ modules (from retros) | Retrospective → next module |
| **Tech Lead requests it** | Any point |

Skip silently when none fire. Do not invent a trigger to justify running.

## Angles by phase

Pick the challenger whose perspective is most likely to catch the author's blind spot. The author defends; the challenger attacks the premises.

| Phase | Author (defends) | Challenger (attacks) | What the challenger contests |
|---|---|---|---|
| **Idea brief** | `idea-researcher` | `product-manager` | Is the problem real? Are the target users right? Does the proposed solution actually solve it? Is the "why now" credible? |
| **PRD** | `product-manager` | `software-architect` (viability) + `product-marketing-manager` (value/positioning) | Is it technically feasible? Are the trade-offs sound? Does it deliver value the user will pay attention to? Is the scope right? |
| **Tech spec** | `software-architect` | a second architectural angle (another `software-architect` invocation framed adversarially, or `cloud-architect` when infra is involved) | Are the trade-offs right? Were alternatives genuinely considered? Is the design sound under the declared Risk Surface? |
| **Code review** | the implementation | `security-engineer` (security) / `quality-architect` (test quality) — the angles the review-team already fans out | Does the code meet the spec? Are there security/test-quality gaps the author's self-review missed? |

## The confrontation format

Keep it bounded — one round of attack + one round of rebuttal, then the Tech Lead decides. Do not let it spiral into endless rounds.

1. **Author presents** the artifact (brief / PRD / spec / diff) with its key claims and trade-offs.
2. **Challenger attacks** — contests the premises, names the blind spots, proposes alternatives. The challenger must be specific ("the target user is wrong because X", "this trade-off is unsound because Y"), not generic ("have you considered the user?").
3. **Author rebuts** — accepts what's valid, pushes back with reasoning on what isn't.
4. **You synthesize** — a short recommendation: what the confrontation changed (if anything), what the author conceded, what remains contested.
5. **Tech Lead decides** — the final call is theirs. You record the decision and any artifact amendments.

## Output

Save a short record to `docs/agents/deliberate-confrontation/YYYY-MM-DD-{slug}.md` with frontmatter (`skill: deliberate-confrontation`, `date`, `phase`, `author`, `challenger`, `trigger`, `decision`), then a 5-10 line summary: the contested points, what changed, what the Tech Lead decided. This feeds the retrospective and the metrics.

## Relationship to the rest of ai-squad

- **`sdlc-orchestrator`** decides when to invoke this skill (it owns the triggers). This skill runs the confrontation; the orchestrator + Tech Lead own the verdict.
- **`review-team`** already fans out multiple angles in parallel (worst-verdict-wins). This skill is the *interactive* complement — it adds the attack/rebuttal exchange that the fan-out does not have. Use the fan-out for breadth; use this for depth on the few decisions that warrant it.
- **`idea-researcher` / `product-manager` / `software-architect`** are the authors. Their existing self-review (e.g. idea-researcher Step 5b) stays — this skill adds the *external* angle their self-review cannot provide.
- **Retrospective gate** consumes the output: a recurring blocker that triggered a confrontation should produce a diff to the owning agent's definition.

## Verification before you claim done

The claim "confrontation complete" requires evidence in the same message: the contested points, the challenger's specific objections, the author's rebuttals, and the Tech Lead's decision. No "both sides were heard" — show the substance.
