# ai-squad

**Uma squad de engenharia virtual para o seu projeto — movida por IA.**

ai-squad é um conjunto de "skills" para o [Claude Code](https://claude.ai/code) que transforma o assistente de IA em uma equipe completa: arquiteto de software, engenheiro backend, engenheiro frontend, designer, QA, gerente de produto e mais — cada um com um papel claro e um jeito estruturado de trabalhar.

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
- **Git** instalado
- Algum projeto de software para trabalhar (pode ser um projeto novo ou existente)

---

## Setup — 3 passos

### 1. Clone e instale as skills

```bash
git clone https://github.com/carlos-sobral/ai-squad.git
cd ai-squad
bash install.sh
```

O script copia as skills para `~/.claude/skills/`. Só isso.

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
│  software-architect (refactor mode) → cleanup     │         │
└───────────────────────────────────────────────────┼─────────┘
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

## Os agentes e seus modos

Alguns agentes têm **modos diferentes** dependendo do momento do projeto. É importante entender isso para saber o que pedir.

### `software-architect` — 2 modos

| Modo | Quando usar | O que produz |
|---|---|---|
| **Spec mode** | Antes da implementação | Especificação técnica detalhada: API contracts, modelo de dados, decisões arquiteturais |
| **Code review mode** | Depois da implementação | Revisão do código contra a spec original: bugs, desvios, problemas de qualidade |

```
# spec mode
/software-architect escreve a spec para o módulo X

# code review mode
/software-architect revisa a implementação do módulo X
```

---

### `product-designer` — 2 modos

| Modo | Quando usar | O que produz |
|---|---|---|
| **Design System Mode** | Uma vez por projeto, antes do primeiro módulo com UI | `docs/design-system.md` com cores, tipografia, espaçamentos, componentes — a fundação visual de todas as telas |
| **UX Spec Mode** | Uma vez por módulo com UI, depois do PRD | Especificação de telas: fluxos, estados, copy, acessibilidade, inventário de componentes |

O Design System Mode só precisa rodar uma vez. Depois disso, todos os módulos seguintes usam o sistema definido — não é preciso aprovar o visual de cada tela separadamente.

```
# design system mode (uma vez)
/product-designer cria o design system do projeto

# ux spec mode (por módulo)
/product-designer especifica as telas do módulo X
```

---

### `cloud-architect` — 2 modos

| Modo | Quando usar | O que produz |
|---|---|---|
| **Setup mode** | Uma vez por projeto, antes do primeiro deploy | Pipeline de CI/CD, script de setup local, documentação de variáveis de ambiente |
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

## TeamMode — agentes em paralelo com tmux (opcional, recomendado)

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

## Dica: o arquivo CLAUDE.md é o segredo

O arquivo `CLAUDE.md` na raiz do seu projeto é o que dá contexto a todos os agentes. Sem ele, cada agente começa do zero e pode fazer suposições erradas sobre o seu stack ou convenções.

Preencha bem as seções de stack, convenções e restrições. Você pode ir atualizando à medida que o projeto evolui — os agentes leem esse arquivo toda vez.

---

## Perguntas frequentes

**Preciso saber programar para usar isso?**
Algum background técnico ajuda bastante — entender o que está sendo gerado, saber revisar código, conseguir rodar o projeto localmente. Não é necessário ser um engenheiro sênior, mas zero contexto técnico vai dificultar na hora de validar o que foi entregue.

**Posso usar em projetos existentes?**
Sim. Coloque o `CLAUDE.md` na raiz, preencha com o contexto do projeto, e o `/sdlc-orchestrator` vai se adaptar ao que já existe.

**Funciona com qualquer linguagem/framework?**
Sim. As skills são instruções em linguagem natural — não são específicas para nenhum stack. O `CLAUDE.md` é onde você define qual stack o projeto usa.

**Quanto custa?**
As skills são gratuitas (este repositório é open source). Você precisa de uma assinatura Claude Pro ou acima para usar o Claude Code com volume razoável de trabalho.

---

## Estrutura do repositório

```
ai-squad/
├── skills/              # As skills — uma pasta por agente
│   ├── sdlc-orchestrator/
│   ├── software-architect/
│   ├── backend-engineer/
│   └── ...
├── templates/
│   └── CLAUDE.md        # Template para o seu projeto
├── install.sh           # Script de instalação
└── README.md
```

---

## Contribuindo

Issues e sugestões são bem-vindas. Se você testou com um stack específico e tem melhorias para propor, abra um PR.

---

## Licença

MIT
