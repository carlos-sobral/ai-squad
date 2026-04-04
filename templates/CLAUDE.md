# CLAUDE.md — [Project Name]

> This file tells Claude Code everything it needs to know about your project.
> Fill in the sections below. The more specific you are, the better the agents will work.
> Delete any section that doesn't apply to your project.

---

## What is this project?

[One paragraph describing the product: what it does, who uses it, and why it exists.]

---

## Stack

| Layer | Technology |
|---|---|
| Framework | e.g. Next.js, Django, Rails, FastAPI |
| Language | e.g. TypeScript, Python, Ruby |
| Database | e.g. PostgreSQL, MySQL, MongoDB |
| ORM | e.g. Prisma, SQLAlchemy, ActiveRecord |
| Auth | e.g. Supabase Auth, Auth0, custom JWT |
| Styling | e.g. Tailwind CSS + shadcn/ui |
| Tests | e.g. Playwright, Vitest, pytest |
| CI/CD | e.g. GitHub Actions + Vercel |

---

## Project structure

```
/
├── [describe your main folders here]
```

---

## Code conventions

### API Routes

[Describe the pattern your API routes follow. Example:]
- Auth: all routes check for a valid session before anything else
- Error format: `{ "error": { "code": "snake_case", "message": "Human readable" } }`
- Response keys: collections use plural (`users`), single resources use singular (`user`)

### Naming

[Any naming conventions that matter: file names, function names, variable names.]

### Tests

[Where tests live, what framework is used, what needs to be tested.]

---

## Authorization rules

[How your app handles multi-tenancy or user isolation. Example:]
- Every database query must filter by `organizationId`
- `organizationId` is always read from the authenticated session — never from the request body

---

## What NOT to do

[Hard constraints agents must never violate. Example:]
- Never use floating-point for monetary values — always use Decimal
- Never store uploaded files — process in memory and discard

---

## Agent Outputs

Agent outputs are saved here as a log of what was built and when.

<!-- Agents append entries here automatically -->
