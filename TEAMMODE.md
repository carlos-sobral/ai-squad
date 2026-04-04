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

## Como verificar que está funcionando

1. Abra o terminal
2. Inicie uma sessão tmux:
   ```bash
   tmux
   ```
3. Abra o Claude Code dentro do tmux:
   ```bash
   claude
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

## Dica de workflow

Uma forma confortável de trabalhar:

```bash
# Abrir tmux com uma sessão nomeada
tmux new-session -s projeto

# Dentro do tmux, abrir Claude Code
claude

# Quando terminar, desanexar (mantém tudo rodando)
# Ctrl+B + D

# Para voltar depois
tmux attach -t projeto
```
