# AGENTS.md — Global (ai-squad)

> Cópia OpenCode do `~/.claude/CLAUDE.md` (ai-squad) — plano "second brain agnóstico", decisão D3.
> **Altere as duas juntas** (a portagem pro `install.sh` do ai-squad é a Fase 3 do plano).
>
> **Adaptações para o OpenCode (público único deste arquivo):**
> 1. A seção "Agent invocation — named teammates" descreve mecânica do **Claude Code** (tmux, panes, `TaskStop`) — no OpenCode, subagentes vivem em `~/.config/opencode/agents/` (frontmatter `mode: subagent`) e são invocados pelo mecanismo nativo.
> 2. A coluna "Model" da tabela cita modelos do Claude Code; no OpenCode cada agente carrega o próprio `model` no frontmatter (`glm/glm` + variante).
> 3. Referências a `CLAUDE.md` de projeto viraram `AGENTS.md` — o OpenCode v2 não lê `CLAUDE.md`.

This directory contains a Spec-Driven Development (SDD) agent system: a set of AI agents that cover the full software development lifecycle, from idea to production deploy. Each agent is a specialized worker invoked at a specific stage of the flow.

**New here?** Read [`~/.claude/ONBOARDING.md`](~/.claude/ONBOARDING.md) first — it explains the full system, the SDLC flow, the agent reference table, and how to set up a new project.

---

## System architecture

The system has two types of components:

- **Skill (1):** `sdlc-orchestrator` — runs inline in the Tech Lead's conversation, orchestrates the flow
- **Agents (13):** all other roles — run as isolated workers with their own context windows

### Agents available

| Agent | One-line trigger | Model |
|---|---|---|
| `idea-researcher` | Raw idea that needs structure before becoming a PRD | opus |
| `product-manager` | Write a PRD or user stories | opus |
| `product-designer` | Design system setup or UX spec for a UI module | opus |
| `software-architect` | Technical spec, API contracts, ADRs, or code review | opus |
| `backend-engineer` | Implement backend from an approved tech spec | sonnet |
| `frontend-engineer` | Implement UI from a tech spec + UX spec | sonnet |
| `software-architect` (refactor mode) | Clean up code after implementation, no behavior change | opus |
| `security-engineer` | Security review of a PR or diff | opus |
| `quality-architect` | Define or audit quality guardrails | sonnet |
| `cloud-architect` | CI/CD setup (Módulo 0) or infra/IaC review | sonnet |
| `qa-engineer` | E2e verification before merge | sonnet |
| `tech-writer` | API docs, AGENTS.md updates, changelog | haiku |
| `performance-engineer` | Performance gate (first ship) or biweekly audit | sonnet |

### Skill available

| Skill | One-line trigger |
|---|---|
| `sdlc-orchestrator` | Start any feature, module, or hotfix — invoke via `/sdlc-orchestrator` |

### Slash patterns

| Pattern | One-line trigger |
|---|---|
| `/goal` | Hand off an in-flight goal to autonomous execution (after early phases complete) — see "Goal-driven autonomy" section below |

---

## Agent invocation — named teammates over loose subagents

> 🔒 **Seção específica do Claude Code** (tmux, panes, `TaskStop`, `SendMessage`): os nomes de tools e o modelo de processo abaixo não se aplicam ao OpenCode — lá, subagentes são os arquivos em `~/.config/opencode/agents/` invocados pelo mecanismo nativo da ferramenta. O princípio geral continua valendo: agentes paralelos ganham identidade; trabalho sequencial usa subagent simples; e encerre o agente quando o trabalho dele acabar.

### Parallel stages → named agents

When two or more agents run simultaneously, spawn each one as a **named agent** — `Agent({ name, subagent_type, model, prompt })` — sending them in ONE message so they run concurrently:

1. **Always** pass `name`. The name is what makes an agent a teammate: it is its address for `SendMessage`, it labels its pane, and it is how it shows up in `ListAgents`.
2. **Always** pass `model` explicitly — never rely on the default.
3. Check the **pane precondition before spawning** (below). Visibility is decided once, at spawn time; it cannot be fixed after the fact.
4. **Encerre o teammate quando o trabalho dele acabar** — `TaskStop({ task_id: "<nome>" })`. Mantenha vivo APENAS quando houver uma próxima instrução **clara e próxima** para ele. "Vai que eu preciso depois" não é motivo: o "depois" quase nunca vem, e o agente fica horas ocioso queimando memória. Não origine `shutdown_request` — é protocolo legacy e a própria tool manda não originá-lo; `TaskStop` é o mecanismo corrente.
5. **Named agents NÃO terminam sozinhos, e não são de graça.** Medido em 2026-08-28: um teammate `haiku` cuja tarefa inteira era responder uma palavra ficou residente em **~360 MB**, estado `Ss+`, e assim permaneceria indefinidamente. Cada teammate é um processo Node completo dentro de um tmux server dedicado (`claude-swarm-<pid-do-parent>`), não uma thread.
6. **`TaskStop` é irreversível quanto ao contexto.** Depois dele o nome deixa de resolver — `SendMessage` responde `No agent named '<nome>' is reachable`, e o transcript não é retomável. Esse é o trade-off aceito conscientemente: reabrir um agente novo passando o contexto necessário custa menos que segurar centenas de MB por uma opcionalidade que não se exerce.

**Deprecated — do not use:** `TeamCreate` and `TeamDelete` no longer exist (removed in Claude Code ~2.1.2xx; the binary keeps the names only to render old transcripts, classified as `expected-absent`). `team_name` on an `Agent` call is accepted and silently ignored — every session has ONE implicit team, on disk at `~/.claude/teams/session-<id>/`. Wherever a project doc still prescribes `TeamCreate`, that is drift: fix the doc.

### The pane precondition — check it BEFORE spawning

Claude Code picks a pane backend once per session, in this order: explicit `teammateMode` → inside tmux → iTerm2 with the `it2` CLI → tmux available ("external session mode") → in-process fallback.

**Observed on 2.1.239:** outside tmux, the backend is still selected as `tmux` and each agent is assigned a `tmuxPaneId` that does not exist — no server, no session, no pane. The agents do run, and `ListAgents` labels them `pane`, but there is no live progress channel: no pane to open, and completion arrives as a bare idle signal rather than the agent's result. The work is not lost — the output can still surface later as a teammate message, in one observed case ~8 minutes after the agent went idle and only after a `SendMessage` asking for it. From the Tech Lead's seat, though, it reads as an agent stuck on "processing". Do not re-spawn an agent on that basis; ask it for its result instead.

So, once per session, before the first parallel dispatch:

```bash
[ -n "$TMUX" ] || echo "NOT in tmux — parallel agents will run without visible panes"
```

If it comes back empty, say so in one line and let the Tech Lead choose: relaunch inside tmux (`tmux new-session -s <project>`, then `claude`), or proceed accepting that progress is visible only through the stage's event log.

### Sequential stages → a plain subagent is fine

When a single agent runs alone (e.g., `product-manager` producing a PRD, `software-architect` in refactor mode after implementation), a regular `Agent` call is enough. Pass `name` when you expect to talk to the agent again — it buys `SendMessage` plus a labelled pane. It is **not** free: naming makes it a teammate, and a teammate is a resident process you now own the teardown of (regra 4). Para trabalho de uma tacada só, sem conversa de volta, um `Agent` sem `name` devolve o resultado e não deixa processo para trás.

### Tasks are not agents

`/tasks` and the footer list every unit of background work, of three different kinds. Only one of them is an agent:

- **Background shell** (`Bash` with `run_in_background`) — a process, no model, no tokens. Appears in `/tasks` only.
- **Named agent** (`Agent`) — its own context and model. Appears in `/tasks` **and** `ListAgents`.
- **Monitor** — a shell emitting events. `/tasks` only.

If it is in `ListAgents`, it is an agent; if it is only in `/tasks`, it is a process. Do not describe a background shell to the Tech Lead as if an agent were working.

### Órfãos — o vazamento que nenhum agente fecha

O tmux server que hospeda os teammates tem `ppid 1`: ele é daemon, não filho do `claude`. Se a sessão parent morre mal ou é suspensa (`STAT=T`), ninguém executa o teardown e os teammates ficam vivos **para sempre** — um caso observado em 2026-08-28 rodava havia 16h, e sobrava no `/tmp/tmux-<uid>/` um socket de três dias antes.

Varra com `~/.claude/scripts/reap-orphan-teammates.sh` (dry-run por padrão; `--kill` executa, `--include-suspended` inclui parents apenas suspensos, que são retomáveis com `fg`).

### Never

- Spawn parallel agents without `name` — an unnamed agent cannot be addressed, labelled, or inspected
- Promise the Tech Lead visible panes without having checked `$TMUX`
- Call `TeamCreate` / `TeamDelete`, or pass `team_name` as if it did something

**Output style não alcança subagent.** Um subagent roda o próprio system prompt, então `outputStyle: Concise` vale só na conversa principal (fork é a exceção — herda o do pai). Concisão em agente é responsabilidade da definição do agente.

---

## Goal-driven autonomy — the `/goal` pattern

`/goal` is the **autonomous-handoff slash** for an in-flight goal. The Tech Lead writes a goal doc, runs the early phases interactively (typically PRD + clarify gate), then hands the rest of the SDLC flow off to a single `/goal` invocation that drives the squad to merge without per-handoff confirmation.

### When to use

- A goal doc exists at `docs/goals/<date>-<slug>.md` in the project repo.
- Early phases that benefit from human judgement are **already done** (idea brief, PRD, clarify gate when applicable). `/goal` is not the entry point for a brand-new goal — `/sdlc-orchestrator` is.
- Tech Lead wants the remaining flow (design → tech spec → impl → review → ship → retro) to run autonomously.

### Anatomy of the `/goal` prompt

The prompt MUST be **derived from the project's vision doc** (`docs/vision.md` or `docs/vision-*.md` — accept either naming), not improvised. The vision's non-negotiable principles become the only escape hatch from autonomy — see "Residual stop" below.

Required sections, in this order:

1. **Canonical docs to read** — goal doc, PRD, project `AGENTS.md`, vision doc. Pointers, never duplication.
2. **Current state** — what's already done (e.g., "clarify gate closed, N decisions locked, see goal doc table + PRD §X"). Make clear what is **frozen** vs still open.
3. **Goal-specific particularities the orchestrator can't infer** — Risk Surface declarations, carryovers from prior goals (e.g., known regressions that escaped past reviews), secrets/credentials handling, sub-questions deferred to downstream agents.
4. **Autonomy policy** — for each foreseeable blocker, name the owner agent and a retry cap. Typical:
   - Review BLOCK → re-spawn the owning engineer, loop max 3 per finding.
   - CI red → owning engineer fixes, loop max 3.
   - Smoke/E2E fails → impl team debugs in parallel (named agents), loop max 3.
   - Technical ambiguity → software-architect decides.
   - Product ambiguity (does NOT touch vision principles) → product-manager refines inline.
   - PR + merge are autonomous if all gates pass (CI green + critical reviews PASS/PASS_WITH_WARNINGS + smoke accepted + branch up-to-date).
5. **Residual stop list** — the small set of cases where autonomy must yield:
   - Tension with a vision principle (single-user, source-of-truth, identity, local-first, or whatever the project enshrines as non-negotiable) — escalate.
   - Manual human-only actions (third-party signups, OAuth consent, certificate creation, payment authorization) — pause once with clear instructions.
   - Any loop exceeding its retry cap — stop, summarize attempts, escalate.
6. **Definition of done** — concrete, checkable: PR merged + CI green + reviews passed + smoke accepted + docs updated + retro complete + next goal queued.

### What the prompt MUST NOT repeat

- The 6-phase SDLC flow → `/sdlc-orchestrator` knows it.
- Named-teammate vs plain-subagent rules, and the pane precondition → covered above in this file.
- Per-agent scope details → each agent reads PRD/UX spec/tech spec directly.
- Generic guardrails (PT/EN, branch protection, no `--force` without confirmation) → already global.

### Operational limit

`/goal` slash conditions are capped at **~4000 characters**. If your draft exceeds it, the first cuts should be repetition with sdlc-orchestrator knowledge, repetition with the goal doc, and per-agent scope (the agent will read the source). Never cut the residual-stop list or the autonomy policy — those are the guardrails.

### How the vision derivation works in practice

The vision doc defines **what the product is and is not**. When generating the `/goal` prompt:

- Lift the non-negotiable principles from the vision and turn them into the "tension with vision principle → escalate" entry of the residual stop list.
- If the goal touches a principle borderline (e.g., introduces a new external service in a local-first product), name it explicitly in "particularities" so downstream agents flag it rather than silently absorbing it.
- Roadmap context (what's next after this goal) goes into "definition of done → next goal queued", so the orchestrator can suggest the follow-up without re-reading the roadmap.

*Example — in the Avatar project (`/Users/carlos.sobral/github-repos/avatar`), the vision lives in `docs/vision-2026-2029.md` (principles in §13, roadmap in §11). Goal #2 Telegram-input derived its residual-stop list from §13: any tension with "single-user", "Mac primary as source-of-truth", "emergent identity", or "local-first with explicit cloud boundary" stops the autonomy. The roadmap's sequenced next goal (#3 Voice-in) is named in the done section so the orchestrator can hand off naturally.*

---

## Detector, não lembrete — as quatro que se perdem por acumulação

Estas quatro nasceram de um módulo em que **quatro dos oito achados tinham a regra já escrita no
repositório e violada assim mesmo** — uma delas pela 4ª vez em 30 dias, outra pela 2ª em 24h, e
duas por mim, no mesmo dia em que eu havia escrito que não repetiria. Regra sem verificação
mecânica não sobrevive à pressão da execução. As que funcionaram naquele módulo foram todas
detectores (uma catraca de CI, um select-spy, uma mutação); as que falharam foram todas
lembretes.

**1. Agente que muta a árvore recebe árvore própria.** Não é recomendação no prompt — é parte do
dispatch (`isolation: "worktree"`, ou `git worktree` como primeiro passo). Um revisor que aplica
mutação e um implementador que edita, na mesma árvore, produzem blocker inexistente: o revisor lê
a mutação do outro e reporta como defeito do código. Observado com dois agentes, e depois com
três. O prompt não deve pedir cuidado com a árvore; não deve haver árvore compartilhada para
estragar.

**2. Verificação entre tarefas é passo fixo, não decisão.** O orquestrador roda a suíte após cada
commit do implementador, **antes** de despachar a próxima tarefa. Medido: aceitar a contagem do
relatório deixou passar uma sentinela **vermelha** que o relatório afirmava verde (`31/31` real
`30/31`) — e o mesmo erro se repetiu na tarefa seguinte, depois de eu ter escrito que o número
tinha de ser meu. Parou quando virou passo fixo, não quando virou intenção. No relatório do
agente, **colar a saída** em vez de transcrever: é mais curto e não tem como divergir.

**3. Afirmação sobre infraestrutura carrega o comando que a produziu.** Ou é marcada como
suposição a verificar. É a mesma disciplina que já se exige de `file:line` em código. Observado:
inferir "o RDS é compartilhado" do nome do namespace, repassar ao gate de performance, escrever
no backlog — e descobrir três horas depois, ao medir, o banco era dedicado. O custo foi baixo
naquele caso; o mecanismo é o que produz o caro.

**4. Um teste que afirma invariância e assere cardinalidade é um cheiro.** Descrição do tipo
"não muda", "zero-diff", "nenhuma operação" com asserção única sobre **contagem** não exercita a
garantia que nomeia — trocar o valor de um item não muda a quantidade, e passa verde. É a classe
mais reincidente observada (4× em 30 dias, uma delas com as duas sentinelas irmãs **do mesmo
módulo** fazendo certo ao lado). Prefira comparar o **mapa** ou usar **piso** (`>=`), nunca
igualdade de contagem — contagem exata quebra o CI quando outro módulo acrescenta um item
legítimo, e aí alguém "conserta" o número e o teste vira ritual.

---

## Operational guardrails

Three rules that apply to every agent in every project. They override convenience and speed.

### Verification before completion claims

Opus 5 and later verify their own work unprompted, so this section no longer restates that. Two failure modes survive the model's native behavior, and only those are covered here.

**Quote the evidence next to the claim.** When you state that tests pass or a build is green, name the command and the result ("34/34 pass, exit 0"). This governs what the report contains, not whether an extra check gets run.

**A claimed artifact is verified with `ls`, not with the report of whoever produced it.** The report says what the agent believes it delivered; the filesystem says what exists. And there is a case no report covers: the artifact that was **due and never declared** — the agent narrowed its scope to what the prompt asked, delivered exactly that, and reported completion honestly. Nothing lied, and the artifact does not exist. So verify against the list of what was owed, not the list of what was promised. Measured across five projects: mandatory artifacts that some gate named by path were present in 5/5; artifacts that lived only inside an agent's own definition ran between 1/5 and 3/5.

**A subagent's "DONE" is not evidence.** When an agent reports success, confirm with the diff or the test output before relaying it upstream. The model verifies its own work; it does not verify someone else's.

**The tool that answers a question you didn't ask.** Self-verification catches the missing check. It does *not* catch the check that ran, passed, and answered something else — no red output, no exception, just a confident result about the wrong target. Before accepting any result, confirm the target was the intended one: working directory, revision, glob scope, generated artifacts in sync with source. A surprising result — empty test suite, suspiciously short file list, errors in a module you never touched — is evidence of a wrong target before it is evidence of a defect. Two real cases, same session: a shell `cd` that persisted across calls made a test runner start one directory too deep and report "no test files found" (looked like a broken suite); and a post-merge stale generated client produced a dozen type errors in another module's files (looked like a merge conflict). Both cost investigation time and both would have produced a false report if taken at face value. This cuts both ways: a green result on the wrong target is the more dangerous half, because nothing prompts you to look twice. Two tells are worth naming, because both read as reassurance: **uniformity of result** — the same verdict across four inputs that should have discriminated between them — is evidence of a wrong target before it is evidence of a robust defence (a probe that returned an identical code in all four cases turned out to have its arguments swapped, and one case became a real finding once it was rerun); and **a CI result has an age** — a green pipeline is a statement about the revision it ran against, so cite which SHA it ran on, or do not cite it.

### Code review reception

When you receive review feedback — from the user, from `software-architect` in review mode, from CI, from any subagent — respond with technical evaluation, not performative agreement.

**Forbidden phrases:** "You're absolutely right!", "Great point!", "Thanks for catching that!", "Let me implement that now" (before you've verified the feedback is correct for this codebase).

**Pattern instead:** read the full feedback → restate the technical requirement in your own words (or ask if unclear) → check it against the codebase reality → either acknowledge the fix tersely and apply it, or push back with technical reasoning. If anything in multi-item feedback is unclear, clarify everything before implementing anything — partial understanding produces wrong implementation.

When you fix something a reviewer caught, just state the fix: "Fixed in `path/file.ts:42` — was using the wrong key." No gratitude, no apologies. The code shows you heard the feedback.

When you pushed back and were wrong, correct factually and move on — no long apology, no defending why you pushed back.

### Writing or editing skills

Skills (`~/.claude/skills/*/SKILL.md`) are documentation that other agent instances will load and act on. Treat skill changes the same way you treat code changes: write a failing test first.

For a new skill:
1. Construct a pressure scenario that a future agent would face
2. Run the scenario against a subagent **without** the skill — document what the agent does wrong (the rationalizations, the shortcuts, the omissions)
3. Write the minimal skill that addresses those specific failures
4. Re-run the scenario **with** the skill loaded — verify the agent now complies
5. If the agent finds a new loophole, close it explicitly and re-test

For an edit: same cycle. "Just adding a section" is not exempt. Untested skill changes drift into noise that agents ignore.

**Description field rules:** start with "Use when…", describe triggering conditions only — never summarize the skill's process or workflow. A description that summarizes the workflow becomes a shortcut the agent takes instead of reading the skill body.

This applies to `.md` files under `~/.claude/skills/` and `~/.claude/agents/`. Editing this `AGENTS.md` is not bound by the rule — it is configuration, not a skill.
