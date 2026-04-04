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
claude
```

Dentro do Claude Code, digite:

```
/sdlc-orchestrator
```

O orquestrador vai te guiar pelo resto.

---

## Como funciona — o fluxo em resumo

```
Você tem uma ideia
       ↓
/sdlc-orchestrator    ← ponto de entrada, sempre
       ↓
product-manager       ← transforma a ideia em requisitos
       ↓
software-architect    ← define a solução técnica
       ↓
backend-engineer      ← implementa o servidor/API
frontend-engineer     ← implementa a interface      ← em paralelo
       ↓
security-engineer     ← revisão de segurança
software-architect    ← revisão de código           ← em paralelo
       ↓
qa-engineer           ← escreve e roda os testes
tech-writer           ← documenta                   ← em paralelo
       ↓
Pronto para fazer merge
```

Você não precisa chamar cada agente manualmente. O `/sdlc-orchestrator` sabe qual é o próximo passo e te diz o que fazer.

---

## Os agentes disponíveis

| Skill | O que faz |
|---|---|
| `/sdlc-orchestrator` | **Ponto de entrada.** Guia você pelo fluxo completo, decide quem chamar e quando |
| `/software-architect` | Transforma requisitos em especificação técnica; revisa implementações |
| `/product-manager` | Escreve PRDs e histórias de usuário com critérios de aceite |
| `/product-designer` | Define o design system do projeto; especifica telas e fluxos de UX |
| `/idea-researcher` | Pesquisa e estrutura ideias antes de virar requisito |
| `/backend-engineer` | Implementa APIs, banco de dados, lógica de negócio |
| `/frontend-engineer` | Implementa componentes e páginas seguindo o design system |
| `/qa-engineer` | Escreve e roda testes end-to-end; valida critérios de aceite |
| `/security-engineer` | Revisa código procurando vulnerabilidades |
| `/tech-writer` | Documenta APIs e decisões técnicas |
| `/performance-engineer` | Audita performance de frontend e backend |
| `/refactoring-engineer` | Limpa e simplifica código sem mudar comportamento |
| `/cloud-architect` | Configura CI/CD e infraestrutura |
| `/quality-architect` | Revisa qualidade dos testes e guardrails do projeto |

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
