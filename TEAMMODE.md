# TeamMode — Agentes em paralelo com tmux

Por padrão, quando o `sdlc-orchestrator` roda dois ou mais agentes ao mesmo tempo (ex: `backend-engineer` + `frontend-engineer`), eles aparecem como **painéis divididos no terminal** usando o tmux. Você consegue ver o progresso de cada agente em tempo real, lado a lado.

Sem essa configuração, os agentes ainda funcionam — mas rodam em sequência e sem visibilidade de andamento.

---

## O que você precisa

- **tmux** — multiplexador de terminal (gerencia os painéis)
- **Claude Code** com a variável de ambiente `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Dois ajustes no arquivo `~/.claude/settings.json`

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
  "Preferences": {
    "tmuxSplitPanes": true
  },
  "teammateMode": "tmux"
}
```

Se o arquivo já existe com outras configurações, adicione apenas as chaves que faltam — não substitua o arquivo inteiro.

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

> **Importante:** o Claude Code precisa estar rodando **dentro de uma sessão tmux** para os painéis funcionarem. Se você abrir o `claude` fora do tmux, os agentes paralelos vão rodar em sequência normalmente — sem erro, só sem os painéis.

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
- Verifique se `settings.json` tem as três chaves corretas
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

`TeamCreate` paraleliza dois ou mais agents simultaneamente. Mas paralelizar problemas relacionados desperdiça contexto e gera conflitos. A decisão é binária: **os domínios são independentes?**

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
