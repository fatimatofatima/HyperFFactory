#!/usr/bin/env bash
set -Eeuo pipefail

SUITE="/opt/smartfriend-suite"
LEGACY_DIRS=(
  "/opt/smartfrind"
  "/opt/smartfrind_unified"
  "/opt/SmartFrind_Miracle"
  "/opt/SmartFriend"
  "/opt/ffactory"
  "/opt/deepseek"
)

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$SUITE/reports"

mkdir -p "$REPORT_DIR"

TXT="$REPORT_DIR/sf_capabilities_${TS}.txt"
JSON="$REPORT_DIR/sf_capabilities_${TS}.json"

have() { command -v "$1" >/dev/null 2>&1; }

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$TXT" >/dev/null
}

sec() {
  {
    echo
    echo "============================================================"
    echo ">>> $*"
    echo "============================================================"
  } | tee -a "$TXT" >/dev/null
}

suite_self_hits=0
legacy_self_hits=0
suite_memory_dbs=0
legacy_memory_dbs=0
suite_quality_filters=0
legacy_quality_filters=0
experience_recent_logs=0
dw_total_dbs=0
dw_unified_like=0

list_existing_dir() {
  for d in "$@"; do
    [ -d "$d" ] && echo " - $d"
  done
}

scan_self_awareness() {
  sec "A) Self-awareness and environment"

  if [ ! -d "$SUITE" ]; then
    log "Warning: suite dir $SUITE not found."
    return
  fi

  log "Root suite dir: $SUITE"
  log "Existing legacy roots:"
  list_existing_dir "${LEGACY_DIRS[@]}" | tee -a "$TXT" >/dev/null

  echo | tee -a "$TXT" >/dev/null
  log "Scanning self/environment modules in suite..."

  local candidates=(
    "cognitive_system/consciousness/self_awareness.py"
    "cognitive_system/consciousness"
    "cognitive_system/personality"
    "cognitive_system/environment"
    "health/health.py"
    "ops/health_gate.py"
  )

  for rel in "${candidates[@]}"; do
    if [ -e "$SUITE/$rel" ]; then
      log "FOUND in suite: $rel"
      suite_self_hits=$((suite_self_hits + 1))
    fi
  done

  echo | tee -a "$TXT" >/dev/null
  log "Searching for endpoints like /health, /status, /whoami in suite apps..."

  if [ -d "$SUITE/apps" ]; then
    grep -R -n --color=never -E '"/health"|"/status"|"/whoami"|"/about"' "$SUITE/apps" 2>/dev/null \
      | head -n 40 | tee -a "$TXT" >/dev/null || true
  fi
  if [ -d "$SUITE/bots/app" ]; then
    grep -R -n --color=never -E '"/health"|"/status"|"/whoami"|"/about"' "$SUITE/bots/app" 2>/dev/null \
      | head -n 40 | tee -a "$TXT" >/dev/null || true
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Searching for self-awareness modules in legacy dirs..."

  for d in "${LEGACY_DIRS[@]}"; do
    [ -d "$d" ] || continue
    log "Legacy scan in: $d"
    find "$d" -maxdepth 6 -type f \( -iname "*self_awareness*.py" -o -iname "*identity*.py" -o -iname "*conscious*.py" \) 2>/dev/null \
      | head -n 20 | tee -a "$TXT" >/dev/null || true
    local c
    c="$(find "$d" -maxdepth 6 -type f \( -iname "*self_awareness*.py" -o -iname "*identity*.py" -o -iname "*conscious*.py" \) 2>/dev/null | wc -l || echo 0)"
    legacy_self_hits=$((legacy_self_hits + c))
  done

  log "Summary A) suite_self_hits=$suite_self_hits, legacy_self_hits=$legacy_self_hits"
}

scan_memory() {
  sec "B) Persistent memory"

  log "Listing sqlite databases (*.db) inside suite..."
  if find "$SUITE" -maxdepth 4 -type f -name "*.db" 2>/dev/null | grep -q .; then
    find "$SUITE" -maxdepth 4 -type f -name "*.db" 2>/dev/null \
      | tee -a "$TXT" >/dev/null
    suite_memory_dbs="$(find "$SUITE" -maxdepth 4 -type f -name "*.db" 2>/dev/null | wc -l || echo 0)"
  else
    log "No *.db files found in suite at depth <=4."
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Listing sqlite databases in legacy dirs..."
  for d in "${LEGACY_DIRS[@]}"; do
    [ -d "$d" ] || continue
    log "Legacy DB scan in: $d"
    find "$d" -maxdepth 4 -type f -name "*.db" 2>/dev/null | tee -a "$TXT" >/dev/null || true
    local c
    c="$(find "$d" -maxdepth 4 -type f -name "*.db" 2>/dev/null | wc -l || echo 0)"
    legacy_memory_dbs=$((legacy_memory_dbs + c))
  done

  if have sqlite3; then
    echo | tee -a "$TXT" >/dev/null
    log "sqlite3 present – sampling tables from first 3 suite DBs..."
    while IFS= read -r db; do
      [ -f "$db" ] || continue
      echo | tee -a "$TXT" >/dev/null
      log "DB: $db"
      sqlite3 "$db" ".tables" 2>/dev/null | head -n 30 | sed 's/^/  table: /' | tee -a "$TXT" >/dev/null || true
    done < <(find "$SUITE" -maxdepth 4 -type f -name "*.db" 2>/dev/null | head -n 3)
  else
    log "sqlite3 not found; skipping table inspection."
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Searching for memory manager modules..."
  if [ -d "$SUITE/packages/memory" ]; then
    find "$SUITE/packages/memory" -maxdepth 3 -type f -name "*memory*.py" 2>/dev/null \
      | tee -a "$TXT" >/dev/null || true
  fi
  for d in "${LEGACY_DIRS[@]}"; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth 6 -type f -iname "*memory_manager*.py" 2>/dev/null \
      | sed "s|^|$d: |" | tee -a "$TXT" >/dev/null || true
  done

  log "Summary B) suite_memory_dbs=$suite_memory_dbs, legacy_memory_dbs=$legacy_memory_dbs"
}

scan_quality_filters() {
  sec "C) Quality filters and promotion logic"

  log "Scanning quality_filter / learn_promote / self_monitor in suite brain..."
  local qfiles
  qfiles="$(find "$SUITE" -maxdepth 6 -type f \( -iname "quality_filter.py" -o -iname "learn_promote.py" -o -iname "self_monitor.py" \) 2>/dev/null || true)"
  if [ -n "$qfiles" ]; then
    echo "$qfiles" | tee -a "$TXT" >/dev/null
    suite_quality_filters="$(echo "$qfiles" | wc -l || echo 0)"
  else
    log "No quality-related modules found in suite (depth <=6)."
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Scanning ingest and bots for quality/score/promote signals..."
  for path in "$SUITE/packages/ingest" "$SUITE/bots"; do
    [ -d "$path" ] || continue
    log "Search in: $path"
    grep -R -n --color=never -E "quality_score|score|promote|relevance|confidence" "$path" 2>/dev/null \
      | head -n 60 | tee -a "$TXT" >/dev/null || true
  done

  echo | tee -a "$TXT" >/dev/null
  log "Scanning legacy dirs for quality / smart_memory_upgrade scripts..."
  for d in "${LEGACY_DIRS[@]}"; do
    [ -d "$d" ] || continue
    log "Legacy quality scan in: $d"
    find "$d" -maxdepth 6 -type f \( -iname "*smart_memory_upgrade*.sh" -o -iname "*quality*.py" -o -iname "*promote*.py" \) 2>/dev/null \
      | tee -a "$TXT" >/dev/null || true
    local c
    c="$(find "$d" -maxdepth 6 -type f \( -iname "*smart_memory_upgrade*.sh" -o -iname "*quality*.py" -o -iname "*promote*.py" \) 2>/dev/null | wc -l || echo 0)"
    legacy_quality_filters=$((legacy_quality_filters + c))
  done

  log "Summary C) suite_quality_filters=$suite_quality_filters, legacy_quality_filters=$legacy_quality_filters"
}

scan_experience() {
  sec "D) Experience tracking / self-monitoring"

  log "Looking for self_monitor modules..."
  if [ -d "$SUITE/cognitive_system/brain" ]; then
    find "$SUITE/cognitive_system/brain" -maxdepth 3 -type f -iname "*self_monitor*.py" 2>/dev/null \
      | tee -a "$TXT" >/dev/null || true
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Scanning logs and reports for recent activity (last 7 days)..."
  local log_dirs=(
    "$SUITE/logs"
    "$SUITE/bots/logs"
    "$SUITE/factory/reports"
  )

  for ld in "${log_dirs[@]}"; do
    [ -d "$ld" ] || continue
    log "Logs dir: $ld"
    local recent
    recent="$(find "$ld" -type f -mtime -7 2>/dev/null | wc -l || echo 0)"
    experience_recent_logs=$((experience_recent_logs + recent))
    find "$ld" -type f -mtime -7 2>/dev/null | head -n 20 | sed 's/^/  recent: /' | tee -a "$TXT" >/dev/null || true
  done

  log "Summary D) experience_recent_logs(last 7 days)=$experience_recent_logs"
}

scan_data_warehouse() {
  sec "E) Data warehouse / unified storage"

  log "Collecting all sqlite DBs under suite (depth <=6)..."
  local all_dbs
  all_dbs="$(find "$SUITE" -maxdepth 6 -type f -name "*.db" 2>/dev/null || true)"
  if [ -n "$all_dbs" ]; then
    echo "$all_dbs" | tee -a "$TXT" >/dev/null
    dw_total_dbs="$(echo "$all_dbs" | wc -l || echo 0)"
  else
    log "No DB files found inside suite."
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Looking for unified/warehouse/central DBs..."
  if [ -n "${all_dbs:-}" ]; then
    echo "$all_dbs" \
      | grep -Ei "unified|warehouse|central" 2>/dev/null \
      | tee -a "$TXT" >/dev/null || true
    dw_unified_like="$(echo "$all_dbs" | grep -Ei "unified|warehouse|central" 2>/dev/null | wc -l || echo 0)"
  fi

  echo | tee -a "$TXT" >/dev/null
  log "Searching in code for smartfriend_unified.db or warehouse keywords..."
  grep -R -n --color=never -E "smartfriend_unified\.db|warehouse|data_warehouse" "$SUITE" 2>/dev/null \
    | head -n 60 | tee -a "$TXT" >/dev/null || true

  log "Summary E) dw_total_dbs=$dw_total_dbs, dw_unified_like=$dw_unified_like"
}

write_json() {
  {
    echo "{"
    echo "  \"meta\": {"
    echo "    \"generated_at\": \"$(date -Iseconds)\","
    echo "    \"suite_root\": \"${SUITE}\","
    echo "    \"legacy_roots\": ["
    local first=1
    for d in "${LEGACY_DIRS[@]}"; do
      [ -d "$d" ] || continue
      if [ $first -eq 1 ]; then
        echo "      \"${d}\""
        first=0
      else
        echo "      ,\"${d}\""
      fi
    done
    echo "    ]"
    echo "  },"
    echo "  \"self_awareness\": {"
    echo "    \"suite_hits\": ${suite_self_hits},"
    echo "    \"legacy_hits\": ${legacy_self_hits}"
    echo "  },"
    echo "  \"memory\": {"
    echo "    \"suite_memory_dbs\": ${suite_memory_dbs},"
    echo "    \"legacy_memory_dbs\": ${legacy_memory_dbs}"
    echo "  },"
    echo "  \"quality_filters\": {"
    echo "    \"suite_quality_filters\": ${suite_quality_filters},"
    echo "    \"legacy_quality_filters\": ${legacy_quality_filters}"
    echo "  },"
    echo "  \"experience_tracking\": {"
    echo "    \"recent_log_files_last_7_days\": ${experience_recent_logs}"
    echo "  },"
    echo "  \"data_warehouse\": {"
    echo "    \"total_dbs_in_suite\": ${dw_total_dbs},"
    echo "    \"unified_like_dbs\": ${dw_unified_like}"
    echo "  }"
    echo "}"
  } >"$JSON"
}

main() {
  sec "SmartFriend Suite – Capabilities Audit"
  log "TS: $TS"
  log "Reports:"
  log "  TXT : $TXT"
  log "  JSON: $JSON"

  scan_self_awareness
  scan_memory
  scan_quality_filters
  scan_experience
  scan_data_warehouse

  sec "Summary – quick numbers"
  log "self_awareness: suite_hits=$suite_self_hits, legacy_hits=$legacy_self_hits"
  log "memory: suite_dbs=$suite_memory_dbs, legacy_dbs=$legacy_memory_dbs"
  log "quality_filters: suite=$suite_quality_filters, legacy=$legacy_quality_filters"
  log "experience_recent_logs (7d)=$experience_recent_logs"
  log "data_warehouse: total_dbs_in_suite=$dw_total_dbs, unified_like=$dw_unified_like"

  write_json

  echo | tee -a "$TXT" >/dev/null
  log "Reports generated:"
  log " - TXT : $TXT"
  log " - JSON: $JSON"
}

main "$@"
