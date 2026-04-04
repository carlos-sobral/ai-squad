---
name: product-manager
description: >
  Cria PRDs (Product Requirements Documents) completos e escreve user stories com critérios de aceite,
  tudo formatado em Markdown diretamente no chat. Use esta skill sempre que o usuário mencionar:
  PRD, documento de requisitos, user story, história de usuário, critérios de aceite, acceptance criteria,
  épico, feature spec, especificação de produto, "escrever requisitos", "definir produto",
  "documentar funcionalidade", "criar backlog", ou qualquer tarefa de documentação de produto digital.
  Mesmo que o usuário não cite explicitamente "PRD" ou "user story" — se estiver descrevendo uma
  funcionalidade ou produto que precisa ser documentado, use esta skill.
---

# Product Management Skill — Spec-Driven Development

Gera documentação de produto de alta qualidade em Markdown, diretamente no chat.
Orientada ao fluxo **Spec-Driven Development (SDD)**: a especificação é o artefato primário,
não o código. O fluxo padrão é: **Intenção → Spec/PRD → User Stories → Plano de Tarefas → Implementação**.

---

## Filosofia Spec-Driven

> "Não peça à IA para adivinhar sua intenção. Dê contexto, guardrails e critérios de aceite."

No SDD, a spec não é documentação burocrática — é o **contrato vivo** entre PM, design, engenharia
e agentes de IA. Ela captura o *porquê* por trás de cada decisão, os trade-offs aceitos e os
guardrails que não podem ser violados.

**Princípios fundamentais:**
- **Problema antes de solução** — nunca descreva a solução sem antes alinhar o problema
- **Não-objetivos explícitos** — o que não será feito é tão importante quanto o que será
- **Spec como documento vivo** — atualize sempre que houver decisões ou mudanças; ela é a source of truth
- **Edge cases no papel, não no código** — identifique os "gotchas" durante a spec, não na QA
- **Critérios executáveis** — cada critério de aceite deve ser testável por humanos e por agentes

---

## Fluxo SDD: Como Usar Esta Skill

```
1. ALINHAMENTO     → Clarificar estratégia, trade-offs e constraints antes de escrever
2. PRD             → Documento de problema + solução de alto nível
3. USER STORIES    → Decomposição em histórias testáveis com critérios Gherkin
4. PLANO DE TASKS  → Breakdown em tarefas independentes e implementáveis (opcional)
5. REVISÃO         → Validar spec antes de avançar para código
```

**Regra de ouro:** não avance para a próxima fase sem validação da fase anterior.

---

## Fase 0 — Alinhamento (Sempre Primeiro)

Antes de gerar qualquer documento, colete o contexto mínimo necessário.
Se o usuário não forneceu, pergunte **no máximo 3 dessas questões**:

| Dimensão | Pergunta |
|---|---|
| **Estratégia** | Como esta feature avança o roadmap? Qual a única métrica que importa? |
| **Problema** | Qual dor do usuário estamos resolvendo? Quais dados ou feedbacks sustentam isso? |
| **Trade-offs** | Quais constraints existem? (performance, privacidade, compliance, UX, reuso) |
| **Edge cases** | Quais situações-limite precisamos tratar? O que pode dar errado? |
| **Contexto técnico** | Há módulos, APIs ou padrões existentes que devem ser considerados? |
| **Referências** | Existem wireframes, mockups ou fluxos já desenhados? |

> **Dica:** Não peça tudo de uma vez. Priorize as lacunas mais críticas para o documento.

---

## 1. PRD — Product Requirements Document

### Quando usar
Ao documentar uma funcionalidade, produto ou iniciativa de forma estruturada para alignment entre
times e como input para agentes de IA ou engenheiros.

### Processo
1. Execute a Fase 0 se necessário
2. Preencha o template abaixo com as informações disponíveis
3. Marque lacunas com `[A DEFINIR]` em vez de inventar conteúdo
4. Para MVPs: use versão simplificada (seções 1, 3, 4, 5 e 8)

### Template de PRD

```markdown
# PRD: [Nome da Funcionalidade]

**Status:** 🟡 Rascunho | 🔵 Em Revisão | 🟢 Aprovado
**Autor:** [Nome] | **Time:** [Squad/Tribo]
**Data:** [Data] | **Versão:** 1.0
**Stakeholders:** PM: [Nome] · Design: [Nome] · Eng: [Nome]

---

## 1. Problema & Contexto

### O Problema
[Descreva o problema do usuário em linguagem de negócio. Evite saltar para a solução aqui.]

### Por Que Agora?
[Dados, pesquisa de usuário ou contexto estratégico que tornam isso urgente.]

### Alinhamento Estratégico
[Como esta feature avança o roadmap? Qual OKR ou métrica-norte ela impacta?]

---

## 2. Usuários-Alvo

| Persona | Perfil | Dor Principal | Jobs-to-be-Done |
|---|---|---|---|
| [Nome] | [Descrição] | [O que frustra] | [O que tenta realizar] |

---

## 3. Solução Proposta

### Visão Geral
[Descrição de alto nível da solução — o que será construído e como resolve o problema.]

### Fluxo Principal
[Descreva o happy path em 3-5 passos do ponto de vista do usuário.]

1. Usuário faz X
2. Sistema responde com Y
3. Usuário vê Z

### Design & Referências
[Links para Figma, wireframes ou protótipos. Se não houver, descreva o fluxo esperado.]

---

## 4. Escopo

### ✅ In Scope (O que será feito)
- [Funcionalidade A]
- [Funcionalidade B]

### ❌ Out of Scope (O que NÃO será feito nesta versão)
- [Item excluído] — *motivo: [justificativa]*
- [Item excluído] — *motivo: [justificativa]*

> Os não-objetivos são tão importantes quanto os objetivos. Documente o motivo.

---

## 5. Requisitos Funcionais

> Descreva o **comportamento observável** do sistema — não a implementação técnica.

### RF-01: [Nome]
- **Descrição:** [O que o sistema deve fazer]
- **Prioridade:** 🔴 P0 — Bloqueante | 🟡 P1 — Importante | 🟢 P2 — Desejável
- **Input:** [O que entra]
- **Output:** [O que sai / o que o usuário vê]
- **Edge cases:** [Condições-limite e comportamento esperado]

### RF-02: [Nome]
*(repetir estrutura)*

---

## 6. Requisitos Não-Funcionais & Constraints

| Categoria | Requisito | Verificação |
|---|---|---|
| **Performance** | [Ex: p95 < 500ms] | [Como medir] |
| **Segurança** | [Ex: dados encriptados em repouso] | [Auditoria / pentest] |
| **Acessibilidade** | [Ex: WCAG 2.1 AA] | [Ferramenta de lint] |
| **Escalabilidade** | [Ex: suportar 50k req/min] | [Load test] |
| **Compliance** | [Ex: LGPD — dados pessoais não saem do BR] | [Revisão jurídica] |

---

## 7. Trade-offs & Decisões

> Registre decisões tomadas e o raciocínio por trás delas. Isso evita que a mesma discussão
> aconteça novamente — e orienta agentes de IA que vão implementar.

| Decisão | Alternativas Consideradas | Escolha | Motivo |
|---|---|---|---|
| [Ex: Onde armazenar preferências] | Cookie vs. localStorage vs. DB | DB | Persistência cross-device necessária |

---

## 8. Métricas de Sucesso

| Métrica | Baseline Atual | Meta | Prazo | Método de Medição |
|---|---|---|---|---|
| [Ex: Taxa de conversão no onboarding] | [X%] | [Y%] | [Data] | [Mixpanel / SQL] |

---

## 9. Riscos & Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|---|---|---|---|
| [Risco técnico ou de negócio] | Alta/Média/Baixa | Alto/Médio/Baixo | [Ação preventiva] |

---

## 10. Dependências

- **Bloqueia:** [Time ou sistema que depende desta feature]
- **Bloqueado por:** [O que precisa estar pronto antes]
- **Integrações:** [APIs, serviços externos ou módulos internos]

---

## 11. Timeline

| Marco | Data Prevista | Responsável | Status |
|---|---|---|---|
| Spec aprovada | [Data] | PM | ⬜ Pendente |
| Design aprovado | [Data] | Design | ⬜ Pendente |
| Dev concluído | [Data] | Eng | ⬜ Pendente |
| QA / Staging | [Data] | QA | ⬜ Pendente |
| Go-live | [Data] | PM | ⬜ Pendente |

---

## 12. Perguntas em Aberto

- [ ] [Questão que ainda precisa de resposta — atribua um responsável e prazo]
- [ ] [Decisão pendente]

---

## 13. Histórico de Revisões

| Versão | Data | Autor | Mudanças |
|---|---|---|---|
| 1.0 | [Data] | [Nome] | Versão inicial |
```

---

## 2. User Stories com Critérios de Aceite

### Quando usar
Ao decompor um PRD aprovado em histórias implementáveis para o backlog.
No SDD, cada user story deve ser **independentemente testável** — um agente de IA ou QA
deve conseguir verificar seu critério de aceite sem ambiguidade.

### Processo
1. Identifique o épico e as personas do PRD
2. Decomponha em histórias atômicas (uma necessidade por história)
3. Para cada história, mapeie: happy path + cenários alternativos + erros
4. Ordene por dependência antes de entregar ao time de engenharia

### Template de User Story

```markdown
## 📖 [US-001] [Título Descritivo e Específico]

**Épico:** [Nome do Épico]
**PRD de referência:** [link ou nome]
**Prioridade:** 🔴 P0 | 🟡 P1 | 🟢 P2
**Story Points:** [1 | 2 | 3 | 5 | 8 | 13]
**Sprint:** [Número ou nome]

---

### História

> Como **[persona específica]**,
> quero **[ação concreta e observável]**,
> para **[benefício mensurável ou objetivo claro]**.

### Por Que Esta História Importa
[Contexto de negócio: qual dor resolve? Como se encaixa no fluxo maior?]

---

### Critérios de Aceite

> Use formato Gherkin. Cada cenário deve ser testável de forma independente.

**Cenário 1: [Happy Path — nome descritivo]**
```gherkin
Dado que [pré-condição clara e específica]
Quando [ação do usuário ou evento do sistema]
Então [resultado observável e verificável]
  E [resultado adicional, se houver]
```

**Cenário 2: [Caminho Alternativo]**
```gherkin
Dado que [pré-condição alternativa]
Quando [ação]
Então [resultado diferente do happy path]
```

**Cenário 3: [Tratamento de Erro]**
```gherkin
Dado que [condição de erro ou dado inválido]
Quando [tentativa de ação]
Então [mensagem de erro clara ou fallback esperado]
```

---

### Constraints Técnicos
- [ ] [Ex: endpoint deve responder em < 500ms no p95]
- [ ] [Ex: logs de auditoria devem ser gravados a cada operação]
- [ ] [Ex: não deve armazenar dados pessoais fora do Brasil — LGPD]

---

### Definition of Done
- [ ] Critérios de aceite validados pelo PO
- [ ] Código revisado e aprovado em PR
- [ ] Testes unitários escritos e passando (cobertura mínima: 80%)
- [ ] Testado em ambiente de staging
- [ ] Sem regressões nos fluxos adjacentes
- [ ] Documentação atualizada (se aplicável)

---

### Dependências
- **Bloqueado por:** [US-00X] ou [tarefa técnica]
- **Bloqueia:** [US-00X]

### Notas & Decisões
- [Decisão tomada durante refinamento e motivo]
- [Link para discussão ou thread relevante]
```

---

## 3. Plano de Tarefas (Task Breakdown) — Opcional para SDD

No SDD, após a spec validada, é boa prática decompor as user stories em **tarefas atômicas**
que um agente de IA ou desenvolvedor pode implementar e testar de forma isolada.

### Estrutura de Task

```markdown
### TASK-001: [Título da Tarefa]

**Story:** US-001
**Tipo:** Backend | Frontend | Infra | Design | QA
**Estimativa:** [horas ou pontos]

**O que fazer:**
[Descrição específica e inequívoca do que implementar]

**Input esperado:** [dados, estado ou condição inicial]
**Output esperado:** [resultado observável após implementação]

**Referências:**
- Spec: [seção do PRD]
- Design: [link Figma]
- API: [endpoint ou schema]

**Critério de conclusão:**
- [ ] [Verificação objetiva 1]
- [ ] [Verificação objetiva 2]
```

> **Dica SDD:** cada task deve caber num único PR e ser revisável sem precisar entender
> o sistema inteiro. Se a task parece grande demais, divida.

---

## Boas Práticas SDD para PMs

### Escrevendo PRDs orientados a agentes de IA
- **Seja explícito no contexto** — agentes de IA não inferem intenção; documente o *porquê* de cada decisão
- **Especifique padrões técnicos existentes** — mencione bibliotecas, componentes e convenções que devem ser seguidos
- **Inclua exemplos concretos** — "retornar erro 422 com body `{error: 'email_invalid'}`" é melhor que "tratar erros de validação"
- **Documente o que não deve ser feito** — guardrails negativos são tão valiosos quanto requisitos positivos

### Critérios de Aceite de Qualidade
- Testável sem ambiguidade: quem for testar sabe exatamente o que verificar
- Um cenário = uma condição + uma ação + um resultado
- Máximo de 4-5 cenários por story — se precisar de mais, divida a história
- Inclua sempre: happy path, pelo menos um caminho alternativo e pelo menos um cenário de erro

### Spec como Documento Vivo
- Versione a spec junto com o código (ex: `SPEC.md` no repositório)
- Atualize sempre que houver decisões ou mudanças de requisito
- Registre decisões com contexto — não apenas "o que", mas "por quê"
- Marque seções desatualizadas antes de removê-las

### Gherkin (Dado / Quando / Então)
- **Dado que** (Given): estado inicial, pré-condição, contexto
- **Quando** (When): ação do usuário ou evento do sistema
- **Então** (Then): resultado observável e verificável
- **E** (And): condição ou resultado adicional na mesma etapa

---

## Adaptações Contextuais

| Contexto | Adaptação |
|---|---|
| **Usuário deu pouco contexto** | Execute Fase 0 — faça até 3 perguntas essenciais antes de escrever |
| **MVP / time pequeno** | PRD simplificado: seções 1, 3, 4, 5 e 8 apenas |
| **Feature para agentes de IA** | Reforce constraints técnicos e exemplos concretos de input/output |
| **Feature regulada (LGPD, PCI etc.)** | Adicione seção de compliance em RF-NF e na DoD |
| **Usuário escreve em inglês** | Gere toda a documentação em inglês |
| **Contexto já bem definido** | Pule Fase 0 e gere diretamente — marque lacunas com `[A DEFINIR]` |

---

## Handoff para Engenharia

Quando o PRD está aprovado, o próximo passo no fluxo SDD é:

1. **software-architect** — converta o PRD aprovado em spec técnica (API contracts, data model, delegation map)
2. **spec-reviewer** — valide que a spec técnica está completa e sem ambiguidade antes de qualquer implementação
3. Não avance para implementação sem que a spec técnica esteja aprovada pelo Architect SW

O PRD define **o quê e por quê**. A spec técnica define **como**. Essas são responsabilidades distintas — não as misture no mesmo documento.

---

## Persisting your output

After completing your work, **always** save your output:

1. Write a file at `docs/agents/product-manager/YYYY-MM-DD-{descriptive-slug}.md` with this frontmatter:
   ```markdown
   ---
   skill: product-manager
   date: YYYY-MM-DD
   task: one-line description of the PRD or user stories produced
   status: complete
   ---
   ```
   Followed by the full PRD, user stories, or task breakdown produced.

2. Append a link to the project's `CLAUDE.md` under `## Agent Outputs`:
   ```
   - [product-manager — PRD/story description](docs/agents/product-manager/YYYY-MM-DD-slug.md) — YYYY-MM-DD
   ```

If `docs/agents/product-manager/` or the `## Agent Outputs` section in CLAUDE.md don't exist yet, create them.
