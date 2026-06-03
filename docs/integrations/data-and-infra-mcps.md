# Data & Infra MCPs — per-project recipes (read-only)

These MCP servers are **credential-bound and high blast-radius** — they touch live data (Postgres/DB) or live infrastructure (cloud/Terraform/K8s). For that reason ai-squad does **not** wire them globally: a global DB server needs a connection string hardcoded in the global config (a secret leak), and a global cloud server is a write-capable tool always loaded with no target project.

Instead they are **per-project recipes**, configured in the project's **local `.mcp.json`** (which must be git-ignored — it holds secrets), with three invariant rules:

1. **Read-only by default.** Use a read-only DB user / read-only IAM role / non-destructive mode flag. The agents are wired to *inventory and reason*, never to mutate.
2. **Verify before use.** The agent confirms the server is connected (`/mcp`) before relying on it; if absent it falls back to the standard flow. No hallucinated schema/state.
3. **Never write/apply through the MCP.** Migrations run through the project's migration tooling; infra changes run through the reviewed IaC pipeline. The MCP is for reading, not for `DROP`/`apply`.

The agents (`backend-engineer`, `cloud-architect`) reference these conditionally — they work without them and gain grounding when present.

**Decision matrix:**

| You are... | Wire |
|---|---|
| Backend work against a real schema you keep getting wrong from memory | Postgres/DB MCP (read-only user) |
| Brownfield infra inventory or IaC review against a live account | Cloud / Terraform / K8s MCP (read-only role) |
| Greenfield, no live data/infra yet | none — skip until there's something to read |

---

## Recipe 1 — Postgres / DB MCP (`backend-engineer`)

**When to use.** Backend implementation/review against an existing database where schema, column types, indexes, or constraints matter and recalling them from memory causes bugs.

**Local `.mcp.json` (git-ignored — connection string is a secret):**

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres",
               "postgresql://READONLY_USER:***@host:5432/dbname"]
    }
  }
}
```

**Setup.**
1. Create a **read-only** DB role (`GRANT SELECT` only; no INSERT/UPDATE/DELETE/DDL). Never point the MCP at a superuser.
2. Put the connection string in the project's local `.mcp.json`; confirm `.mcp.json` is in `.gitignore`.
3. `/mcp` to confirm `postgres` connected.

**What it covers.** Schema inspection, column types, indexes, constraints, sample read queries to validate assumptions. `backend-engineer` uses it to ground the data layer against reality instead of memory.

**Hard limits.** Read-only role enforced at the DB, not just by convention. Migrations and writes go through the project's migration tooling — never through the MCP. Alternatives with an explicit read-only mode: `crystaldba/postgres-mcp`.

---

## Recipe 2 — Cloud / Terraform / Kubernetes MCP (`cloud-architect`)

**When to use.** Brownfield infra inventory (Inventory mode) or IaC review (Review mode) against a live account/cluster, where reading actual state beats guessing from the repo alone.

**Local `.mcp.json` (representative — verify current package names + read-only flags before wiring):**

```json
{
  "mcpServers": {
    "terraform": { "command": "npx", "args": ["-y", "@hashicorp/terraform-mcp-server"] },
    "kubernetes": { "command": "npx", "args": ["-y", "mcp-server-kubernetes"] }
  }
}
```

For AWS, prefer the official **AWS Labs MCP** read-only servers (`awslabs/mcp`).

**Setup.**
1. Scope credentials **read-only**: a read-only IAM role / a `kubeconfig` pointed at a read context / Terraform pointed at state + registry docs, not at `apply`. Use the K8s server's non-destructive/read-only mode where available.
2. Credentials come from the ambient environment (AWS profile, kubeconfig) — do not hardcode secrets in `.mcp.json`.
3. `/mcp` to confirm connection.

**What it covers.** `cloud-architect` reads live resource inventory, drift between IaC and reality, and current cluster/state for Inventory and Review modes.

**Hard limits.** Never `terraform apply`, `kubectl delete/apply`, or any mutating cloud call through the MCP — those go through the reviewed CI/CD pipeline. The MCP is a read-only lens. Blast radius is the credential's scope, so the read-only role is the actual guardrail, not the prompt.
