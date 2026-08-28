#!/usr/bin/env bash
# reap-orphan-teammates.sh — mata tmux servers claude-swarm-<pid> cujo parent
# claude não existe mais (ou está suspenso), junto com os teammates dentro deles.
# Dry-run por padrão. Use --kill para executar.
set -uo pipefail

KILL=0; SUSPENDED=0
for a in "$@"; do
  case "$a" in
    --kill) KILL=1 ;;
    --include-suspended) SUSPENDED=1 ;;
  esac
done
SOCKDIR="/tmp/tmux-$(id -u)"
[ -d "$SOCKDIR" ] || { echo "sem socket dir"; exit 0; }

found=0
for sock in "$SOCKDIR"/claude-swarm-*; do
  [ -S "$sock" ] || continue
  name=$(basename "$sock"); ppid=${name#claude-swarm-}
  server_pid=$(tmux -L "$name" display-message -p '#{pid}' 2>/dev/null)

  # socket sem server vivo = resíduo
  if [ -z "$server_pid" ]; then
    echo "RESIDUO  $sock (server morto)"
    found=1
    [ $KILL -eq 1 ] && rm -f "$sock"
    continue
  fi

  stat=$(ps -o stat= -p "$ppid" 2>/dev/null | tr -d ' ')
  cmd=$(ps -o command= -p "$ppid" 2>/dev/null)

  alive=0; suspended=0
  case "$cmd" in *claude*)
    case "$stat" in T*) suspended=1 ;; *) alive=1 ;; esac ;;
  esac

  if [ $alive -eq 1 ]; then
    echo "OK       $name — parent $ppid vivo ($stat)"
    continue
  fi

  if [ $suspended -eq 1 ] && [ $SUSPENDED -eq 0 ]; then
    echo "SUSPENSO $name — parent $ppid parado (retomável com fg); use --include-suspended"
    found=1
    continue
  fi

  agents=$(pgrep -f -- "--team-name" 2>/dev/null | while read -r p; do
             pstree_root=$p; ps -o ppid= -p "$p" 2>/dev/null | tr -d ' '
           done | grep -c "^$server_pid$" || true)
  rss=$(ps -o rss= -p $(pgrep -P "$server_pid" 2>/dev/null | tr '\n' ',' | sed 's/,$//') 2>/dev/null \
        | awk '{s+=$1} END {printf "%.0f", s/1024}')
  echo "ORFAO    $name — parent $ppid ${stat:-inexistente}; ${agents:-?} teammate(s), ~${rss:-0} MB"
  found=1
  if [ $KILL -eq 1 ]; then
    tmux -L "$name" kill-server 2>/dev/null && echo "         → server $server_pid morto"
    rm -f "$sock"
  fi
done

[ $found -eq 0 ] && echo "nada órfão."
[ $found -eq 1 ] && [ $KILL -eq 0 ] && echo; [ $found -eq 1 ] && [ $KILL -eq 0 ] && echo "rode com --kill para limpar."
exit 0
