# Design tooling (ferramentas externas dos agentes de design)

Os agentes `product-designer` e `frontend-engineer` sabem usar três ferramentas externas **quando elas estão disponíveis** — e degradam graciosamente quando não estão. A regra é invariante: toda ferramenta externa é **opt-in, verificada via `/mcp` ou lista de skills, e subordinada ao `docs/design-system.md`**. Nenhuma delas é fonte de verdade visual paralela; o `design-system.md` continua sendo o contrato.

| Ferramenta | Tipo | Papel | Custo | Setup |
|---|---|---|---|---|
| **shadcn registry MCP** | MCP (lookup) | `frontend-engineer` consulta props/API reais dos componentes em vez de lembrar do treino (sem props alucinadas) | grátis | **automático** — já vem no `.mcp.json` |
| **ui-ux-pro-max** | Skill | `product-designer` gera *rascunho* de paletas/font-pairings/estilos no Design System Mode → filtrado pela §0 + anti-slop | grátis (dep: Python 3) | opt-in (abaixo) |
| **21st.dev Magic** | MCP (geração) | `frontend-engineer` faz scaffold de componentes premium → re-expressos nos tokens do DS | **API key** | opt-in (abaixo) |

## 1. shadcn registry MCP — automático

Já está wirado em `templates/.mcp.json`. Copie esse arquivo para a raiz do seu projeto:

```bash
cp <caminho-do-ai-squad>/templates/.mcp.json ./.mcp.json
```

Abra o Claude Code no projeto e rode `/mcp` para confirmar que `shadcn` aparece como conectado. Requer Node/npx no PATH. (Funciona melhor num projeto que já tem `components.json` do shadcn.)

## 2. ui-ux-pro-max — opt-in

Skill de terceiro (`nextlevelbuilder/ui-ux-pro-max-skill`). Instale no escopo de usuário:

```bash
npx -y skills add https://github.com/nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max
```

Requer Python 3. O `product-designer` a invoca como **acelerador subordinado** no Design System Mode — ela gera candidatos, mas você ainda commita a UMA direção visual e é o autor final dos tokens. Se não estiver instalada, o fluxo padrão roda sem ela.

> Nota de segurança: skill de terceiro roda com permissões totais do agente. Revise antes de usar (o instalador mostra os scores Socket/Snyk/Gen).

## 3. 21st.dev Magic — opt-in (precisa de API key)

Gerador de componentes. Precisa de uma conta/API key em https://21st.dev. Registre no escopo de usuário:

```bash
claude mcp add magic --scope user --env API_KEY="SUA_API_KEY" -- npx -y @21st-dev/magic@latest
```

O `frontend-engineer` usa para scaffold de componentes com polish visual, mas **re-expressa os tokens/radius/sombras/fonts no `docs/design-system.md`** antes de aceitar — nunca deixa introduzir uma linguagem visual paralela.
