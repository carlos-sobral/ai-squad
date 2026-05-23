# Plano de Melhorias

Backlog vivo. Duas seções: a primeira é o backlog de evolução do SDLC (análise mais recente); a segunda guarda os itens de onboarding/setup do diagnóstico anterior.

---

# SDLC Evolution Backlog (2026-05-10)

Análise feita após audit paralelo do orchestrator flow, dos 13 agents e da infra de qualidade/métricas/automação. Itens organizados por leverage e custo.

## T1 — Quick wins (aditivas, baixo risco, dias)

### 1. Atualizar `MEMORY.md` do projeto
A única entry diz "skills planejadas" mas `agents-improvement-audit` e `sdlc-practices-evolve` já existem em `~/.claude/skills/` e já tiveram runs (2026-04-25, 2026-05-01). Memory está mentindo pra futuras conversas.

### 2. Refresh deste próprio `docs/improvements.md`
Lista item 1 (legacy) como feito com 12 agents — hoje são 13 (inclui `product-marketing-manager`). Itens 2–5 do backlog antigo estão estagnados há semanas. Promover ou descartar.

### 3. Slim down dos agents inchados (>800 linhas)
`backend-engineer` tem 20+ "Lessons from production use" — extrair pra `docs/agent-references/backend-engineer-lessons.md` e referenciar. Mesma análise pra `software-architect`, `security-engineer`, `cloud-architect`. Prompts grandes degradam aderência sem ganho proporcional.

### 4. Habilitar auto-research em mais 2 agents
Hoje 5 agents têm AR ativo; 8 estão "eval suite blocked". Os mais maduros pra desbloquear primeiro: `software-architect` (spec patterns são testáveis com fixtures de PRD→spec) e `product-manager` (PRD shape contra rubrica). Cada um destrava ~20% do framework.

### 5. Aggregator de `team-events/events.jsonl`
Os arquivos já existem por team mas ninguém lê. Script simples (`scripts/metrics/agent-usage.sh`) que rola sobre todos os events.jsonl e responde: qual agent foi mais invocado, qual gerou mais blockers, taxa de retro→diff conversion **por agent**. Hoje a retro→diff é métrica global em `collect.sh` mas não estratificada.

### 6. Versão do framework no `install.sh`
Não tem `--version`; impossível saber qual snapshot um projeto está usando. Adicionar tag de release + `install.sh --version` que ecoa o último commit.

---

## T2 — Adicionar capacidade (semanas)

### 7. Eval suites pros 8 agents bloqueados
Sem evals, auto-research não roda. Investimento direto pra cada um: 5–10 binary cases por agent, salvos no próprio frontmatter como `## Eval Suite`. O `auto-research` skill já lê esse formato. Esse é o gargalo número 1 do loop de melhoria contínua.

### 8. Modo `release` no `cloud-architect` (ou agent dedicado)
Hoje cloud-architect tem setup/inventory/review. Faltam: gerar release notes, bump de versão automatizado, changelog vs commits, validação de tag. Já tem retro lesson (commit `459a38f`) sobre "endpoint dry-run em release" — sinal de que o domínio é real.

### 9. Loop de feedback accept/reject
Auto-research e retros propõem diffs. O sistema sabe o que foi aplicado, mas não sabe se o usuário **reverteu depois** (fora da janela de eval) ou se reclamou. Hook simples: `git commit` em `~/.claude/agents/` com author=human + comentário com palavra-chave "revert/regression/wrong" → log estruturado em `~/.claude/logs/agent-feedback.jsonl`. `agents-improvement-audit` lê isso e ajusta thresholds.

### 10. Telemetria de invocação real
Quem chamou qual agent, quando, quanto durou, custo. Hoje `team-events` captura paralelos mas não captura invocações sequenciais. Hook em `~/.claude/settings.json` (PreToolUse no `Agent` tool) → linha em `~/.claude/logs/agent-invocations.jsonl`. Isso destrava analytics que hoje são impossíveis.

### 11. Formalizar Módulo 0 gate
O orchestrator menciona Módulo 0 (CI/CD setup via cloud-architect) mas o gate não é crisp: o que exatamente trava? Definir checklist binário (CI verde em PR de exemplo? deploy script idempotente? runbook de rollback?) e mover pro orchestrator como gate explícito antes de Módulo 1.

### 12. Spec→impl contract test
Quando `software-architect` produz spec com FR list, criar gate que valida estrutura (FRs numerados, AC binárias, contratos OpenAPI parseáveis) antes de dispatch pra backend/frontend. Falha cedo evita 30 min de implementação sobre spec vaga. Pode ser um lint Python simples sobre os specs.

### 13. Dry-run mode no `sdlc-orchestrator`
Antes de spawnar teams, mostrar: "vou invocar X agents nestas tiers, custo estimado Y, tempo estimado Z." Permite Tech Lead abortar caro/desnecessário. Especialmente útil em T3 (4-5 agents paralelos).

---

## T3 — Estrutural (decisão antes de seguir)

### 14. Disciplinas ausentes — quais entram?

| Disciplina | Proposta | Justificativa |
|---|---|---|
| Observability / SRE | Modo `operate` no cloud-architect ou agent novo `sre-engineer` | Hoje ninguém define alertas, SLOs, dashboards |
| Release engineering | Modo no cloud-architect (item 8) | Stretch do operate |
| Incident commander | Agent novo `incident-commander` | Runbook + RCA orchestration; quality-architect tem só RCA mode |
| Data / ML | Out-of-scope até projeto pedir | Não criar prematuramente |
| Accessibility specialist | Manter embedded em frontend+qa | Cobertura aceitável; dedicated seria over-engineering |
| FinOps | Modo de auditoria periódica no cloud-architect | Cost guardrails |
| Dependency hygiene | Modo no security-engineer (já roda CVE check) | Adjacente ao OWASP A06 |

### 15. Self-evolution scheduling
Hoje `agents-improvement-audit` e `sdlc-practices-evolve` são manuais. Decidir se viram cron (CronCreate) com cadência (semanal? mensal?). Risco: ruído auto-aplicado sem o usuário no loop. Mitigação: T1 auto, T2/T3 sempre escalado (já é a política das skills, mas sem trigger não roda).

### 16. Retrospective inter-módulos
Retro hoje é por-módulo. Padrões que aparecem em 3 módulos diferentes (ex: "QA achou bug que security deveria ter pegado" 3x) não disparam mudança estrutural. `sdlc-practices-evolve` cobre parcialmente, mas roda em cima de "estado da arte externo", não em cima de "padrões nos meus próprios retros". Adicionar mode "internal-pattern-mining" que lê todos os `docs/agent-evolution/*.md` e procura recorrência.

### 17. CI próprio do framework
O ai-squad é distribuído sem CI. Validações faltando: frontmatter dos `.md` parseável, install.sh idempotente, skills com seções obrigatórias presentes, eval suites referenciadas executam. GitHub Action simples que roda em PR.

### 18. Onboard-greenfield
`onboard-brownfield` existe; greenfield está como item 4 do backlog legacy. Vale completar: se a maioria dos projetos novos vai usar o framework do zero, o gap é maior do que parece.

---

## Conjunto recomendado se for atacar agora

Se quiser executar um subset coerente em 1-2 dias, o pacote de maior leverage é:

- **#1 + #2** (housekeeping de memória/improvements — 30 min)
- **#5** (aggregator de events.jsonl — 1h, destrava analytics)
- **#7** (eval suites pra software-architect e product-manager — 3-4h, destrava AR em ~25% dos agents)
- **#9 + #10** (loops de feedback — 2-3h, fecha o ciclo de aprendizado real)
- **#11** (Módulo 0 gate formalizado — 1h)

Total: ~1 dia de trabalho, fecha 3 dos gaps de observabilidade mais visíveis e destrava o motor de auto-melhoria pra mais agents.

---

# Onboarding & Setup Backlog (legacy — 2026-04)

Diagnóstico anterior, focado em bootstrap de projeto. Mantido aqui pra rastreabilidade.

## ~~L1. Custom Agents (`.claude/agents/`) — FEITO~~

13 agents criados em `agents/` com frontmatter (`name`, `description`, `model`). `install.sh` atualizado para copiar para `~/.claude/agents/`. Modelo roteado automaticamente por papel (Opus/Sonnet/Haiku). `refactoring-engineer` foi eliminado — sua funcionalidade agora é o Mode 5 (Refactor) do `software-architect`. Adicionado posteriormente: `product-marketing-manager`.

## L2. Template de projeto com `.claude/` pré-configurado — Aguardando priorização

**Problema:** O `install.sh` instala as skills globalmente, mas não configura o projeto do dev com `settings.json`, TeamMode ou `.claude/` adequado.

**Status:** Parcialmente coberto por `/onboard-brownfield` em brownfield. Para greenfield, ainda é manual — copiar `templates/CLAUDE.md` e editar `~/.claude/settings.json` manualmente.

**O que fazer (opcional):**
- Criar `init-project.sh` que pergunte greenfield vs brownfield
- Se greenfield: copiar template + guiar pré-requisitos
- Se brownfield: recomendar `/onboard-brownfield` e validar pré-reqs

## L3. MCPs úteis para o fluxo — Média prioridade

**Problema:** Nenhum MCP configurado. O fluxo spec-driven se beneficiaria de ferramentas externas integradas.

**O que fazer:**
- Avaliar e documentar MCPs relevantes para o processo:
  - **Asana MCP** — criar/atualizar tarefas diretamente do fluxo SDLC
  - **OpenAPI validator MCP** — validar contratos de API durante o review
  - **GitHub MCP** — criar PRs, comentar issues, verificar CI direto do fluxo
- Criar seção no README com MCPs recomendados e como configurá-los
- Adicionar configuração opcional ao `install.sh`

**Resultado esperado:** Devs podem integrar ferramentas do seu stack no fluxo agentic sem configuração manual.

## L4. Onboarding greenfield aprimorado — ver SDLC item #18

**Problema:** O README explica o que é o framework, mas não guia o dev no primeiro uso de forma prática.

**Status:** `/onboard-brownfield` cobre 100% do case brownfield. Para greenfield, falta guia step-by-step de setup + primeiro módulo. Item promovido para o SDLC Evolution Backlog como **item #18**.

## L5. Skill de setup/validação do ambiente — Baixa prioridade

**Problema:** Não há forma de um dev verificar se o ambiente está configurado corretamente.

**O que fazer:**
- Criar skill `setup-validator` que verifica:
  - Skills instaladas em `~/.claude/skills/`
  - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` habilitado
  - tmux disponível
  - `CLAUDE.md` do projeto preenchido com as seções obrigatórias
- Retorna relatório com o que está OK e o que precisa corrigir

**Resultado esperado:** Dev roda `/setup-validator` e sabe exatamente o que falta antes de começar.
