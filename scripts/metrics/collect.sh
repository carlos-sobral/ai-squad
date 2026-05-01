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
  # Match conventional-commit prefixes that signal a failure to fix:
  #   revert / hotfix / fix — with or without scope (parens) and with or without
  #   breaking-change bang (!). Examples matched:
  #     revert: …          revert!: …          revert(scope): …
  #     hotfix: …          hotfix(scope): …
  #     fix: …             fix!: …             fix(scope): …    fix(scope)!: …
  # NOT matched (intentional): feat:, chore:, docs:, refactor:, test:, etc.
  failures="$(git log --since="$SINCE_GIT" --pretty=format:%s 2>/dev/null \
    | grep -E "^(revert|hotfix|fix)(\([^)]+\))?!?:" | wc -l | tr -d ' ')"
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

# ---------- HTML helpers ----------

# color_badge: value thresholds direction → inline HTML badge
# direction: "lower_better" (lead time, CFR, rework) or "higher_better" (fidelity, coverage, conversion)
# args: value green_thresh yellow_thresh direction label
# For lower_better:  green if val<=green_thresh, yellow if val<=yellow_thresh, else red
# For higher_better: green if val>=green_thresh, yellow if val>=yellow_thresh, else red
html_badge() {
  local val="$1" label="$2" green_t="$3" yellow_t="$4" direction="$5"
  local bg="#6c757d" fg="#fff"  # default gray/N/A

  # Strip non-numeric chars for comparison (handle "12.3h", "45.6%", "N/A")
  local num
  num="$(printf '%s' "$val" | sed 's/[^0-9.]//g')"

  if [ -z "$num" ] || printf '%s' "$val" | grep -qi 'N/A'; then
    bg="#6c757d"; fg="#fff"
  elif [ "$direction" = "lower_better" ]; then
    if awk "BEGIN { exit !($num <= $green_t) }"; then
      bg="#28a745"; fg="#fff"
    elif awk "BEGIN { exit !($num <= $yellow_t) }"; then
      bg="#ffc107"; fg="#000"
    else
      bg="#dc3545"; fg="#fff"
    fi
  else
    # higher_better
    if awk "BEGIN { exit !($num >= $green_t) }"; then
      bg="#28a745"; fg="#fff"
    elif awk "BEGIN { exit !($num >= $yellow_t) }"; then
      bg="#ffc107"; fg="#000"
    else
      bg="#dc3545"; fg="#fff"
    fi
  fi

  printf '<span style="display:inline-block;padding:2px 8px;border-radius:4px;font-size:0.85em;font-weight:600;background:%s;color:%s;" title="%s">%s</span>' \
    "$bg" "$fg" "$label" "$val"
}

# Parse maturity levels from docs/maturity-assessment.md
# Sets MATURITY_SPEC, MATURITY_REVIEW, MATURITY_LEARNING, MATURITY_DELIVERY, MATURITY_OBS
parse_maturity() {
  MATURITY_SPEC="unknown"
  MATURITY_REVIEW="unknown"
  MATURITY_LEARNING="unknown"
  MATURITY_DELIVERY="unknown"
  MATURITY_OBS="unknown"
  local matfile="docs/maturity-assessment.md"
  [ -f "$matfile" ] || return 0
  while IFS='|' read -r _ dim level _; do
    dim="$(printf '%s' "$dim" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    level="$(printf '%s' "$level" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -oE 'L[1-4]' || true)"
    [ -z "$level" ] && continue
    case "$dim" in
      *Spec*Discipline*|*spec*discipline*) MATURITY_SPEC="$level" ;;
      *Review*Coverage*|*review*coverage*) MATURITY_REVIEW="$level" ;;
      *Learning*Loop*|*learning*loop*)     MATURITY_LEARNING="$level" ;;
      *Delivery*Stability*|*delivery*stability*) MATURITY_DELIVERY="$level" ;;
      *Observability*|*observability*)     MATURITY_OBS="$level" ;;
    esac
  done < "$matfile"
}

# Parse previous snapshot for deltas
# Sets associative-style variables PREV_LT_P50 PREV_LT_P95 PREV_CFR PREV_COVERAGE PREV_RETRO_CONV
parse_previous_snapshot() {
  PREV_LT_P50="" PREV_LT_P95="" PREV_CFR="" PREV_COVERAGE="" PREV_RETRO_CONV="" PREV_SPEC_FID=""
  HAS_PREVIOUS=0
  local histdir="docs/metrics/history"
  [ -d "$histdir" ] || return 0
  local latest
  latest="$(find "$histdir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort | tail -1)"
  [ -z "$latest" ] && return 0
  # Get the last snapshot block (after last ---)
  local block
  block="$(awk '/^---$/{buf=""} {buf=buf"\n"$0} END{print buf}' "$latest")"
  [ -z "$block" ] && return 0
  HAS_PREVIOUS=1
  PREV_LT_P50="$(printf '%s' "$block" | grep 'Lead Time.*p50' | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  PREV_LT_P95="$(printf '%s' "$block" | grep 'Lead Time.*p95' | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  PREV_CFR="$(printf '%s' "$block" | grep 'Change Failure Rate' | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  PREV_COVERAGE="$(printf '%s' "$block" | grep 'Agent Coverage' | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  PREV_RETRO_CONV="$(printf '%s' "$block" | grep 'Retro' | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  PREV_SPEC_FID="$(printf '%s' "$block" | grep 'Spec-Fidelity' | awk -F'|' '{print $3}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
}

# delta_arrow: cur prev direction → HTML arrow span
# direction: lower_better | higher_better
delta_arrow() {
  local cur="$1" prev="$2" direction="$3"
  local cur_n prev_n
  cur_n="$(printf '%s' "$cur" | sed 's/[^0-9.]//g')"
  prev_n="$(printf '%s' "$prev" | sed 's/[^0-9.]//g')"

  if [ -z "$cur_n" ] || [ -z "$prev_n" ] || printf '%s' "$cur" | grep -qi 'N/A' || printf '%s' "$prev" | grep -qi 'N/A'; then
    printf '<span style="color:#6c757d;">&#8594;</span>'
    return
  fi

  local diff improved
  diff="$(awk "BEGIN { printf \"%.4f\", $cur_n - $prev_n }")"
  # check if approximately equal (within 0.5)
  if awk "BEGIN { exit !(($diff > -0.5) && ($diff < 0.5)) }"; then
    printf '<span style="color:#6c757d;">&#8594;</span>'
  elif [ "$direction" = "lower_better" ]; then
    if awk "BEGIN { exit !($diff < 0) }"; then
      printf '<span style="color:#28a745;">&#8595; improved</span>'
    else
      printf '<span style="color:#dc3545;">&#8593; regressed</span>'
    fi
  else
    if awk "BEGIN { exit !($diff > 0) }"; then
      printf '<span style="color:#28a745;">&#8593; improved</span>'
    else
      printf '<span style="color:#dc3545;">&#8595; regressed</span>'
    fi
  fi
}

# Rubric cell: if dimension matches current level, highlight it
rubric_cell() {
  local current_level="$1" cell_level="$2" text="$3"
  if [ "$current_level" = "$cell_level" ]; then
    printf '<td style="background:#28a74533;border:2px solid #28a745;font-weight:500;">%s <span style="display:inline-block;padding:1px 6px;border-radius:3px;font-size:0.75em;font-weight:700;background:#28a745;color:#fff;">CURRENT</span></td>' "$text"
  else
    printf '<td>%s</td>' "$text"
  fi
}

render_html() {
  local html_output="${OUTPUT%.md}.html"
  # If OUTPUT doesn't end in .md, just append .html
  if [ "$html_output" = "$OUTPUT" ]; then
    html_output="${OUTPUT}.html"
  fi

  parse_maturity
  parse_previous_snapshot

  # Pre-compute badges
  local lt_p50_badge lt_p95_badge cfr_badge
  # Lead time thresholds: p50 green<=24h(1d), yellow<=72h(3d); p95 green<=72h(3d), yellow<=120h(5d)
  lt_p50_badge="$(html_badge "$LT_P50" "Lead Time p50" 24 72 lower_better)"
  lt_p95_badge="$(html_badge "$LT_P95" "Lead Time p95" 72 120 lower_better)"
  # CFR thresholds: green<=10%, yellow<=15%
  local cfr_num
  cfr_num="$(printf '%s' "$CFR" | sed 's/[^0-9.]//g' | head -c 10)"
  cfr_badge="$(html_badge "$CFR" "Change Failure Rate" 10 15 lower_better)"

  # Spec fidelity badge (higher_better: green>=85, yellow>=70)
  local specfid_badge
  specfid_badge="$(html_badge "$SPEC_FID" "Spec-Fidelity Rate" 85 70 higher_better)"

  # Coverage badge: parse "X/Y" → percentage
  local cov_pct_str="$COVERAGE"
  local cov_num cov_total cov_pct
  cov_num="$(printf '%s' "$COVERAGE" | grep -oE '^[0-9]+' || echo 0)"
  cov_total="$(printf '%s' "$COVERAGE" | grep -oE '/[0-9]+' | tr -d '/' || echo 0)"
  if [ "$cov_total" -gt 0 ] 2>/dev/null; then
    cov_pct="$(awk "BEGIN { printf \"%.0f\", ($cov_num/$cov_total)*100 }")"
    cov_pct_str="${cov_pct}% (${COVERAGE})"
  fi
  local coverage_badge
  coverage_badge="$(html_badge "$cov_pct_str" "Agent Coverage" 90 70 higher_better)"

  # Retro conversion badge (higher_better: green>=60, yellow>=40)
  local retro_badge
  retro_badge="$(html_badge "$RETRO_CONV" "Retro Conversion" 60 40 higher_better)"

  # Rework: convert markdown list to HTML
  local rework_html
  if printf '%s' "$REWORK" | grep -q 'N/A'; then
    rework_html="<span style=\"display:inline-block;padding:2px 8px;border-radius:4px;font-size:0.85em;font-weight:600;background:#6c757d;color:#fff;\">N/A</span> <span style=\"color:#888;font-size:0.85em;\">$REWORK</span>"
  else
    rework_html="<ul style=\"margin:0.5em 0;padding-left:1.5em;\">"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local mod pct_part
      mod="$(printf '%s' "$line" | sed 's/.*\*\*\(.*\)\*\*.*/\1/')"
      pct_part="$(printf '%s' "$line" | sed 's/.*\*\*.*\*\* — //')"
      local rw_num
      rw_num="$(printf '%s' "$pct_part" | grep -oE '[0-9]+%' | tr -d '%' || echo '')"
      local rw_badge
      rw_badge="$(html_badge "${rw_num:-N/A}%" "Rework: $mod" 15 30 lower_better)"
      rework_html="${rework_html}<li><strong>${mod}</strong> -- ${pct_part} ${rw_badge}</li>"
    done <<< "$REWORK"
    rework_html="${rework_html}</ul>"
  fi

  # Versioning: convert markdown list to HTML
  local versioning_html
  if printf '%s' "$VERSIONING" | grep -q 'N/A'; then
    versioning_html="<span style=\"display:inline-block;padding:2px 8px;border-radius:4px;font-size:0.85em;font-weight:600;background:#6c757d;color:#fff;\">N/A</span> <span style=\"color:#888;font-size:0.85em;\">$VERSIONING</span>"
  else
    versioning_html="<ul style=\"margin:0.5em 0;padding-left:1.5em;\">"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      line="$(printf '%s' "$line" | sed 's/\*\*\(.*\)\*\*/<strong>\1<\/strong>/g')"
      versioning_html="${versioning_html}<li>${line}</li>"
    done <<< "$VERSIONING"
    versioning_html="${versioning_html}</ul>"
  fi

  # Deltas card content
  local deltas_html
  if [ "$HAS_PREVIOUS" -eq 1 ]; then
    local d_lt50 d_lt95 d_cfr d_cov d_retro d_specfid
    d_lt50="$(delta_arrow "$LT_P50" "$PREV_LT_P50" lower_better)"
    d_lt95="$(delta_arrow "$LT_P95" "$PREV_LT_P95" lower_better)"
    d_cfr="$(delta_arrow "$CFR" "$PREV_CFR" lower_better)"
    d_cov="$(delta_arrow "$cov_pct_str" "$PREV_COVERAGE" higher_better)"
    d_retro="$(delta_arrow "$RETRO_CONV" "$PREV_RETRO_CONV" higher_better)"
    d_specfid="$(delta_arrow "$SPEC_FID" "$PREV_SPEC_FID" higher_better)"
    deltas_html="<table style=\"width:100%;border-collapse:collapse;\">
<tr style=\"border-bottom:1px solid #dee2e6;\"><th style=\"text-align:left;padding:6px;\">Metric</th><th style=\"text-align:left;padding:6px;\">Previous</th><th style=\"text-align:left;padding:6px;\">Current</th><th style=\"text-align:left;padding:6px;\">Trend</th></tr>
<tr><td style=\"padding:6px;\">Lead Time p50</td><td style=\"padding:6px;\">${PREV_LT_P50:-N/A}</td><td style=\"padding:6px;\">${LT_P50}</td><td style=\"padding:6px;\">${d_lt50}</td></tr>
<tr style=\"background:#f8f9fa;\"><td style=\"padding:6px;\">Lead Time p95</td><td style=\"padding:6px;\">${PREV_LT_P95:-N/A}</td><td style=\"padding:6px;\">${LT_P95}</td><td style=\"padding:6px;\">${d_lt95}</td></tr>
<tr><td style=\"padding:6px;\">CFR</td><td style=\"padding:6px;\">${PREV_CFR:-N/A}</td><td style=\"padding:6px;\">${CFR}</td><td style=\"padding:6px;\">${d_cfr}</td></tr>
<tr style=\"background:#f8f9fa;\"><td style=\"padding:6px;\">Spec-Fidelity</td><td style=\"padding:6px;\">${PREV_SPEC_FID:-N/A}</td><td style=\"padding:6px;\">${SPEC_FID}</td><td style=\"padding:6px;\">${d_specfid}</td></tr>
<tr><td style=\"padding:6px;\">Agent Coverage</td><td style=\"padding:6px;\">${PREV_COVERAGE:-N/A}</td><td style=\"padding:6px;\">${cov_pct_str}</td><td style=\"padding:6px;\">${d_cov}</td></tr>
<tr style=\"background:#f8f9fa;\"><td style=\"padding:6px;\">Retro Conversion</td><td style=\"padding:6px;\">${PREV_RETRO_CONV:-N/A}</td><td style=\"padding:6px;\">${RETRO_CONV}</td><td style=\"padding:6px;\">${d_retro}</td></tr>
</table>"
  else
    deltas_html="<p style=\"color:#6c757d;font-style:italic;\">First snapshot -- no comparison available.</p>"
  fi

  # Maturity rubric rows
  local maturity_html
  if [ "$MATURITY_SPEC" = "unknown" ] && [ "$MATURITY_REVIEW" = "unknown" ] && \
     [ "$MATURITY_LEARNING" = "unknown" ] && [ "$MATURITY_DELIVERY" = "unknown" ] && \
     [ "$MATURITY_OBS" = "unknown" ] && [ ! -f "docs/maturity-assessment.md" ]; then
    maturity_html="<p style=\"color:#6c757d;font-style:italic;\">Run /onboard-brownfield or complete first retrospective gate to populate.</p>"
  else
    local r1c1 r1c2 r1c3 r1c4
    r1c1="$(rubric_cell "$MATURITY_SPEC" L1 '&lt;50% PRD antes do c&oacute;digo')"
    r1c2="$(rubric_cell "$MATURITY_SPEC" L2 '&ge;80% PRD; &lt;50% T2/T3 com clarify')"
    r1c3="$(rubric_cell "$MATURITY_SPEC" L3 '&ge;80% T2+ com clarify; Fidelity &ge;70% 3 m&oacute;dulos')"
    r1c4="$(rubric_cell "$MATURITY_SPEC" L4 'Fidelity &ge;85% 6 m&oacute;dulos; clarify &le;2 perguntas')"

    local r2c1 r2c2 r2c3 r2c4
    r2c1="$(rubric_cell "$MATURITY_REVIEW" L1 'Review-team &lt;60%')"
    r2c2="$(rubric_cell "$MATURITY_REVIEW" L2 'Standard 100%; cr&iacute;ticos ad-hoc')"
    r2c3="$(rubric_cell "$MATURITY_REVIEW" L3 'Depth correta &ge;90%; 0 LLM-review skip')"
    r2c4="$(rubric_cell "$MATURITY_REVIEW" L4 '0 cr&iacute;ticos p&oacute;s-merge/tri; &lt;1 blocker/m&oacute;dulo')"

    local r3c1 r3c2 r3c3 r3c4
    r3c1="$(rubric_cell "$MATURITY_LEARNING" L1 'Retro skipado')"
    r3c2="$(rubric_cell "$MATURITY_LEARNING" L2 '&ge;80% m&oacute;dulos; &lt;30% &rarr; diff')"
    r3c3="$(rubric_cell "$MATURITY_LEARNING" L3 'Conversion &ge;40%; cada agent &ge;1 bump/90d')"
    r3c4="$(rubric_cell "$MATURITY_LEARNING" L4 'Conversion &ge;60%; 0 blockers repetidos 3 m&oacute;dulos')"

    local r4c1 r4c2 r4c3 r4c4
    r4c1="$(rubric_cell "$MATURITY_DELIVERY" L1 'CFR n&atilde;o medido ou &gt;25%')"
    r4c2="$(rubric_cell "$MATURITY_DELIVERY" L2 'CFR &le;20%; lead time medido')"
    r4c3="$(rubric_cell "$MATURITY_DELIVERY" L3 'CFR &le;15%, p95 &le;5d 3 m&oacute;dulos')"
    r4c4="$(rubric_cell "$MATURITY_DELIVERY" L4 'CFR &le;10%, p95 &le;3d 6 m&oacute;dulos; 0 rollbacks/tri')"

    local r5c1 r5c2 r5c3 r5c4
    r5c1="$(rubric_cell "$MATURITY_OBS" L1 'Sem ## Tooling &gt; obs')"
    r5c2="$(rubric_cell "$MATURITY_OBS" L2 'Stack escolhida; health check definido')"
    r5c3="$(rubric_cell "$MATURITY_OBS" L3 '100% deploys validados; 0 catalog gap 3 m&oacute;dulos')"
    r5c4="$(rubric_cell "$MATURITY_OBS" L4 'Audit encontra &ge;1 problema antes de incidente')"

    maturity_html="<table style=\"width:100%;border-collapse:collapse;font-size:0.85em;\">
<tr style=\"background:#e9ecef;\"><th style=\"padding:8px;text-align:left;\">Dimension</th><th style=\"padding:8px;text-align:center;\">L1</th><th style=\"padding:8px;text-align:center;\">L2</th><th style=\"padding:8px;text-align:center;\">L3</th><th style=\"padding:8px;text-align:center;\">L4</th></tr>
<tr style=\"border-bottom:1px solid #dee2e6;\"><td style=\"padding:8px;font-weight:600;\">Spec Discipline</td>${r1c1}${r1c2}${r1c3}${r1c4}</tr>
<tr style=\"border-bottom:1px solid #dee2e6;background:#f8f9fa;\"><td style=\"padding:8px;font-weight:600;\">Review Coverage</td>${r2c1}${r2c2}${r2c3}${r2c4}</tr>
<tr style=\"border-bottom:1px solid #dee2e6;\"><td style=\"padding:8px;font-weight:600;\">Learning Loop</td>${r3c1}${r3c2}${r3c3}${r3c4}</tr>
<tr style=\"border-bottom:1px solid #dee2e6;background:#f8f9fa;\"><td style=\"padding:8px;font-weight:600;\">Delivery Stability</td>${r4c1}${r4c2}${r4c3}${r4c4}</tr>
<tr><td style=\"padding:8px;font-weight:600;\">Observability</td>${r5c1}${r5c2}${r5c3}${r5c4}</tr>
</table>"
  fi

  mkdir -p "$(dirname "$html_output")"

  cat > "$html_output" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ai-squad Engineering Metrics</title>
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #f8f9fa; color: #212529; margin: 0; padding: 0;
    line-height: 1.6;
  }
  .container { max-width: 900px; margin: 0 auto; padding: 24px 16px; }
  header { text-align: center; margin-bottom: 32px; }
  header h1 { margin: 0 0 4px; font-size: 1.6em; color: #212529; }
  header .meta { color: #6c757d; font-size: 0.9em; }
  .card {
    background: #fff; border-radius: 8px; padding: 20px 24px; margin-bottom: 20px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06);
  }
  .card h2 { margin: 0 0 16px; font-size: 1.15em; color: #343a40; border-bottom: 2px solid #e9ecef; padding-bottom: 8px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { padding: 8px; text-align: left; }
  th { font-weight: 600; }
  .metric-row { border-bottom: 1px solid #e9ecef; }
  .metric-row:last-child { border-bottom: none; }
  .metric-label { font-weight: 500; color: #495057; }
  .metric-value { text-align: right; }
  footer { text-align: center; color: #adb5bd; font-size: 0.8em; margin-top: 32px; padding-top: 16px; border-top: 1px solid #e9ecef; }
  footer a { color: #6c757d; }
  @media (max-width: 600px) {
    .container { padding: 12px 8px; }
    .card { padding: 14px 16px; }
    table { font-size: 0.9em; }
  }
</style>
</head>
<body>
<div class="container">
<header>
  <h1>ai-squad Engineering Metrics</h1>
  <div class="meta">Generated: ${NOW_ISO} &middot; Window: last ${DAYS} days</div>
</header>

<div class="card">
  <h2>DORA Adapted</h2>
  <table>
    <tr class="metric-row"><td class="metric-label">Lead Time for Change — p50</td><td class="metric-value">${lt_p50_badge}</td></tr>
    <tr class="metric-row"><td class="metric-label">Lead Time for Change — p95</td><td class="metric-value">${lt_p95_badge}</td></tr>
    <tr class="metric-row"><td class="metric-label">Change Failure Rate</td><td class="metric-value">${cfr_badge}</td></tr>
  </table>
</div>

<div class="card">
  <h2>Process Health</h2>
  <div style="margin-bottom:12px;">
    <div class="metric-label" style="margin-bottom:4px;">Rework Rate per module</div>
    ${rework_html}
  </div>
  <table>
    <tr class="metric-row"><td class="metric-label">Spec-Fidelity Rate</td><td class="metric-value">${specfid_badge}</td></tr>
    <tr class="metric-row"><td class="metric-label">Stage Cycle Time</td><td class="metric-value"><span style="display:inline-block;padding:2px 8px;border-radius:4px;font-size:0.85em;font-weight:600;background:#e9ecef;color:#495057;">${CYCLE}</span></td></tr>
  </table>
</div>

<div class="card">
  <h2>Agentic-Specific</h2>
  <table>
    <tr class="metric-row"><td class="metric-label">Agent Coverage</td><td class="metric-value">${coverage_badge}</td></tr>
    <tr class="metric-row"><td class="metric-label">Retro &rarr; Diff Conversion Rate</td><td class="metric-value">${retro_badge}</td></tr>
  </table>
  <div style="margin-top:12px;">
    <div class="metric-label" style="margin-bottom:4px;">Agent Definition Versioning Velocity</div>
    ${versioning_html}
  </div>
</div>

<div class="card">
  <h2>Maturity Rubric</h2>
  ${maturity_html}
</div>

<div class="card">
  <h2>Deltas (vs. Previous Snapshot)</h2>
  ${deltas_html}
</div>

<footer>
  Generated by <a href="https://github.com/carlos-sobral/ai-squad">ai-squad</a> collect.sh
</footer>
</div>
</body>
</html>
HTMLEOF

  log_info "Wrote ${html_output}"
}

write_report "$OUTPUT"
render_html

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
