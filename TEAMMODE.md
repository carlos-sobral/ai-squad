# TeamMode — Agentes em paralelo com painéis

Quando o `sdlc-orchestrator` roda dois ou mais agentes ao mesmo tempo (ex: `backend-engineer` + `frontend-engineer`), cada um pode aparecer como um **painel dividido no terminal**. Você vê o progresso de cada agente em tempo real, lado a lado.

Sem isso os agentes ainda rodam — mas **sem nenhuma visibilidade de andamento**, e é aí que mora a armadilha descrita em "A precondição que ninguém checa" abaixo.

> **Não existe mais `TeamCreate`.** Um agente vira teammate simplesmente por receber `name` na chamada do `Agent`: `Agent({ name: "backend", subagent_type: "backend-engineer", model: "sonnet", prompt: "..." })`. O `name` é o endereço dele no `SendMessage`, o rótulo do painel e a forma como ele aparece no `ListAgents`. Cada sessão tem **um team implícito** (em `~/.claude/teams/session-<id>/`) — nada pra criar, nada pra deletar. `TeamCreate` e `TeamDelete` foram removidas no Claude Code ~2.1.2xx; `team_name` numa chamada de `Agent` é aceito e silenciosamente ignorado.

---

## O que você precisa

- **tmux** (ou **iTerm2** com o CLI `it2` — ver abaixo)
- **Claude Code** com a variável de ambiente `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Uma chave no `~/.claude/settings.json`

---

## Instalação

### macOS

```bash
brew install tmux
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install tmux
```

### Windows

TeamMode com tmux não é suportado nativamente no Windows. Use o **WSL 2** (Windows Subsystem for Linux) com Ubuntu e instale o tmux dentro do WSL.

---

## Configuração do Claude Code

Abra (ou crie) o arquivo `~/.claude/settings.json` e adicione estas linhas:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux"
}
```

Se o arquivo já existe com outras configurações, adicione apenas as chaves que faltam — não substitua o arquivo inteiro.

`teammateMode` aceita três valores:

| Valor | Efeito |
|---|---|
| `"tmux"` | painéis via tmux — o caminho recomendado |
| `"iterm2"` | painéis nativos do iTerm2; exige `pip install it2` **e** a Python API habilitada (Preferences > General > Magic) |
| `"in-process"` | sem painel; o agente roda embutido na sessão |

> **`Preferences.tmuxSplitPanes` não existe mais.** Versões antigas deste doc pediam essa chave; ela não aparece em nenhum lugar do binário do Claude Code 2.1.239. Se estiver no seu `settings.json`, é inofensiva — mas não faz nada. A chave que decide é `teammateMode`.

### Como o backend de painel é escolhido

A decisão acontece **uma vez por sessão**, nesta ordem:

1. `teammateMode` explícito no settings
2. Claude rodando **dentro** de uma sessão tmux
3. iTerm2 com o CLI `it2` disponível
4. tmux instalado ("external session mode")
5. fallback in-process — sem painel

---

## Comando de lançamento recomendado

```bash
tmux new-session -s meu-projeto
claude --dangerously-skip-permissions
```

### Por que `--dangerously-skip-permissions`?

O fluxo SDLC completo envolve dezenas de agentes fazendo centenas de operações: leitura de arquivos, execução de builds, escrita de specs, criação de testes. Sem essa flag, o Claude para em **cada operação** pedindo confirmação manual — tornando o fluxo inviável.

Com a flag, os agentes trabalham de forma autônoma. O Tech Lead supervisiona pelos outputs e gates de qualidade, não aprovando cada `cat` ou `npm test`.

> **Nota de segurança:** use apenas em projetos pessoais ou de desenvolvimento. A flag desliga todas as confirmações — incluindo operações destrutivas como `rm` ou `git push --force`. Em ambientes compartilhados, avalie o risco.

---

## Como verificar que está funcionando

1. Abra o terminal
2. Inicie uma sessão tmux:
   ```bash
   tmux new-session -s meu-projeto
   ```
3. Abra o Claude Code dentro do tmux:
   ```bash
   claude --dangerously-skip-permissions
   ```
4. Chame o orquestrador em uma situação que roda agentes em paralelo (ex: uma feature com backend + frontend). Os painéis devem aparecer automaticamente divididos na tela.

---

## A precondição que ninguém checa

O Claude Code precisa estar rodando **dentro** de uma sessão tmux **antes** do primeiro spawn. A escolha do backend acontece uma vez, no spawn — não tem como consertar depois.

E o modo de falhar é traiçoeiro. Testado no Claude Code 2.1.239, fora do tmux:

- o backend é selecionado como `tmux` mesmo assim;
- cada agente recebe um `tmuxPaneId` (`%2`, `%3`) que **não existe** — sem servidor, sem sessão, sem painel;
- o `ListAgents` rotula os agentes como `pane`;
- os agentes **rodam**, mas não há canal de progresso ao vivo: não existe painel pra abrir, e o fim chega como um sinal seco de idle em vez do resultado do agente.

Da cadeira do Tech Lead isso é indistinguível de um agente travado: você entra no item do rodapé e não há nada além de "processando". Não é bug seu, e não é sequencialização — é um painel prometido que nunca materializou.

**O trabalho não se perde.** O output ainda pode chegar depois, como mensagem de teammate — num caso observado, ~8 minutos após o agente ficar idle e só depois de um `SendMessage` pedindo. Então **não re-spawne** um agente por causa do silêncio: peça o resultado a ele primeiro.

**Checagem, uma vez por sessão, antes do primeiro dispatch paralelo:**

```bash
[ -n "$TMUX" ] || echo "NOT in tmux — agentes paralelos vão rodar sem painel visível"
```

Se voltar vazio, há duas opções honestas:

1. **Relançar dentro do tmux** — `tmux new-session -s <projeto>` e depois `claude`. É o caminho recomendado.
2. **Seguir sem painel**, sabendo que o progresso só vai aparecer no event log da etapa (`.claude/team-events/<stage>/events.jsonl`). O JSONL é o único canal que funciona independente de backend, de painel e de compactação de contexto.

O que **não** é opção é prometer painéis sem ter rodado a checagem.

---

## Como fica na prática

Quando o `sdlc-orchestrator` spawna dois agentes em paralelo, o terminal divide automaticamente:

```
┌─────────────────────────┬─────────────────────────┐
│                         │                         │
│   backend-engineer      │   frontend-engineer     │
│                         │                         │
│   Implementando API...  │   Criando componentes.. │
│                         │                         │
│                         │                         │
└─────────────────────────┴─────────────────────────┘
```

Cada painel roda de forma independente. Quando os dois terminam, o orquestrador consolida os resultados e te diz o próximo passo.

---

## Task, agente ou workflow — três coisas no mesmo rodapé

O `/tasks` e o rodapé do terminal listam **todo** trabalho de fundo, de três tipos diferentes. Só um deles é agente, e confundi-los leva a interpretar mal o que está acontecendo:

| O que aparece | O que é | Custo de modelo | Onde inspecionar |
|---|---|---|---|
| Shell em background (`Bash` com `run_in_background`) | um processo, sem modelo | zero | `/tasks` (arquivo de output) |
| **Agente nomeado** (`Agent({ name })`) | contexto e modelo próprios | tokens | `/tasks` **e** `ListAgents` |
| Monitor | shell que emite eventos | zero | `/tasks` |

Regra prática: **se está no `ListAgents`, é agente; se só está no `/tasks`, é processo.** E o Workflow tool é um quarto regime — seus agentes não aparecem em painel nenhum: a visibilidade deles é o `/workflows`.

---

## Atalhos úteis do tmux

Se quiser navegar entre os painéis manualmente:

| Ação | Comando |
|---|---|
| Mover entre painéis | `Ctrl+B` → seta direcional |
| Fechar painel atual | `Ctrl+B` + `X` |
| Maximizar painel | `Ctrl+B` + `Z` (toggle) |
| Ver todos os painéis | `Ctrl+B` + `W` |
| Desanexar sessão (sair sem fechar) | `Ctrl+B` + `D` |
| Reabrir sessão salva | `tmux attach` |

---

## Troubleshooting

**Os painéis não aparecem:**
- Verifique se está dentro de uma sessão tmux: `echo $TMUX` — deve retornar um caminho, não ficar vazio
- Verifique se `settings.json` tem `teammateMode` e a env var (`Preferences.tmuxSplitPanes` é chave morta — ver acima)
- Reinicie o Claude Code após editar o `settings.json`

**Erro "tmux: command not found":**
- Instale o tmux conforme a seção acima

**Painel abre mas fecha imediatamente:**
- Geralmente é um erro no início do agente — role o histórico do painel antes de fechar para ver a mensagem de erro

---

## Worktree safety — checklist antes de criar workspace isolado

Antes de criar um worktree (manual ou via ferramenta nativa como `EnterWorktree`), o agente deve passar por três checagens. Pular qualquer uma delas tipicamente causa retrabalho ou polui o repo.

### 1. Detectar isolamento existente

Antes de criar qualquer coisa, verificar se já está em um workspace isolado:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

Se `GIT_DIR != GIT_COMMON`, você já está em um worktree linkado — **não criar outro**, seguir para o setup.

**Guard contra submódulos:** o mesmo teste é positivo dentro de submódulos. Antes de concluir "já é worktree", confirmar:

```bash
git rev-parse --show-superproject-working-tree 2>/dev/null
```

Se retornar um path, é submódulo (tratar como repo normal), não worktree.

### 2. Preferir ferramentas nativas sobre `git worktree add`

Se o ambiente expõe uma ferramenta nativa de worktree (`EnterWorktree`, `WorktreeCreate`, `/worktree`), usar ela. Rodar `git worktree add` quando a ferramenta nativa existe cria estado fantasma que o harness não consegue rastrear nem limpar.

`git worktree add` é fallback — só usar quando não há ferramenta nativa disponível.

### 3. Verificar que o diretório está ignorado (apenas worktrees project-local)

Antes de criar um worktree em `.worktrees/` ou `worktrees/` no projeto:

```bash
git check-ignore -q .worktrees 2>/dev/null || git check-ignore -q worktrees 2>/dev/null
```

**Se não estiver ignorado:** adicionar ao `.gitignore`, commitar, e só então criar. Pular esse passo polui `git status` com centenas de arquivos do worktree.

Worktrees em diretórios globais (`~/.config/...`) não precisam dessa verificação.

### Quick reference

| Situação | Ação |
|---|---|
| `GIT_DIR != GIT_COMMON` e não é submódulo | Já em worktree — pular criação |
| Em submódulo | Tratar como repo normal |
| Ferramenta nativa disponível | Usar ela (não `git worktree add`) |
| `.worktrees/` ou `worktrees/` não está em `.gitignore` | Adicionar + commitar antes de criar |
| Erro de permissão ao criar | Sandbox bloqueou — trabalhar no diretório atual e avisar o user |

---

## Quando dispatch paralelo vale (vs sequencial)

Spawnar N agents nomeados numa única mensagem os roda simultaneamente. Mas paralelizar problemas relacionados desperdiça contexto e gera conflitos. A decisão é binária: **os domínios são independentes?**

### Decision tree

```
Múltiplas tarefas/falhas?
  ├─ sim → São independentes?
  │        ├─ não (relacionadas) → 1 agent investiga todas em sequência
  │        └─ sim → Podem rodar sem estado compartilhado?
  │                 ├─ sim → Paralelo: 1 agent por domínio
  │                 └─ não → Sequencial (evita interferência)
  └─ não → Agent único
```

### Use paralelo quando

- 3+ test files falhando com causas diferentes
- Backend + frontend de uma feature avançam sem compartilhar arquivo
- Investigações em subsistemas que não se tocam (auth vs billing vs notifications)
- Cada problema é compreensível sem o contexto dos outros

### Não use paralelo quando

- Falhas podem ter causa raiz comum (fixar uma pode resolver outras — investigar junto primeiro)
- Agents precisariam editar o mesmo arquivo (conflito garantido)
- A tarefa exige entender o sistema inteiro como uma peça
- Você ainda não sabe o que está quebrado (debug exploratório é sequencial)

### Estrutura de cada agent paralelo

Cada agent precisa de prompt **focado, self-contained e específico no output**:

- **Escopo:** um arquivo, um subsistema, um domínio — não "consertar os testes"
- **Contexto:** colar mensagens de erro e nomes de testes, não confiar que o agent vai descobrir
- **Restrições:** "não tocar em código de produção", "só ajustar testes", etc — senão um agent pode refatorar área de outro
- **Output esperado:** "retornar resumo do root cause e mudanças feitas" — vago resulta em difícil de integrar

### Depois que os agents retornam

1. Ler cada resumo individualmente
2. Verificar se editaram arquivos em comum (conflito potencial)
3. Rodar a suite completa para confirmar integração
4. Spot-check: agents podem cometer o mesmo erro sistemático (mesma má assunção em domínios diferentes)

---

## Dica de workflow

Uma forma confortável de trabalhar:

```bash
# Abrir tmux com uma sessão nomeada
tmux new-session -s projeto

# Dentro do tmux, abrir Claude Code com permissões automáticas
claude --dangerously-skip-permissions

# Quando terminar, desanexar (mantém tudo rodando)
# Ctrl+B + D

# Para voltar depois
tmux attach -t projeto
```
