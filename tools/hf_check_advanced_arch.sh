#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="reports/hf_advanced_arch_check_${TS}.log"
mkdir -p reports

echo "=== HyperFFactory – Advanced Architecture Check (${TS}) ===" | tee "$REPORT"
echo "Root: $(pwd)" | tee -a "$REPORT"
echo | tee -a "$REPORT"

# Helpers
divider() {
  echo "----------------------------------------------------------------" | tee -a "$REPORT"
}

sec() {
  echo | tee -a "$REPORT"
  echo "## $*" | tee -a "$REPORT"
  divider
}

check_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    echo "[OK]    dir  $path" | tee -a "$REPORT"
    return 0
  else
    echo "[MISS]  dir  $path" | tee -a "$REPORT"
    return 1
  fi
}

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "[OK]    file $path" | tee -a "$REPORT"
    return 0
  else
    echo "[MISS]  file $path" | tee -a "$REPORT"
    return 1
  fi
}

check_db_exists() {
  local path="$1"
  if [[ -f "$path" ]]; then
    echo "[OK]    db   $path" | tee -a "$REPORT"
    return 0
  else
    echo "[MISS]  db   $path" | tee -a "$REPORT"
    return 1
  fi
}

check_db_table() {
  local db="$1"
  local table="$2"
  if [[ ! -f "$db" ]]; then
    echo "[MISS]  table $table (db missing: $db)" | tee -a "$REPORT"
    return 1
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "[SKIP]  sqlite3 not installed, cannot inspect $db" | tee -a "$REPORT"
    return 2
  fi
  if sqlite3 "$db" ".tables" | grep -qw "$table"; then
    echo "[OK]    table $table in $db" | tee -a "$REPORT"
    return 0
  else
    echo "[MISS]  table $table in $db" | tee -a "$REPORT"
    return 1
  fi
}

search_string() {
  local label="$1"
  local pattern="$2"
  shift 2
  local paths=("$@")
  if grep -R "$pattern" "${paths[@]}" >/dev/null 2>&1; then
    echo "[OK]    $label: found pattern '$pattern' in ${paths[*]}" | tee -a "$REPORT"
    return 0
  else
    echo "[MISS]  $label: pattern '$pattern' not found in ${paths[*]}" | tee -a "$REPORT"
    return 1
  fi
}

list_spider_scripts() {
  echo "[INFO]  spider-related scripts (sh/py) near root:" | tee -a "$REPORT"
  find . -maxdepth 6 -type f \( -iname "*spider*.sh" -o -iname "*spider*.py" \) 2>/dev/null \
    | sed 's/^/        - /' | tee -a "$REPORT" || true
}

# 1) Lakehouse Layer
sec "1) Knowledge Lakehouse Layer"

check_dir "data_lakehouse" || true
check_dir "data_lakehouse/raw_zone" || true
check_dir "data_lakehouse/cleansed_zone" || true
check_dir "data_lakehouse/semantic_zone" || true
check_dir "data_lakehouse/serving_zone" || true

check_file "config/lakehouse_manifest.yaml" || true

# 2) Specialized Factories
sec "2) Specialized Factories over Lakehouse"

check_dir "factories" || true
check_dir "factories/model_factory" || true
check_dir "factories/knowledge_factory" || true
check_dir "factories/quality_factory" || true

echo "[INFO]  Any links from factories/* to current workers/pipeline:" | tee -a "$REPORT"
grep -R "factories/" workers scripts tools 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

# 3) Spider → Unified Knowledge
sec "3) Spider to Unified Knowledge"

check_dir "knowledge" || true
check_db_exists "db/meta/hf_knowledge.db" || true

list_spider_scripts

echo "[INFO]  Any references to hf_knowledge or knowledge DB in code:" | tee -a "$REPORT"
grep -R "hf_knowledge" . 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

# 4) Patterns System as Actual Service
sec "4) Patterns System"

check_db_exists "db/meta/hf_patterns.db" || true
check_dir "core/patterns" || true
check_dir "patterns" || true

search_string "pattern_store usage" "pattern_store" ai workers tools scripts 2>/dev/null || true

# 5) Multi-System Quality KPIs
sec "5) Quality KPIs (Multi-System)"

QUALITY_DB="db/meta/hf_quality.db"
check_db_exists "$QUALITY_DB" || true

if [[ -f "$QUALITY_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
  echo "[INFO]  hf_quality.db – tables:" | tee -a "$REPORT"
  sqlite3 "$QUALITY_DB" ".tables" 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

  echo "[INFO]  Sample quality rows (up to 10):" | tee -a "$REPORT"
  sqlite3 "$QUALITY_DB" "SELECT * FROM quality_events LIMIT 10;" 2>/dev/null \
    | sed 's/^/        /' | tee -a "$REPORT" || echo "[INFO]  table quality_events not found or empty" | tee -a "$REPORT"
fi

check_file "tools/hf_quality_report.sh" || check_file "bin/hf_quality_report.sh" || true

# 6) Training & Experience System
sec "6) Training & Experience System"

LEARN_DB1="db/meta/learning_hf.db"
LEARN_DB2="db/learning_hf.db"

check_db_exists "$LEARN_DB1" || true
check_db_exists "$LEARN_DB2" || true

check_db_table "$LEARN_DB1" "SkillState" || true
check_db_table "$LEARN_DB2" "SkillState" || true

# Experience views / reports
check_file "tools/hf_learning_report.sh" || true
check_file "tools/hf_scan_brain_memory_quality.sh" || true

TASKS_DB="db/meta/hf_tasks.db"
check_db_exists "$TASKS_DB" || true

if [[ -f "$TASKS_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
  echo "[INFO]  hf_tasks.db – tables:" | tee -a "$REPORT"
  sqlite3 "$TASKS_DB" ".tables" 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

  echo "[INFO]  Sample TRAINING-related tasks (if any):" | tee -a "$REPORT"
  sqlite3 "$TASKS_DB" "SELECT id, actor, type, status, created_at FROM tasks WHERE type LIKE '%TRAIN%' OR actor LIKE '%coach%' LIMIT 10;" 2>/dev/null \
    | sed 's/^/        /' | tee -a "$REPORT" || echo "[INFO]  no explicit TRAINING tasks found" | tee -a "$REPORT"
fi

# 7) Incidents & Errors System
sec "7) Incidents & Errors System"

ERRORS_DB1="db/meta/hf_errors.db"
ERRORS_DB2="db/errors_hf.db"

check_db_exists "$ERRORS_DB1" || true
check_db_exists "$ERRORS_DB2" || true

if [[ -f "$ERRORS_DB1" ]] && command -v sqlite3 >/dev/null 2>&1; then
  echo "[INFO]  hf_errors.db – tables:" | tee -a "$REPORT"
  sqlite3 "$ERRORS_DB1" ".tables" 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

  echo "[INFO]  Looking for incident-ish table names:" | tee -a "$REPORT"
  sqlite3 "$ERRORS_DB1" ".tables" 2>/dev/null | grep -Ei "incident|error|failure|alert" | sed 's/^/        /' | tee -a "$REPORT" || \
    echo "        (no explicit incident-like table names)" | tee -a "$REPORT"
fi

# 8) Coach & System Architect linkage
sec "8) Technical Coach & System Architect Linkage"

check_file "config/agents.yaml" || true
check_file "config/modules.json" || true
check_file "config/modules_enhanced.json" || true

if [[ -f "config/agents.yaml" ]]; then
  echo "[INFO]  agents.yaml entries (grep coach/architect):" | tee -a "$REPORT"
  grep -Ei "coach|architect" config/agents.yaml 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || \
    echo "        (no explicit coach/architect entries)" | tee -a "$REPORT"
fi

search_string "technical_coach references" "technical_coach" . || true
search_string "system_architect references" "system_architect" . || true

# 9) Orchestrator / Workers Unified Config
sec "9) Orchestrator & Workers Unified Config"

check_file "config/agents.yaml" || true
check_file "config/worker_orchestrator.yaml" || true
check_file "config/modules_enhanced.json" || true

echo "[INFO]  Any references to orchestrator / workers config:" | tee -a "$REPORT"
grep -R "orchestrator" config scripts tools workers 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

# 10) Official ffactory Bridge
sec "10) Official ffactory Bridge"

echo "[INFO]  Looking for dedicated ffactory bridge scripts:" | tee -a "$REPORT"
find scripts tools -maxdepth 4 -type f -iname "*ffactory*" 2>/dev/null | sed 's/^/        - /' | tee -a "$REPORT" || \
  echo "        (no ffactory-named bridge scripts found)" | tee -a "$REPORT"

search_string "ffactory references in code" "ffactory" . || true

if [[ -f "$QUALITY_DB" ]] && command -v sqlite3 >/dev/null 2>&1; then
  echo "[INFO]  Any quality entries tagged ffactory (top 10):" | tee -a "$REPORT"
  sqlite3 "$QUALITY_DB" "SELECT * FROM quality_events WHERE system LIKE '%ffactory%' LIMIT 10;" 2>/dev/null \
    | sed 's/^/        /' | tee -a "$REPORT" || echo "        (no explicit ffactory rows)" | tee -a "$REPORT"
fi

# 11) Unified Dashboard beyond CLI
sec "11) Unified Dashboard (beyond CLI)"

check_file "tools/hf_dashboard_cli.sh" || true
check_file "scripts/run_hyper_api.sh" || true

echo "[INFO]  Searching for web/telegram dashboard pieces (fastapi, bot, dashboard words):" | tee -a "$REPORT"
grep -R "FastAPI\|dashboard\|Telegram" apps scripts tools 2>/dev/null | sed 's/^/        /' | tee -a "$REPORT" || true

# 12) Unified Data Model for Users/Sessions/Feedback
sec "12) Unified Data Model (Users / Sessions / Feedback)"

if command -v sqlite3 >/dev/null 2>&1; then
  echo "[INFO]  Scanning db/*.db for user/session/message/evaluation/knowledge tables..." | tee -a "$REPORT"
  find db -type f -name "*.db" 2>/dev/null | while read -r DB; do
    echo "  DB: $DB" | tee -a "$REPORT"
    TABLES="$(sqlite3 "$DB" ".tables" 2>/dev/null || true)"
    echo "$TABLES" | sed 's/^/        /' | tee -a "$REPORT"
    echo | tee -a "$REPORT"
  done
else
  echo "[SKIP]  sqlite3 not available – cannot enumerate DB schemas" | tee -a "$REPORT"
fi

echo | tee -a "$REPORT"
divider
echo "[SUMMARY] Detailed report written to: $REPORT" | tee -a "$REPORT"
echo "=== End of Advanced Architecture Check ===" | tee -a "$REPORT"
