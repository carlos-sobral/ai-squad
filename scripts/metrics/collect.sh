#!/usr/bin/env bash
# collect.sh — ai-squad local engineering metrics collector
#
# Collects 9 engineering metrics across 3 families (DORA-adapted, process
# health, agentic-specific) from the current git repo and the docs/agents/
# tree produced by ai-squad agents. Writes a markdown report to
# docs/metrics/latest.md and appends a snapshot to
# docs/metrics/history/YYYY-MM.md.
#
# Usage: bash scripts/metrics/collect.sh [--window 30d] [--output PATH] [--quiet]
#
# Exits 0 even when individual metrics fail (warnings on stderr); only fatal
# argument or filesystem errors return non-zero. Designed to be invoked by the
# performance-engineer audit mode when CLAUDE.md declares
# engineering_metrics.provider: ai-squad-local.

set -euo pipefail

# Force C locale so awk/printf use '.' as decimal separator regardless of dev env
export LC_ALL=C
export LANG=C

# ---------- defaults ----------
WINDOW="30d"
OUTPUT="docs/metrics/latest.md"
QUIET=0

# ---------- helpers ----------
log_warn() {
  printf '[collect.sh] WARN: %s\n' "$*" >&2
}

log_info() {
  if [ "$QUIET" -eq 0 ]; then
    printf '[collect.sh] %s\n' "$*"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# count files under a directory matching a glob (newest first not needed)
# args: directory pattern
count_files_matching() {
  local dir="$1"
  local pat="$2"
  if [ ! -d "$dir" ]; then
    printf '0'
    return
  fi
  # shellcheck disable=SC2086
  find "$dir" -type f -name "$pat" 2>/dev/null | wc -l | tr -d ' '
}

# extract YAML frontmatter value for a key from a markdown file using awk
# args: file key
fm_get() {
  local file="$1"
  local key="$2"
  if require_cmd yq; then
    # yq reads frontmatter via splitting; fallback to awk if it errors
    yq -r --front-matter=extract ".${key} // \"\"" "$file" 2>/dev/null || \
      awk -v k="$key" '
        BEGIN { infm=0 }
        /^---[[:space:]]*$/ { infm++; next }
        infm==1 {
          line=$0
          sub(/^[[:space:]]*/, "", line)
          n=index(line, ":")
          if (n>0) {
            kk=substr(line,1,n-1)
            vv=substr(line,n+1)
            sub(/^[[:space:]]*/, "", vv)
            sub(/[[:space:]]*$/, "", vv)
            gsub(/^["'\'']|["'\'']$/, "", vv)
            if (kk==k) { print vv; exit }
          }
        }
      ' "$file"
  else
    awk -v k="$key" '
      BEGIN { infm=0 }
      /^---[[:space:]]*$/ { infm++; next }
      infm==1 {
        line=$0
        sub(/^[[:space:]]*/, "", line)
        n=index(line, ":")
        if (n>0) {
          kk=substr(line,1,n-1)
          vv=substr(line,n+1)
          sub(/^[[:space:]]*/, "", vv)
          sub(/[[:space:]]*$/, "", vv)
          gsub(/^["'\'']|["'\'']$/, "", vv)
          if (kk==k) { print vv; exit }
        }
      }
    ' "$file"
  fi
}

# Convert window like "30d" / "14d" / "7d" → days integer
window_days() {
  local w="$1"
  case "$w" in
    *d) printf '%s' "${w%d}" ;;
    *)  printf '30' ;;
  esac
}

# ---------- argument parsing ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --window)
      [ $# -ge 2 ] || { echo "ERROR: --window requires value" >&2; exit 2; }
      case "$2" in
        [0-9]*d) WINDOW="$2" ;;
        *) echo "ERROR: --window must be like 30d" >&2; exit 2 ;;
      esac
      shift 2
      ;;
    --output)
      [ $# -ge 2 ] || { echo "ERROR: --output requires value" >&2; exit 2; }
      case "$2" in
        /*|..*) echo "ERROR: --output must be a relative path inside repo" >&2; exit 2 ;;
        *) OUTPUT="$2" ;;
      esac
      shift 2
      ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

DAYS="$(window_days "$WINDOW")"
SINCE_GIT="${DAYS} days ago"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MONTH_TAG="$(date -u +%Y-%m)"

# Sanity: must be in a git repo
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: not inside a git repo" >&2
  exit 2
fi
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

mkdir -p "$(dirname "$OUTPUT")"
mkdir -p docs/metrics/history

# ---------- metric: lead time ----------
compute_lead_time() {
  if ! require_cmd gh; then
    log_warn "gh CLI not available — skipping lead time"
    printf 'N/A|N/A'
    return
  fi
  local json
  if ! json="$(gh pr list --state=merged --limit 100 --json mergedAt,createdAt 2>/dev/null)"; then
    log_warn "gh pr list failed — skipping lead time"
    printf 'N/A|N/A'
    return
  fi
  if ! require_cmd python3; then
    log_warn "python3 not available — cannot compute percentiles"
    printf 'N/A|N/A'
    return
  fi
  printf '%s' "$json" | python3 - <<'PY'
import json, sys
from datetime import datetime, timezone
data = json.load(sys.stdin) if not sys.stdin.isatty() else []
PY
  # Re-run pipeline properly
  printf '%s' "$json" | python3 -c '
import json, sys
from datetime import datetime
data = json.load(sys.stdin)
hours = []
for pr in data:
    try:
        c = datetime.fromisoformat(pr["createdAt"].replace("Z","+00:00"))
        m = datetime.fromisoformat(pr["mergedAt"].replace("Z","+00:00"))
        hours.append((m-c).total_seconds()/3600.0)
    except Exception:
        pass
if not hours:
    print("N/A|N/A")
else:
    hours.sort()
    def pct(p):
        k = (len(hours)-1)*p
        f, c = int(k), min(int(k)+1, len(hours)-1)
        return hours[f] + (hours[c]-hours[f])*(k-f)
    print(f"{pct(0.5):.1f}h|{pct(0.95):.1f}h")
'
}

# ---------- metric: change failure rate ----------
compute_cfr() {
  local total failures
  total="$(git log --since="$SINCE_GIT" --pretty=format:%H 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$total" = "0" ]; then
    printf 'N/A (no commits in window)'
    return
  fi
  failures="$(git log --since="$SINCE_GIT" --pretty=format:%s 2>/dev/null \
    | grep -E "^(revert|hotfix|fix!):" | wc -l | tr -d ' ')"
  if [ "$total" -eq 0 ]; then
    printf 'N/A'
  else
    awk -v f="$failures" -v t="$total" 'BEGIN { printf "%.1f%% (%d/%d)", (f/t)*100, f, t }'
  fi
}

# ---------- metric: rework rate per module ----------
# Reads frontmatter `verdict:` from docs/agents/**/*.md, groups by slug.
# Slug extraction: filename pattern is YYYY-MM-DD-{mode-or-task}-{slug}.md.
# We approximate by taking the last hyphen-segment before .md as the module
# slug when the name has 4+ segments; otherwise we use the parent directory
# name (the agent name).
compute_rework() {
  if [ ! -d docs/agents ]; then
    printf 'N/A (no docs/agents/)\n'
    return
  fi
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local verdict slug base
    verdict="$(fm_get "$f" verdict 2>/dev/null || true)"
    [ -z "$verdict" ] && continue
    base="$(basename "$f" .md)"
    # try last segment as slug
    slug="$(printf '%s' "$base" | awk -F- '{ print $NF }')"
    # if slug looks like a date fragment or empty, fall back to agent dir
    if [ -z "$slug" ] || printf '%s' "$slug" | grep -Eq '^[0-9]+$'; then
      slug="$(basename "$(dirname "$f")")"
    fi
    printf '%s\t%s\n' "$slug" "$verdict" >> "$tmp"
  done < <(find docs/agents -type f -name '*.md' 2>/dev/null)

  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    printf 'N/A (no verdicts found)\n'
    return
  fi

  awk -F'\t' '
    {
      total[$1]++
      v=tolower($2)
      if (v=="blocked" || v=="fail") fail[$1]++
    }
    END {
      for (m in total) {
        f=(m in fail) ? fail[m] : 0
        printf "  - **%s** — %d/%d (%.0f%%)\n", m, f, total[m], (f/total[m])*100
      }
    }
  ' "$tmp" | sort
  rm -f "$tmp"
}

# ---------- metric: spec-fidelity rate ----------
compute_spec_fidelity() {
  local files c d total
  files="$(find docs/agents/software-architect -type f -name '*consistency*' 2>/dev/null || true)"
  if [ -z "$files" ]; then
    printf 'N/A (no consistency-check reports)'
    return
  fi
  c="$(printf '%s\n' "$files" | xargs grep -o '(c)' 2>/dev/null | wc -l | tr -d ' ')"
  d="$(printf '%s\n' "$files" | xargs grep -o '(d)' 2>/dev/null | wc -l | tr -d ' ')"
  # total markers (a)+(b)+(c)+(d)
  total="$(printf '%s\n' "$files" | xargs grep -oE '\([abcd]\)' 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$total" = "0" ]; then
    printf 'N/A (no markers)'
    return
  fi
  awk -v c="$c" -v d="$d" -v t="$total" \
    'BEGIN { printf "%.1f%% deviations ((c)+(d)=%d/%d)", ((c+d)/t)*100, c+d, t }'
}

# ---------- metric: stage cycle time ----------
# Approximation: median time between first commit in window and merge of the
# branch's PR. We approximate further: time between first and last commit per
# day of activity, averaged. This is a coarse signal.
compute_cycle_time() {
  local commits
  commits="$(git log --since="$SINCE_GIT" --pretty=format:'%aI' 2>/dev/null | sort)"
  if [ -z "$commits" ]; then
    printf 'N/A (no commits in window)'
    return
  fi
  printf '%s\n' "$commits" | python3 -c '
import sys
from datetime import datetime
ts=[]
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try: ts.append(datetime.fromisoformat(line))
    except: pass
if len(ts)<2:
    print("N/A (insufficient data)")
else:
    spans=[]
    cur=[ts[0]]
    for t in ts[1:]:
        if (t-cur[-1]).total_seconds() < 6*3600:
            cur.append(t)
        else:
            if len(cur)>1: spans.append((cur[-1]-cur[0]).total_seconds()/3600)
            cur=[t]
    if len(cur)>1: spans.append((cur[-1]-cur[0]).total_seconds()/3600)
    if not spans:
        print("N/A (no multi-commit sessions)")
    else:
        spans.sort()
        med=spans[len(spans)//2]
        print(f"{med:.1f}h median session span (n={len(spans)})")
'
}

# ---------- metric: agent coverage ----------
compute_agent_coverage() {
  if [ ! -d docs/agents ]; then
    printf 'N/A (no docs/agents/)'
    return
  fi
  local count
  count="$(find docs/agents -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r d; do
    if find "$d" -type f -mtime -"$DAYS" 2>/dev/null | grep -q .; then
      printf '%s\n' "$d"
    fi
  done | wc -l | tr -d ' ')"
  local total
  total="$(find docs/agents -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  printf '%d/%d agent dirs active in last %sd' "$count" "$total" "$DAYS"
}

# ---------- metric: retro→diff conversion ----------
compute_retro_conversion() {
  local diffs retros
  diffs="$(find docs/agent-evolution -type f -name '*.md' -mtime -"$DAYS" 2>/dev/null | wc -l | tr -d ' ')"
  retros="$(find docs/agents/sdlc-orchestrator -type f -name '*retrospective*' -mtime -"$DAYS" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$retros" = "0" ]; then
    printf 'N/A — no retros tracked'
  else
    awk -v d="$diffs" -v r="$retros" 'BEGIN { printf "%.0f%% (%d diffs / %d retros)", (d/r)*100, d, r }'
  fi
}

# ---------- metric: agent definition versioning velocity ----------
compute_versioning_velocity() {
  if [ ! -d docs/agent-evolution ]; then
    printf 'N/A (no docs/agent-evolution/)\n'
    return
  fi
  local tmp
  tmp="$(mktemp)"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local agent vers
    agent="$(fm_get "$f" agent 2>/dev/null || true)"
    vers="$(fm_get "$f" version_after 2>/dev/null || true)"
    [ -z "$agent" ] || [ -z "$vers" ] && continue
    printf '%s\t%s\n' "$agent" "$vers" >> "$tmp"
  done < <(find docs/agent-evolution -type f -name '*.md' -mtime -"$DAYS" 2>/dev/null)

  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    printf 'N/A (no version_after entries in window)\n'
    return
  fi
  awk -F'\t' '{ key=$1 SUBSEP $2; if (!(key in seen)) { seen[key]=1; count[$1]++ } }
    END { for (a in count) printf "  - **%s** — %d distinct versions\n", a, count[a] }' "$tmp" | sort
  rm -f "$tmp"
}

# ---------- main: run all metrics ----------
log_info "Collecting metrics over window=$WINDOW (=$DAYS days)"

LEAD_TIME="$(compute_lead_time || echo 'N/A|N/A')"
LT_P50="${LEAD_TIME%|*}"
LT_P95="${LEAD_TIME#*|}"
CFR="$(compute_cfr || echo 'N/A')"
REWORK="$(compute_rework || echo 'N/A')"
SPEC_FID="$(compute_spec_fidelity || echo 'N/A')"
CYCLE="$(compute_cycle_time || echo 'N/A')"
COVERAGE="$(compute_agent_coverage || echo 'N/A')"
RETRO_CONV="$(compute_retro_conversion || echo 'N/A')"
VERSIONING="$(compute_versioning_velocity || echo 'N/A')"

# ---------- write output ----------
write_report() {
  local out="$1"
  {
    echo "# Engineering Metrics — ai-squad local"
    echo
    echo "**Window:** last ${DAYS} days  "
    echo "**Generated:** ${NOW_ISO}"
    echo
    if [ ! -d docs/agents ]; then
      echo "> no agent outputs found yet — nothing to aggregate"
      echo
    fi
    echo "## Family A — DORA adapted"
    echo
    echo "| Metric | Value |"
    echo "|---|---|"
    echo "| Lead Time for Change — p50 | ${LT_P50} |"
    echo "| Lead Time for Change — p95 | ${LT_P95} |"
    echo "| Change Failure Rate | ${CFR} |"
    echo
    echo "## Family B — Process health"
    echo
    echo "**Rework Rate per module** (verdict in {blocked, fail}):"
    echo
    printf '%s\n' "$REWORK"
    echo
    echo "| Metric | Value |"
    echo "|---|---|"
    echo "| Spec-Fidelity Rate | ${SPEC_FID} |"
    echo "| Stage Cycle Time | ${CYCLE} |"
    echo
    echo "## Family C — Agentic-specific"
    echo
    echo "| Metric | Value |"
    echo "|---|---|"
    echo "| Agent Coverage | ${COVERAGE} |"
    echo "| Retro→Diff Conversion Rate | ${RETRO_CONV} |"
    echo
    echo "**Agent Definition Versioning Velocity** (distinct \`version_after\` per agent):"
    echo
    printf '%s\n' "$VERSIONING"
    echo
    echo "<!-- generated by ai-squad collect.sh at ${NOW_ISO} -->"
  } > "$out"
}

write_report "$OUTPUT"

# Append snapshot to history (full content + separator)
HIST="docs/metrics/history/${MONTH_TAG}.md"
{
  echo
  echo "---"
  echo
  cat "$OUTPUT"
} >> "$HIST"

log_info "Wrote ${OUTPUT} and appended snapshot to ${HIST}"
exit 0
