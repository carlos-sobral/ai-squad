# UX Patterns — behavior registry

> **Owner:** `product-designer`. **Sibling of** [`docs/design-system.md`](design-system.md).
> `design-system.md` says how the product **looks**; this file says how a recurring **task behaves**.
> An entry cites design-system tokens and components by name — it never redefines a color, a size or a component.

## How this file is used

- **Created** by `product-designer` Design System Mode (greenfield: these seed entries, filled in) or extracted by Design System Documentation Mode (brownfield: filled from the existing UI, with every divergence flagged `[DIVERGENT]`).
- **Read before every UX spec.** UX Spec Mode opens with a *Pattern reuse table*: each user task in the PRD → the entry below that governs it (or `NEW`) → the screens that already do it. A screen that needs a behavior not listed here, or a variant not allowed here, updates this file **in the same PR** and logs the decision in the spec's Design Decisions Log.
- **Audited** by `product-designer` Consistency Audit Mode against the `qa-engineer` journey crawl (`docs/agents/qa-engineer/YYYY-MM-DD-journey-crawl/`). Divergences go to the product backlog; this file only changes when the canonical behavior itself changes.
- **Contract tests.** Each entry's reference screen has a pattern contract test at `tests/e2e/ux-patterns/<task-slug>.spec.ts` (`qa-engineer`, aria snapshot). It runs in every merge gate, and may be re-baselined **only in a PR that changes that same entry** — anywhere else a red contract test is a consistency finding, not a snapshot to update.
- **Section headings are a contract.** The journey crawl's contact sheet uses headings identical to the `## <task>` headings below; rename an entry and the crawl must follow in the same PR.
- **Terminology** lines are machine-read: they generate the Vale vocabulary used in CI (`use:` → accepted terms, `avoid:` → rejected terms). Keep the field name `Terminology` and the `use: … · avoid: …` shape.

## Entry format

```
## <task — what the user is doing, not the component>
- **Canonical behavior:** the one behavior every screen uses. Trigger → immediate response → success → failure → focus/navigation after.
- **Reference screen:** route `/…` · artboard `docs/design/canvas/<slug>.dc.html`
- **Allowed variants (and when):** each variant + the condition that permits it. "None" is a valid answer.
- **Terminology:** use: <canonical labels> · avoid: <synonyms seen or rejected>
- **Last reviewed:** YYYY-MM-DD — <module or audit that last confirmed it>
```

Unfilled values stay `[TO DEFINE]`. A brownfield divergence is written `[DIVERGENT: <screen A> does X, <screen B> does Y — canonical?]` and is resolved by the Tech Lead, never by picking silently.

---

## Create or edit a record (form, validation, submit)
- **Canonical behavior:** [TO DEFINE — when validation fires (on blur / on submit), where the field error appears (design-system Form pattern), what the submit button does while pending, where the user lands on success, what is kept on a server error]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE — e.g. inline single-field edit in a table row, only for one-field changes]
- **Terminology:** use: [TO DEFINE — e.g. Save] · avoid: [TO DEFINE — e.g. Submit, Confirm, OK]
- **Last reviewed:** [TO DEFINE]

## Delete or other destructive action
- **Canonical behavior:** [TO DEFINE — confirm-before (dialog) or act-then-undo (toast with Undo + window); which one is the default; where focus goes after the item disappears]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE — e.g. typed-name confirmation only when the action is irreversible AND cascades to other records]
- **Terminology:** use: [TO DEFINE — e.g. Delete] · avoid: [TO DEFINE — e.g. Remove, Erase, Trash]
- **Last reviewed:** [TO DEFINE]

## Find items in a list (filter, sort, search, paginate)
- **Canonical behavior:** [TO DEFINE — filter control (chips / side sheet / toolbar), live vs Apply, whether filter state lives in the URL and survives back/refresh, default sort, pagination vs infinite scroll, "clear filters" placement]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE]
- **Terminology:** use: [TO DEFINE] · avoid: [TO DEFINE]
- **Last reviewed:** [TO DEFINE]

## Empty, loading and error states
- **Canonical behavior:** [TO DEFINE — first-use empty vs no-results-after-filter (different copy and CTA); skeleton vs spinner rule (cite design-system Loading pattern); error with retry; what stays on screen while refetching]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE]
- **Terminology:** use: [TO DEFINE] · avoid: [TO DEFINE]
- **Last reviewed:** [TO DEFINE]

## Feedback after an action (toast vs inline)
- **Canonical behavior:** [TO DEFINE — which outcomes get a toast, which get inline feedback, which get none (the change itself is the feedback); duration; whether errors are ever toast-only]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE]
- **Terminology:** use: [TO DEFINE] · avoid: [TO DEFINE]
- **Last reviewed:** [TO DEFINE]

## Where a task opens (modal vs sheet vs page)
- **Canonical behavior:** [TO DEFINE — the rule that decides: e.g. ≤ N fields and no navigation inside → dialog; needs list context visible → side sheet; deep-linkable or long → page]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE]
- **Terminology:** use: [TO DEFINE] · avoid: [TO DEFINE]
- **Last reviewed:** [TO DEFINE]

## Leave a task (back, cancel, unsaved changes)
- **Canonical behavior:** [TO DEFINE — what Cancel does, what browser Back does mid-task, when an unsaved-changes guard appears, Escape in dialogs/sheets]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE]
- **Terminology:** use: [TO DEFINE] · avoid: [TO DEFINE]
- **Last reviewed:** [TO DEFINE]

## Choose an action (button hierarchy and placement)
- **Canonical behavior:** [TO DEFINE — one primary per view; order of primary/secondary in forms, dialogs and page headers; where destructive actions sit; cite design-system Button variants]
- **Reference screen:** route `[TO DEFINE]` · artboard `[TO DEFINE]`
- **Allowed variants (and when):** [TO DEFINE]
- **Terminology:** use: [TO DEFINE] · avoid: [TO DEFINE]
- **Last reviewed:** [TO DEFINE]
