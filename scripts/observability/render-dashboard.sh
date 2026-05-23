#!/usr/bin/env bash
# render-dashboard.sh — ai-squad stakeholder observability dashboard renderer
#
# Reads ai-squad workflow artifacts from the current repo and renders a single
# static HTML file. Designed for stakeholders (PM, biz, CTO) to monitor module
# progress and recent activity without invoking any agent.
#
# Data sources (each skipped silently when absent):
#   - docs/metrics/timeline.log              (gate enter/exit events)
#   - .claude/orchestrator-state/*.md        (latest orchestrator note per module)
#   - docs/goals/*.md                        (goal docs)
#   - docs/metrics/latest.html               (linked as full metrics snapshot)
#
# Usage:
#   bash scripts/observability/render-dashboard.sh [--output PATH] [--quiet]
#
# Output:
#   docs/dashboard/index.html (default)

set -euo pipefail
export LC_ALL=C
export LANG=C

# ---------- defaults ----------
OUTPUT="docs/dashboard/index.html"
QUIET=0
RECENT_EVENTS_LIMIT=20
STALE_DAYS=7

# ---------- flag parsing ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUTPUT="$2"; shift 2;;
    --quiet) QUIET=1; shift;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "[render-dashboard] unknown flag: $1" >&2; exit 2;;
  esac
done

# ---------- helpers ----------
log_warn() { printf '[render-dashboard] WARN: %s\n' "$*" >&2; }
log_info() { [ "$QUIET" -eq 0 ] && printf '[render-dashboard] %s\n' "$*"; }

html_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&#39;/g"
}

# Convert raw gate slug to a pretty label (best-effort; falls back to slug)
pretty_gate() {
  case "$1" in
    discovery) printf 'Discovery' ;;
    prd) printf 'PRD' ;;
    clarify) printf 'Clarify' ;;
    design-system) printf 'Design System' ;;
    ux-spec) printf 'UX Spec' ;;
    tech-spec) printf 'Tech Spec' ;;
    bootstrap) printf 'Bootstrap' ;;
    impl) printf 'Implementation' ;;
    review) printf 'Review' ;;
    remediation) printf 'Remediation' ;;
    consistency-check) printf 'Consistency Check' ;;
    ship) printf 'Ship' ;;
    finish-branch) printf 'Finish Branch' ;;
    retro|retrospective) printf 'Retrospective' ;;
    *) printf '%s' "$1" ;;
  esac
}

# Human-friendly relative time from ISO8601 UTC. Falls back to absolute if date parse fails.
# args: <iso-timestamp>
relative_time() {
  local iso="$1"
  local then_ts now_ts diff
  # macOS date vs GNU date: try both
  then_ts=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" "+%s" 2>/dev/null || \
            date -u -d "$iso" "+%s" 2>/dev/null || \
            echo "")
  if [ -z "$then_ts" ]; then
    printf '%s' "$iso"; return
  fi
  now_ts=$(date -u "+%s")
  diff=$(( now_ts - then_ts ))
  if [ "$diff" -lt 0 ]; then diff=0; fi
  if [ "$diff" -lt 60 ]; then printf '%ds ago' "$diff"
  elif [ "$diff" -lt 3600 ]; then printf '%dm ago' "$((diff/60))"
  elif [ "$diff" -lt 86400 ]; then printf '%dh ago' "$((diff/3600))"
  elif [ "$diff" -lt 2592000 ]; then printf '%dd ago' "$((diff/86400))"
  else printf '%s' "$iso"
  fi
}

# Resolve project name from git remote, else pwd
detect_project_name() {
  local url base
  url=$(git config --get remote.origin.url 2>/dev/null || true)
  if [ -n "$url" ]; then
    base=$(basename "$url" .git)
    printf '%s' "$base"
  else
    basename "$(pwd)"
  fi
}

# ---------- data collection ----------
PROJECT_NAME=$(detect_project_name)
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

TIMELINE_FILE="docs/metrics/timeline.log"
ORCH_STATE_DIR=".claude/orchestrator-state"
GOALS_DIR="docs/goals"
METRICS_HTML="docs/metrics/latest.html"

HAVE_TIMELINE=0; [ -f "$TIMELINE_FILE" ] && HAVE_TIMELINE=1
HAVE_ORCH=0;     [ -d "$ORCH_STATE_DIR" ] && HAVE_ORCH=1
HAVE_GOALS=0;    [ -d "$GOALS_DIR" ] && HAVE_GOALS=1
HAVE_METRICS=0;  [ -f "$METRICS_HTML" ] && HAVE_METRICS=1

# ---------- module state derivation ----------
# For each module mentioned in timeline.log, find:
#   - latest event timestamp
#   - the gate of the latest event
#   - whether the latest event was enter or exit
#   - the verdict (if present in the exit line)
#
# Output: a temp TSV (one row per module) with cols:
#   slug \t latest_ts \t gate_slug \t event \t verdict
MODULES_TSV=$(mktemp -t aisquad-modules.XXXXXX)
trap 'rm -f "$MODULES_TSV"' EXIT

if [ "$HAVE_TIMELINE" -eq 1 ]; then
  awk '
    {
      ts=""; gate=""; module=""; ev=""; verdict="";
      # ts is between [ and ]
      if (match($0, /\[[0-9TZ:.-]+\]/)) {
        ts = substr($0, RSTART+1, RLENGTH-2);
      }
      for (i=1; i<=NF; i++) {
        f=$i;
        if (f ~ /^gate=/) { gate=substr(f, 6) }
        else if (f ~ /^module=/) { module=substr(f, 8) }
        else if (f ~ /^event=/) { ev=substr(f, 7) }
        else if (f ~ /^verdict=/) { verdict=substr(f, 9) }
      }
      if (module=="" || gate=="" || ev=="" || ts=="") next;
      key=module;
      # keep latest by lexicographic ts (ISO8601 sorts correctly)
      if (!(key in seen) || ts > seen[key]) {
        seen[key]=ts;
        latest_gate[key]=gate;
        latest_ev[key]=ev;
        latest_verdict[key]=verdict;
      }
    }
    END {
      for (k in seen) {
        printf "%s\t%s\t%s\t%s\t%s\n", k, seen[k], latest_gate[k], latest_ev[k], latest_verdict[k];
      }
    }
  ' "$TIMELINE_FILE" | sort -t$'\t' -k2,2r > "$MODULES_TSV"
fi

MODULE_COUNT=$(wc -l < "$MODULES_TSV" | tr -d ' ')

# Staleness: time since most-recent timeline event
LATEST_TIMELINE_TS=""
STALE=0
if [ "$HAVE_TIMELINE" -eq 1 ] && [ -s "$MODULES_TSV" ]; then
  LATEST_TIMELINE_TS=$(head -1 "$MODULES_TSV" | cut -f2)
  if [ -n "$LATEST_TIMELINE_TS" ]; then
    latest_secs=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$LATEST_TIMELINE_TS" "+%s" 2>/dev/null || \
                  date -u -d "$LATEST_TIMELINE_TS" "+%s" 2>/dev/null || echo "")
    if [ -n "$latest_secs" ]; then
      now_secs=$(date -u "+%s")
      age_days=$(( (now_secs - latest_secs) / 86400 ))
      [ "$age_days" -ge "$STALE_DAYS" ] && STALE=1
    fi
  fi
fi

# Get latest line per orchestrator-state file (most recent timestamped entry).
# Returns the freeform note for a given module slug, or empty. Tolerant of
# missing files and of grep returning no matches under pipefail.
orch_note_for_module() {
  local slug="$1"
  local file="$ORCH_STATE_DIR/$slug.md"
  [ -f "$file" ] || return 0
  awk '/^\[[0-9]{4}-/ { last=$0 } END { if (last != "") { sub(/^\[[^]]*\][[:space:]]*/, "", last); print last } }' "$file"
}

# Active goals: list .md files in docs/goals, newest first by mtime.
# Title heuristic: skip any leading YAML frontmatter block, then take the first
# `# Heading` line; fall back to the first non-empty content line.
collect_goals() {
  [ "$HAVE_GOALS" -eq 1 ] || return 0
  for f in "$GOALS_DIR"/*.md; do
    [ -f "$f" ] || continue
    local mtime title
    mtime=$(stat -f "%m" "$f" 2>/dev/null || stat -c "%Y" "$f" 2>/dev/null || echo 0)
    title=$(awk '
      BEGIN { fm=0; done=0 }
      NR==1 && /^---[[:space:]]*$/ { fm=1; next }
      fm==1 && /^---[[:space:]]*$/ { fm=2; next }
      fm==1 { next }
      done==1 { next }
      /^#+[[:space:]]+/ { sub(/^#+[[:space:]]+/, ""); print; done=1; next }
      /^[^[:space:]]/ { if (!heading_found) { print; done=1 } }
    ' "$f" | head -c 200)
    printf '%s\t%s\t%s\n' "$mtime" "$f" "$title"
  done | sort -r -k1,1n
}

# Recent activity: last N lines of timeline, newest first
recent_events() {
  [ "$HAVE_TIMELINE" -eq 1 ] || return 0
  tail -n "$RECENT_EVENTS_LIMIT" "$TIMELINE_FILE" | tac 2>/dev/null || \
    tail -n "$RECENT_EVENTS_LIMIT" "$TIMELINE_FILE" | awk '{a[NR]=$0} END {for (i=NR;i>=1;i--) print a[i]}'
}

# ---------- HTML render ----------
mkdir -p "$(dirname "$OUTPUT")"

PROJECT_NAME_ESC=$(printf '%s' "$PROJECT_NAME" | html_escape)
GENERATED_AT_ESC=$(printf '%s' "$GENERATED_AT" | html_escape)

{

printf '<!DOCTYPE html>\n<html lang="en">\n<head>\n'
printf '<meta charset="utf-8">\n'
printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
printf '<title>%s — squad dashboard</title>\n' "$PROJECT_NAME_ESC"

cat <<'STYLE_EOF'
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f8f9fa; color: #212529; margin: 0; padding: 0; line-height: 1.55;
  }
  .container { max-width: 1080px; margin: 0 auto; padding: 28px 18px 48px; }
  header { margin-bottom: 28px; }
  header h1 { margin: 0 0 4px; font-size: 1.65em; color: #212529; }
  header .meta { color: #6c757d; font-size: 0.9em; }
  .stale-banner {
    background: #fff8e1; border-left: 4px solid #f4b400; padding: 10px 16px;
    border-radius: 4px; margin: 12px 0 20px; color: #6b5400; font-size: 0.92em;
  }
  .card {
    background: #fff; border-radius: 8px; padding: 18px 22px; margin-bottom: 18px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.05);
  }
  .card h2 { margin: 0 0 14px; font-size: 1.1em; color: #343a40; border-bottom: 2px solid #e9ecef; padding-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 8px 6px; text-align: left; vertical-align: top; font-size: 0.92em; }
  th { font-weight: 600; color: #495057; border-bottom: 1px solid #dee2e6; }
  tr.module-row { border-bottom: 1px solid #f1f3f5; }
  tr.module-row:last-child { border-bottom: none; }
  .module-name { font-weight: 600; color: #212529; }
  .badge {
    display: inline-block; padding: 2px 9px; border-radius: 10px; font-size: 0.78em; font-weight: 600;
  }
  .badge-enter { background: #cfe2ff; color: #084298; }
  .badge-exit  { background: #d1e7dd; color: #0a3622; }
  .badge-block { background: #f8d7da; color: #58151c; }
  .badge-warn  { background: #fff3cd; color: #664d03; }
  .badge-muted { background: #e9ecef; color: #495057; }
  .ts { color: #6c757d; font-size: 0.85em; white-space: nowrap; }
  .note { color: #495057; font-size: 0.88em; }
  ul.clean { list-style: none; padding: 0; margin: 0; }
  ul.clean li { padding: 8px 0; border-bottom: 1px solid #f1f3f5; }
  ul.clean li:last-child { border-bottom: none; }
  ul.clean a { color: #0a58ca; text-decoration: none; }
  ul.clean a:hover { text-decoration: underline; }
  .empty { color: #6c757d; font-style: italic; padding: 8px 0; }
  .activity-row { display: flex; gap: 12px; padding: 6px 0; border-bottom: 1px dashed #f1f3f5; font-size: 0.9em; }
  .activity-row:last-child { border-bottom: none; }
  .activity-row .ts { min-width: 130px; }
  .activity-row .module { font-weight: 600; min-width: 140px; }
  footer { text-align: center; color: #adb5bd; font-size: 0.82em; margin-top: 28px; padding-top: 14px; border-top: 1px solid #e9ecef; }
  footer a { color: #6c757d; }
  @media (max-width: 720px) {
    .container { padding: 14px 10px 32px; }
    .card { padding: 14px 14px; }
    .activity-row { flex-direction: column; gap: 2px; }
    .activity-row .ts, .activity-row .module { min-width: 0; }
  }
</style>
STYLE_EOF

printf '</head>\n<body>\n<div class="container">\n'

# ---- header ----
printf '<header>\n'
printf '  <h1>%s</h1>\n' "$PROJECT_NAME_ESC"
printf '  <div class="meta">ai-squad dashboard &middot; generated %s UTC</div>\n' "$GENERATED_AT_ESC"
printf '</header>\n'

# ---- stale banner ----
if [ "$STALE" -eq 1 ]; then
  printf '<div class="stale-banner">⚠ Last gate event was %s. No recent activity in this repo &mdash; the dashboard may not reflect current work.</div>\n' \
    "$(relative_time "$LATEST_TIMELINE_TS" | html_escape)"
fi

# ---- modules in flight ----
printf '<div class="card">\n'
printf '  <h2>Modules in flight</h2>\n'
if [ "$MODULE_COUNT" -eq 0 ]; then
  printf '  <div class="empty">No modules tracked yet. Run /sdlc-orchestrator on a module and gate events will populate here.</div>\n'
else
  printf '  <table>\n'
  printf '    <thead><tr><th>Module</th><th>Current phase</th><th>Status</th><th>Last activity</th><th>Latest note</th></tr></thead>\n'
  printf '    <tbody>\n'
  while IFS=$'\t' read -r slug ts gate ev verdict; do
    slug_esc=$(printf '%s' "$slug" | html_escape)
    gate_pretty=$(pretty_gate "$gate" | html_escape)
    ts_rel=$(relative_time "$ts" | html_escape)
    ts_abs=$(printf '%s' "$ts" | html_escape)
    case "$ev" in
      enter) badge_class="badge-enter"; badge_text="in progress" ;;
      exit)
        if [ -n "$verdict" ]; then
          case "$verdict" in
            *BLOCK*|*block*) badge_class="badge-block"; badge_text="$verdict" ;;
            *WARN*|*warning*) badge_class="badge-warn"; badge_text="$verdict" ;;
            *) badge_class="badge-exit"; badge_text="$verdict" ;;
          esac
        else
          badge_class="badge-exit"; badge_text="done"
        fi
        ;;
      *) badge_class="badge-muted"; badge_text="$ev" ;;
    esac
    badge_text_esc=$(printf '%s' "$badge_text" | html_escape)
    note=$(orch_note_for_module "$slug" | html_escape)
    [ -z "$note" ] && note="<span class=\"empty\">&mdash;</span>"
    printf '      <tr class="module-row">\n'
    printf '        <td class="module-name">%s</td>\n' "$slug_esc"
    printf '        <td>%s</td>\n' "$gate_pretty"
    printf '        <td><span class="badge %s">%s</span></td>\n' "$badge_class" "$badge_text_esc"
    printf '        <td class="ts" title="%s">%s</td>\n' "$ts_abs" "$ts_rel"
    printf '        <td class="note">%s</td>\n' "$note"
    printf '      </tr>\n'
  done < "$MODULES_TSV"
  printf '    </tbody>\n  </table>\n'
fi
printf '</div>\n'

# ---- active goals ----
printf '<div class="card">\n'
printf '  <h2>Goals</h2>\n'
if [ "$HAVE_GOALS" -eq 0 ]; then
  printf '  <div class="empty">No <code>docs/goals/</code> directory found. Create one and add goal docs (one per file) to see them here.</div>\n'
else
  goals_out=$(collect_goals)
  if [ -z "$goals_out" ]; then
    printf '  <div class="empty">No goal files found in docs/goals/.</div>\n'
  else
    printf '  <ul class="clean">\n'
    printf '%s\n' "$goals_out" | while IFS=$'\t' read -r mtime path title; do
      # path is `docs/goals/foo.md`; from `docs/dashboard/index.html` the relative link is `../goals/foo.md`
      rel_path=${path#docs/}
      rel_path_esc=$(printf '%s' "$rel_path" | html_escape)
      title_esc=$(printf '%s' "$title" | html_escape)
      basename_esc=$(printf '%s' "$(basename "$path")" | html_escape)
      [ -z "$title_esc" ] && title_esc="$basename_esc"
      printf '    <li><a href="../%s">%s</a> <span class="ts">&mdash; %s</span></li>\n' \
        "$rel_path_esc" "$title_esc" "$basename_esc"
    done
    printf '  </ul>\n'
  fi
fi
printf '</div>\n'

# ---- recent activity ----
printf '<div class="card">\n'
printf '  <h2>Recent activity</h2>\n'
if [ "$HAVE_TIMELINE" -eq 0 ]; then
  printf '  <div class="empty">No timeline data yet. <code>docs/metrics/timeline.log</code> is written by sdlc-orchestrator gate transitions.</div>\n'
else
  events=$(recent_events)
  if [ -z "$events" ]; then
    printf '  <div class="empty">Timeline file is empty.</div>\n'
  else
    printf '%s\n' "$events" | while IFS= read -r line; do
      [ -z "$line" ] && continue
      ts=$(printf '%s' "$line" | awk 'match($0, /\[[0-9TZ:.-]+\]/) { print substr($0, RSTART+1, RLENGTH-2) }')
      module=$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^module=/) {print substr($i,8); exit}}')
      gate=$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^gate=/) {print substr($i,6); exit}}')
      ev=$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^event=/) {print substr($i,7); exit}}')
      verdict=$(printf '%s' "$line" | awk '{for(i=1;i<=NF;i++) if ($i ~ /^verdict=/) {print substr($i,9); exit}}')
      ts_rel=$(relative_time "$ts" | html_escape)
      module_esc=$(printf '%s' "$module" | html_escape)
      gate_pretty=$(pretty_gate "$gate" | html_escape)
      ev_esc=$(printf '%s' "$ev" | html_escape)
      detail="$gate_pretty"
      [ -n "$ev" ] && detail="$detail &middot; $ev_esc"
      [ -n "$verdict" ] && detail="$detail &middot; $(printf '%s' "$verdict" | html_escape)"
      printf '  <div class="activity-row">\n'
      printf '    <span class="ts" title="%s">%s</span>\n' "$(printf '%s' "$ts" | html_escape)" "$ts_rel"
      printf '    <span class="module">%s</span>\n' "$module_esc"
      printf '    <span class="detail">%s</span>\n' "$detail"
      printf '  </div>\n'
    done
  fi
fi
printf '</div>\n'

# ---- footer ----
printf '<footer>\n'
if [ "$HAVE_METRICS" -eq 1 ]; then
  # METRICS_HTML is `docs/metrics/latest.html`; from `docs/dashboard/` the relative link is `../metrics/latest.html`
  metrics_rel=${METRICS_HTML#docs/}
  printf '  See full <a href="../%s">engineering metrics snapshot</a> &middot; ' "$(printf '%s' "$metrics_rel" | html_escape)"
fi
printf 'Generated by <a href="https://github.com/carlos-sobral/ai-squad">ai-squad</a> render-dashboard.sh\n'
printf '</footer>\n'

printf '</div>\n</body>\n</html>\n'

} > "$OUTPUT"

log_info "wrote $OUTPUT (modules=$MODULE_COUNT, stale=$STALE)"
