#!/usr/bin/env bash
# validate-events.sh — checa conformidade dos event logs do ai-squad.
#
# O event log (.claude/team-events/<scope>/events.jsonl) é o canal de progresso
# que sobrevive a painel ausente, sessão compactada e orquestração retomada.
# Ele só serve se o schema for estável — este script mostra onde derreteu.
#
# Uso:
#   scripts/metrics/validate-events.sh [caminho-do-projeto] [--strict]
#
# Sem argumento, valida o projeto atual. Com --strict, sai com código 1 se
# houver qualquer violação (útil em CI ou num hook).

set -uo pipefail

ROOT="${1:-.}"
[ "${1:-}" = "--strict" ] && ROOT="."
STRICT=0
for a in "$@"; do [ "$a" = "--strict" ] && STRICT=1; done

DIR="$ROOT/.claude/team-events"
if [ ! -d "$DIR" ]; then
  echo "nenhum event log em $DIR"
  exit 0
fi

find "$DIR" -name events.jsonl -print0 | xargs -0 cat 2>/dev/null | STRICT="$STRICT" python3 -c '
import sys, json, os, collections

VOCAB = {"started", "completed", "blocked", "handoff", "finding"}
KEYS  = {"ts", "agent", "event", "payload"}

bad_json = non_obj = 0
extra_keys = collections.Counter()
bad_event  = collections.Counter()
missing    = collections.Counter()
bad_ts     = 0
legacy_team = 0
per_agent  = collections.defaultdict(set)
total      = 0

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except Exception:
        bad_json += 1
        continue
    if not isinstance(d, dict):
        non_obj += 1
        continue
    total += 1
    for k in set(d) - KEYS:
        if k == "team":
            legacy_team += 1      # redundante com o path, tolerado em log historico
        else:
            extra_keys[k] += 1
    for k in KEYS - set(d):
        missing[k] += 1
    ev = d.get("event")
    if ev is not None and ev not in VOCAB:
        bad_event[str(ev)] += 1
    ts = d.get("ts")
    if isinstance(ts, str) and not ts.endswith("Z"):
        bad_ts += 1
    if isinstance(d.get("agent"), str) and ev in VOCAB:
        per_agent[d["agent"]].add(ev)

viol = bad_json + non_obj + sum(extra_keys.values()) + sum(bad_event.values()) + sum(missing.values()) + bad_ts

print(f"linhas validas: {total}")
print(f"violacoes: {viol}")
if bad_json:   print(f"  JSON malformado: {bad_json}")
if non_obj:    print(f"  linha que nao e objeto: {non_obj}")
if bad_ts:     print(f"  ts sem sufixo Z: {bad_ts}")
for k, n in missing.most_common():
    print(f"  chave obrigatoria ausente: {k} ({n})")
for k, n in extra_keys.most_common(10):
    hint = "  <- use ts" if k == "timestamp" else "  <- mova para dentro de payload"
    print(f"  chave fora do contrato: {k} ({n}){hint}")
if legacy_team:
    print(f"nota: {legacy_team} linhas com \"team\" no topo (legado tolerado — o scope ja vem do path)")
for k, n in bad_event.most_common(10):
    print(f"  event fora do vocabulario: {k} ({n})")

incompletos = [a for a, evs in per_agent.items() if "started" in evs and "completed" not in evs]
if incompletos:
    print(f"  agentes com started sem completed: {len(incompletos)} -> {", ".join(sorted(incompletos)[:5])}")

if os.environ.get("STRICT") == "1" and viol:
    sys.exit(1)
'
