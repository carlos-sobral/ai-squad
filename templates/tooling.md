# External tooling (MCPs + skills por agente)

Vários agentes do ai-squad sabem usar ferramentas externas (MCP servers e skills) **quando elas estão disponíveis** — e degradam graciosamente quando não estão. A regra é invariante para todos:

> **Toda ferramenta externa é opt-in, verificada via `/mcp` (ou lista de skills), e subordinada à fonte da verdade** (o código real do repo, o design-system.md, o tech spec, o julgamento do agente). Nenhuma ferramenta é dependência rígida; nenhuma é fonte de verdade paralela. Se ausente, o agente registra a lacuna e segue o fluxo padrão — nunca alucina o output.

## Tier A/B — seguras, recomendadas (vêm no `.mcp.json` ou são opt-in simples)

| Ferramenta | Tipo | Agente(s) | Papel | Setup |
|---|---|---|---|---|
| **shadcn registry MCP** | MCP lookup | frontend-engineer, product-designer | props/API reais de componentes (sem alucinação) | `.mcp.json` (automático) |
| **Context7 MCP** | MCP lookup | backend-eng, frontend-eng, software-architect, tech-writer | docs version-specific de 9000+ libs | `.mcp.json` (automático) |
| **Lighthouse MCP** | MCP análise | performance-engineer | executa auditorias lab (CWV/perf/a11y/SEO) — field data ainda governa o veredito | `.mcp.json` (automático) |
| **Sentry MCP** | MCP lookup | performance-engineer, quality-architect (RCA) | erros/releases/regressões reais de produção | `.mcp.json` + OAuth (`/mcp` → sentry → login) |
| **ui-ux-pro-max** | skill | product-designer | rascunho de paletas/font-pairings → filtrado pela §0 + anti-slop | opt-in (abaixo) |
| **Trail of Bits static-analysis** | plugin | security-engineer | dirige Semgrep/CodeQL/SARIF como engine do Pass 1 | opt-in (abaixo, precisa do binário) |
| **21st.dev Magic** | MCP geração | frontend-engineer | scaffold de componentes premium → re-expressos nos tokens do DS | opt-in (API key) |

### Setup do `.mcp.json` (shadcn, context7, lighthouse, sentry)

Copie o template para a raiz do projeto e confirme com `/mcp`:
```bash
cp <ai-squad>/templates/.mcp.json ./.mcp.json
```
Todos são keyless (npx) ou OAuth (sentry) — nenhum segredo no arquivo. Requer Node/npx no PATH. Sentry pede login interativo via `/mcp`.

### ui-ux-pro-max (skill opt-in, dep: Python 3)
```bash
npx -y skills add https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max
```
Acelerador subordinado do Design System Mode. Skill de terceiro — roda com permissões totais; revise antes de usar.

### Trail of Bits static-analysis (plugin opt-in, dep: semgrep/codeql)
```bash
claude plugin marketplace add trailofbits/skills
claude plugin install static-analysis@trailofbits
brew install semgrep   # o plugin DIRIGE o binário; ele não o empacota
```
O security-engineer usa como engine do Pass 1 — mas **só** quando o binário está no PATH (verifica antes). Ausência nunca bloqueia o review.

### 21st.dev Magic (MCP opt-in, precisa de API key)
```bash
claude mcp add magic --scope user --env API_KEY="SUA_KEY" -- npx -y @21st-dev/magic@latest
```

## Tier D — per-projeto, alto blast-radius (recipes, NÃO global)

Estas são **credential-bound** e tocam dado/infra viva — por isso ficam como recipe per-projeto **read-only**, nunca no `.mcp.json` global (evita segredo hardcoded e MCP de escrita sempre ativo). Wire por projeto, com escopo read-only quando o servidor suportar:

| Ferramenta | Agente | Cuidado |
|---|---|---|
| **Postgres/DB MCP** | backend-engineer | connection string por projeto; preferir usuário read-only; nunca commitar a string |
| **Cloud / Terraform / K8s MCP** | cloud-architect | usa credenciais ambientes; escopo read-only; revisar antes de qualquer apply |

Os agentes (`backend-engineer`, `cloud-architect`) referenciam essas ferramentas condicionalmente (verify-before-use); o projeto fornece a credencial no seu próprio `.mcp.json` local (git-ignored).

**Recipes concretas (config read-only, comandos, hard limits):** [`docs/integrations/data-and-infra-mcps.md`](../docs/integrations/data-and-infra-mcps.md).
