# ai-squad

**Uma squad de engenharia virtual para o seu projeto — movida por IA.**

ai-squad é um conjunto de **12 agentes especializados** e **2 skills** para o [Claude Code](https://claude.ai/code) que transforma o assistente de IA em uma equipe completa: arquiteto de software, engenheiro backend, engenheiro frontend, designer, QA, gerente de produto e mais — cada um com um papel claro e um jeito estruturado de trabalhar.

Em vez de mandar um prompt solto e torcer pelo melhor, você segue um fluxo: **escreva o que quer construir → deixe o arquiteto planejar → deixe os engenheiros implementar → deixe o QA validar**. Cada etapa tem critérios de qualidade. O resultado é mais consistente e menos retrabalho.

---

## O que você vai conseguir fazer

- Descrever uma ideia em linguagem natural e receber um plano técnico detalhado
- Implementar features com agentes especializados (backend, frontend, QA)
- Ter gates de qualidade automáticos: revisão de segurança, testes, documentação
- Acumular aprendizados do projeto em um arquivo que os agentes consultam automaticamente

---

## Pré-requisitos

- **[Claude Code](https://claude.ai/code)** instalado (precisa de uma conta Claude — plano Pro ou acima)
- **tmux** instalado (`brew install tmux` no macOS, `apt install tmux` no Linux) — necessário para agentes rodarem em paralelo
- **Git** instalado
- Algum projeto de software para trabalhar (pode ser um projeto novo ou existente)

---

## Setup — 3 passos

### 1. Clone e instale

```bash
git clone https://github.com/carlos-sobral/ai-squad.git
cd ai-squad
bash install.sh
```

O script copia os agents para `~/.claude/agents/` e as skills para `~/.claude/skills/`.

### 2. Configure seu projeto

Copie o template de contexto para a raiz do seu projeto:

```bash
cp templates/CLAUDE.md /caminho/do/seu/projeto/CLAUDE.md
```

Abra o arquivo e preencha as seções: qual é o projeto, qual é o stack, quais são as convenções. Quanto mais específico, melhor. Esse arquivo é o que os agentes vão ler antes de fazer qualquer coisa.

### 3. Abra o Claude Code no seu projeto e comece

```bash
cd /caminho/do/seu/projeto
tmux new-session -s meu-projeto
claude --dangerously-skip-permissions
```

**Sobre os argumentos de lançamento:**

- **tmux** — obrigatório para os agentes rodarem em painéis paralelos (TeamMode). Sem ele, funciona mas roda em sequência.
- **`--dangerously-skip-permissions`** — pula as confirmações de permissão a cada tool call. Sem isso, o fluxo para dezenas de vezes pedindo aprovação manual para ler arquivos, rodar comandos, etc. Na prática, é inviável rodar o fluxo completo sem essa flag — os agentes fazem centenas de operações por módulo.

> **Nota:** use `--dangerously-skip-permissions` apenas em projetos pessoais ou de desenvolvimento. Em ambientes compartilhados ou de produção, avalie o risco. A flag desliga **todas** as confirmações de segurança.

Dentro do Claude Code, digite:

```
/sdlc-orchestrator
```

O orquestrador vai te guiar pelo resto.

---

## Como funciona — o fluxo completo

O `/sdlc-orchestrator` é quem guia tudo. Você não precisa chamar cada agente manualmente — ele te diz o que fazer em cada etapa.

```
┌─────────────────────────────────────────────────────────────┐
│  SETUP (roda uma vez por projeto)                           │
│                                                             │
│  cloud-architect    → configura CI/CD e infra               │
│  product-designer   → cria o design system visual           │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  DISCOVERY (opcional — para ideias ainda em aberto)         │
│                                                             │
│  idea-researcher    → pesquisa e estrutura a ideia          │
│  product-manager    → escreve os requisitos (PRD)           │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  DESIGN (para módulos com interface visual)                 │
│                                                             │
│  product-designer   → especifica telas, fluxos e copy       │
│  software-architect → define a solução técnica              │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  IMPLEMENTAÇÃO                                              │
│                                                             │
│  backend-engineer   ──────────────────────────────┐         │
│  frontend-engineer  → rodam em paralelo           │         │
└───────────────────────────────────────────────────┼─────────┘
                                                    ↓
┌─────────────────────────────────────────────────────────────┐
│  PÓS-IMPLEMENTAÇÃO (opcional)                               │
│                                                             │
│  software-architect (refactor mode) → cleanup sem mudar     │
│                                       comportamento         │
└─────────────────────────────────────────────────────────────┘
                                                    ↓
┌─────────────────────────────────────────────────────────────┐
│  REVISÃO                                                    │
│                                                             │
│  security-engineer  ──────────────────────────────┐         │
│  software-architect → revisão de código           │         │
│  quality-architect  → (opcional) guardrails de QA │         │
│  cloud-architect    → (opcional) se mudou infra   │         │
└───────────────────────────────────────────────────┼─────────┘
                                                    ↓
┌─────────────────────────────────────────────────────────────┐
│  ENTREGA                                                    │
│                                                             │
│  qa-engineer        → escreve e roda os testes             │
│  tech-writer        → documenta                            │
│  performance-engineer → (opcional) auditoria de perf       │
└─────────────────────────────────────────────────────────────┘
                         ↓
                   Merge para main
```

---

## Os 12 agentes

| Agente | O que faz | Modelo |
|---|---|---|
| `idea-researcher` | Pesquisa e estrutura ideias vagas antes do PRD | opus |
| `product-manager` | Escreve PRDs e user stories com acceptance criteria; suporta notação EARS para ACs event-driven | opus |
| `product-designer` | Design system + UX specs por módulo | opus |
| `software-architect` | Tech specs, code review, ADRs, refactor, diagramas | opus |
| `backend-engineer` | Implementa backend a partir de tech spec | sonnet |
| `frontend-engineer` | Implementa UI a partir de tech spec + UX spec | sonnet |
| `security-engineer` | Revisão de segurança (OWASP, CWE, ASVS); LLM security review (OWASP LLM Top 10:2025) | sonnet |
| `quality-architect` | Estratégia de testes e quality gates | sonnet |
| `cloud-architect` | CI/CD setup e revisão de infra/IaC | sonnet |
| `qa-engineer` | Testes e2e, verificação antes do merge | sonnet |
| `performance-engineer` | Gate de performance e auditorias periódicas | sonnet |
| `tech-writer` | Documentação de APIs, CLAUDE.md, changelog | haiku |

E **2 skills:**
- **`sdlc-orchestrator`** — guia o Tech Lead pelo fluxo completo de módulos, decide quais agentes rodar e quando, aplica gates de qualidade
- **`onboard-brownfield`** (novo) — onboarding de uma única vez em codebases pré-existentes, inventária stack + CI/CD + convenções + hotspots, produz baseline de documentação e maturity assessment

---

## Modos dos agentes

Alguns agentes têm **modos diferentes** dependendo do momento do projeto. É importante entender isso para saber o que pedir.

### `software-architect` — 4 modos

| Modo | Quando | O que produz |
|---|---|---|
| **Spec** | Antes da implementação | Tech spec (T1/T2/T3 ou delta), API contracts, diagramas Mermaid (`docs/architecture.md`), ADRs, mapa de delegação. Tudo que é pré-implementação. |
| **Code review** | Depois da implementação | Revisão do código contra a spec original: bugs, desvios, problemas de qualidade. Em codebases brownfield, distingue padrões pré-existentes de novos divergentes. |
| **Refactor** | Pós-implementação (opcional) | Cleanup de código sem mudança de comportamento: simplificar, renomear, remover dead code. Auto-recomendado quando diff toca hotspots documentados. |
| **Discovery** (novo) | Onboarding de brownfield | Lê a codebase existente, extrai stack, convenções, hotspots. Popula CLAUDE.md, cria baseline ADR e docs. Usado só via `/onboard-brownfield`. |

```
# spec mode (o orchestrator define o tier)
/software-architect escreve a spec para o módulo X

# code review mode
/software-architect revisa a implementação do módulo X

# refactor mode
/software-architect faz cleanup do código do módulo X
```

---

### `product-designer` — Design System + UX Specs

| Modo | Quando usar | O que produz |
|---|---|---|
| **Design System Mode** (greenfield) | Uma vez por projeto novo, antes do primeiro módulo com UI | `docs/design-system.md` com cores, tipografia, espaçamentos, componentes — a fundação visual de todas as telas |
| **Documentation Mode** (brownfield) | Uma vez em codebases existentes, durante onboarding | Extrai tokens e componentes da UI existente, marca pontos de divergência como [TO DEFINE], nunca modifica código |
| **UX Spec Mode** | Uma vez por módulo com UI, depois do PRD | Especificação de telas: fluxos, estados, copy, acessibilidade, inventário de componentes |

O Design System Mode (greenfield) ou Documentation Mode (brownfield) só precisa rodar uma vez. Depois disso, todos os módulos seguintes usam o sistema definido.

```
# design system mode (uma vez)
/product-designer cria o design system do projeto

# ux spec mode (por módulo)
/product-designer especifica as telas do módulo X
```

---

### `cloud-architect` — 3 modos

| Modo | Quando usar | O que produz |
|---|---|---|
| **Setup mode** | Uma vez por projeto novo, antes do primeiro deploy | Pipeline de CI/CD, script de setup local, documentação de variáveis de ambiente |
| **Inventory mode** (novo) | Durante onboarding brownfield | Lê workflows de CI/CD existentes, popula `## Tooling` no CLAUDE.md, documenta infraestrutura atual |
| **Review mode** | Ao revisar PRs que tocam em infra ou CI/CD | Revisão de segurança e conformidade de mudanças de infraestrutura |

```
# setup mode (uma vez)
/cloud-architect configura o CI/CD do projeto

# review mode
/cloud-architect revisa as mudanças de infra deste PR
```

---

### `performance-engineer` — 2 modos

| Modo | Quando usar | O que produz |
|---|---|---|
| **Gate mode** | Na primeira entrega de cada módulo | Veredicto de performance: aprovado / aprovado com ressalvas / reprovado |
| **Audit mode** | Periodicamente (ex: a cada 2 semanas) | Relatório completo de performance da aplicação |

---

## TeamMode — agentes em paralelo com tmux

Quando o `sdlc-orchestrator` roda dois agentes ao mesmo tempo (ex: backend + frontend), eles aparecem como **painéis divididos no terminal** — você vê o progresso de cada um em tempo real.

Para ativar, você precisa do **tmux** instalado e dois ajustes no `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "Preferences": {
    "tmuxSplitPanes": true
  },
  "teammateMode": "tmux"
}
```

Depois, sempre que for usar o Claude Code, abra dentro de uma sessão tmux:

```bash
tmux new-session -s meu-projeto
claude --dangerously-skip-permissions
```

Sem o tmux, os agentes ainda funcionam — rodam em sequência, sem os painéis. O TeamMode é opcional mas muda bastante a experiência. A flag `--dangerously-skip-permissions` é necessária para o fluxo rodar de forma autônoma — sem ela, cada operação de cada agente pede confirmação manual.

→ **Guia completo de instalação e configuração:** [TEAMMODE.md](./TEAMMODE.md)

---

## Gates de qualidade automáticos

O `sdlc-orchestrator` (v1.7) aplica **gates estruturados** em pontos críticos do fluxo:

### Clarify gate (T2/T3)
Após o PRD ser escrito, os top-5 pontos de ambiguidade são levantados antes da tech spec. Inspirado em [GitHub Spec Kit](https://github.com/github-community-projects/spec-kit). Em codebases brownfield, pergunta se você quer preservar comportamento legado bit-for-bit ou se é seguro mudar.

### Consistency-check gate (pré-merge)
Antes do merge, o `software-architect` compara PRD ↔ tech spec ↔ diff do PR e classifica deltas em 4 classes:
- **(a) Aligned** — especificação e código batem
- **(b) Minor drift** — desvios pequenos, recomendação vs bloqueador
- **(c) Divergent** — padrão novo conflita com especificação
- **(d) Undefined** — feature não estava na spec (requer revisão)
- **(e) Legacy preservation** (brownfield only) — mudanças intencionais ao código existente; exige citação de arquivo:linha

### Gates de observabilidade (post-deploy)
Contrato de observabilidade no tech spec (T2+): SLI/SLO + event schema + 2 alertas (1 SLO burn + 1 symptom). Pós-deploy, validação automática de saúde em +15min: query analytics + alertas + SLO ok. Configurável via `## Tooling > observability`.

---

## Integração com ferramentas externas — bloco `## Tooling`

A template de `CLAUDE.md` agora inclui um bloco **`## Tooling`** (YAML) que centraliza **toda** integração externa: issue tracker, repo host, CI/CD, chat, engineering metrics, observability. 

**Benefício:** mudar de GitHub para GitLab, ou de Slack para Discord, é editar uma linha. Agents leem deste bloco em vez de assumir ferramenta.

Providers suportados:

| Slot | Opções |
|---|---|
| `issue_tracker` | github, jira, linear, asana |
| `ci_cd` | github_actions, circleci, gitlab_ci |
| `observability > product_analytics` | posthog, mixpanel, amplitude |
| `observability > technical` | otel+grafana_cloud, datadog, honeycomb, new_relic |
| `observability > alerting` | pagerduty, opsgenie, slack_webhook, discord_webhook |
| `engineering_metrics` | ai-squad-local (default), devlake, linearb |

→ **Receitas de configuração:** [docs/integrations/engineering-metrics-providers.md](docs/integrations/engineering-metrics-providers.md)

---

## Engineering metrics — visibilidade do processo SDLC

Novo: `scripts/metrics/collect.sh` coleta **9 métricas DORA** + saúde de processo + sinais específicos de fluxo agentic:

```bash
scripts/metrics/collect.sh
# → docs/metrics/latest.md
# → docs/metrics/history/YYYY-MM.md
```

Inclui:
- Deployment frequency, lead time, MTTR, change failure rate
- Spec discipline (% modules com T2 antes de código)
- Review coverage (% PRs com code review, security review)
- Learning loop (retrospectivas, ADRs, atualizações de CLAUDE.md)
- Observability (SLI/SLO defined, alertas configurados)

Gráfico de maturidade: `templates/docs/maturity-assessment.md` — rubrica 5×4 (5 dimensões × 4 níveis: Ad-hoc → Otimizando). Baseline auto-reivindicado no onboarding brownfield.

---

## Suporte a brownfield — one-shot discovery + inventory

Para **codebases pré-existentes**, rode `/onboard-brownfield` uma única vez, antes de `/sdlc-orchestrator`:

```bash
/onboard-brownfield
```

Isso:
1. Cria um projeto descoberta paralelo (software-architect Mode 4 + cloud-architect Mode 3)
2. Inventária stack, CI/CD, convenções, hotspots
3. Popula baseline CLAUDE.md, ADR, engineering-patterns, maturity-assessment
4. Marca lacunas críticas como [TO DEFINE]
5. Recomenda Design System Documentation Mode se UI detectada

**Resultado:** seus agentes têm contexto real do codebase desde o primeiro módulo. Sem surpresas.

→ **Docs completos:** `skills/onboard-brownfield/SKILL.md`

---

## Dica: o arquivo CLAUDE.md é o segredo

O arquivo `CLAUDE.md` na raiz do seu projeto é o que dá contexto a todos os agentes. Sem ele, cada agente começa do zero e pode fazer suposições erradas sobre o seu stack ou convenções.

Preencha bem as seções de stack, convenções e restrições. Você pode ir atualizando à medida que o projeto evolui — os agentes leem esse arquivo toda vez.

---

## Perguntas frequentes

**Preciso saber programar para usar isso?**
Algum background técnico ajuda bastante — entender o que está sendo gerado, saber revisar código, conseguir rodar o projeto localmente. Não é necessário ser um engenheiro sênior, mas zero contexto técnico vai dificultar na hora de validar o que foi entregue.

**Posso usar em projetos existentes?**
Sim. **Para brownfield (codebase pré-existente):** rode `/onboard-brownfield` uma vez — ele inventaria tudo, popula o `CLAUDE.md` automaticamente com stack + convenções + hotspots. **Para greenfield:** coloque o `CLAUDE.md` na raiz, preencha com o contexto do projeto novo.

**Funciona com qualquer linguagem/framework?**
Sim. Os agentes são instruções em linguagem natural — não são específicos para nenhum stack. O `CLAUDE.md` é onde você define qual stack o projeto usa.

**Quanto custa?**
Os agentes são gratuitos (este repositório é open source). Você precisa de uma assinatura Claude Pro ou acima para usar o Claude Code com volume razoável de trabalho.

---

## Estrutura do repositório

```
ai-squad/
├── agents/                  # 12 agent definitions (.md) — modelo fixo por papel
│   ├── software-architect.md
│   ├── backend-engineer.md
│   ├── frontend-engineer.md
│   └── ...
├── skills/                  # 2 skills: sdlc-orchestrator + onboard-brownfield
│   ├── sdlc-orchestrator/
│   └── onboard-brownfield/
├── scripts/
│   └── metrics/             # collect.sh — coleta DORA + engineering metrics
├── templates/
│   ├── CLAUDE.md            # Template de contexto para o seu projeto
│   └── docs/
│       └── maturity-assessment.md  # Rubrica 5×4 de maturidade (baseline + audits)
├── docs/
│   └── integrations/        # Recipes de engineering-metrics providers
├── install.sh               # Instala agents + skills em ~/.claude/
├── TEAMMODE.md              # Guia de TeamMode com tmux
└── README.md
```

---

## Contribuindo

Issues e sugestões são bem-vindas. Se você testou com um stack específico e tem melhorias para propor, abra um PR.

---

## Licença

MIT
