#!/usr/bin/env bash
# HyperFFactory – hf_db_manager Runner
# ينفّذ مهام hf_db_manager من hf_tasks.db على db/meta/*.db
# نطاق العمل:
#   - db_manager:meta_dbs:check_schema
#   - db_manager:meta_dbs:integrity_check
#   - db_manager:meta_dbs:vacuum
#   - db_manager:meta_dbs:size_report
#   - db_manager:meta_dbs:backup_policy
#   - db_manager:meta_dbs:scan_meta_dbs
#   - db_manager:meta_dbs:rebuild_registry
#   - db_manager:meta_dbs:rebuild_index

set -euo pipefail

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "ERROR: sqlite3 not installed." >&2
  exit 1
fi

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
TASKS_DB="$META_DIR/hf_tasks.db"
REG_DB="$META_DIR/hf_db_registry.db"
FILES_INDEX_DB="$META_DIR/hf_files_index.db"
REPORTS_DIR="$ROOT/reports"
mkdir -p "$REPORTS_DIR"

TS_RUN="$(date +'%Y-%m-%d %H:%M:%S %z')"
TS_FILE="$(date +'%Y%m%d_%H%M%S')"
LOG="$REPORTS_DIR/hf_db_manager_run_${TS_FILE}.log"

log() {
  local msg="$*"
  printf '%s [DBMGR] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$msg" | tee -a "$LOG"
}

log "Start hf_db_manager_run – ROOT=$ROOT"

if [ ! -f "$TASKS_DB" ]; then
  log "ERROR: tasks DB not found at $TASKS_DB"
  exit 1
fi

# كشف قواعد بيانات الميتا
if ! ls "$META_DIR"/*.db >/dev/null 2>&1; then
  log "ERROR: no meta DBs (*.db) under $META_DIR"
  exit 1
fi

mapfile -t META_DBS < <(find "$META_DIR" -maxdepth 1 -type f -name '*.db' | sort)
log "Discovered ${#META_DBS[@]} meta DB(s)."

# قراءة المهام PLANNED لـ hf_db_manager
mapfile -t TASKS < <(sqlite3 "$TASKS_DB" "
  SELECT id || '|' || scope
  FROM tasks
  WHERE actor='hf_db_manager' AND status='PLANNED'
  ORDER BY priority DESC, id ASC;
")

if [ "${#TASKS[@]}" -eq 0 ]; then
  log "No PLANNED tasks for hf_db_manager – nothing to do."
  echo "Log file: $LOG"
  exit 0
fi

log "Found ${#TASKS[@]} PLANNED task(s) for hf_db_manager."

# ============================
#   عمليات على meta DBs
# ============================

op_check_schema() {
  log "op_check_schema: checking schema accessibility for meta DBs..."
  for db in "${META_DBS[@]}"; do
    if sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1;" >/dev/null 2>&1; then
      log "OK schema access: $(basename "$db")"
    else
      log "WARN cannot read schema: $(basename "$db")"
    fi
  done
}

op_integrity_check() {
  log "op_integrity_check: running PRAGMA integrity_check on meta DBs..."
  for db in "${META_DBS[@]}"; do
    local res
    res=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>&1 || true)
    if [ "$res" = "ok" ]; then
      log "OK integrity_check: $(basename "$db")"
    else
      log "FAIL integrity_check: $(basename "$db") -> $res"
    fi
  done
}

op_vacuum() {
  log "op_vacuum: running VACUUM on meta DBs..."
  for db in "${META_DBS[@]}"; do
    log "VACUUM $(basename "$db")..."
    if sqlite3 "$db" "VACUUM;"; then
      log "OK VACUUM: $(basename "$db")"
    else
      log "WARN VACUUM failed: $(basename "$db")"
    fi
  done
}

op_size_report() {
  log "op_size_report: generating size report for meta DBs..."
  printf "%-30s %-12s %-19s\n" "DB" "SIZE_KB" "MTIME" | tee -a "$LOG"
  for db in "${META_DBS[@]}"; do
    local size_kb mtime_epoch mtime_human
    size_kb=$(du -k "$db" | awk '{print $1}')
    mtime_epoch=$(stat -c '%Y' "$db")
    mtime_human=$(date -d "@$mtime_epoch" +'%Y-%m-%d %H:%M:%S')
    printf "%-30s %-12s %-19s\n" "$(basename "$db")" "$size_kb" "$mtime_human" | tee -a "$LOG"
  done
}

op_backup_policy() {
  log "op_backup_policy: simple backup directories check..."
  local found=0
  for bdir in "$ROOT/backup" "$ROOT/backups"; do
    if [ -d "$bdir" ]; then
      log "Found backup directory: $bdir"
      # عرض بعض الملفات إن وجدت
      find "$bdir" -maxdepth 3 -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.gz' -o -name '*.zst' \) 2>/dev/null | head -n 20 | sed 's/^/  - /' | tee -a "$LOG" || true
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    log "WARN: no backup directories (backup/ or backups/) found directly under $ROOT."
  fi
}

# ============================
#   Registry (hf_db_registry)
# ============================

ensure_meta_registry_schema() {
  log "ensure_meta_registry_schema: ensuring meta_dbs table exists in $REG_DB ..."
  sqlite3 "$REG_DB" "
    CREATE TABLE IF NOT EXISTS meta_dbs (
      id INTEGER PRIMARY KEY,
      file_name   TEXT NOT NULL,
      path        TEXT NOT NULL,
      size_bytes  INTEGER,
      mtime       TEXT,
      tables_count INTEGER,
      last_scan   TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_meta_dbs_path ON meta_dbs(path);
  "
}

op_scan_meta_dbs() {
  log "op_scan_meta_dbs: scanning meta DBs into $REG_DB ..."
  ensure_meta_registry_schema
  local now
  now="$(date +'%Y-%m-%d %H:%M:%S %z')"
  for db in "${META_DBS[@]}"; do
    local size_bytes mtime_epoch mtime_human tables_count
    size_bytes=$(stat -c '%s' "$db")
    mtime_epoch=$(stat -c '%Y' "$db")
    mtime_human=$(date -d "@$mtime_epoch" +'%Y-%m-%d %H:%M:%S')
    tables_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo 0)

    sqlite3 "$REG_DB" "
      INSERT INTO meta_dbs (file_name, path, size_bytes, mtime, tables_count, last_scan)
      VALUES (
        '$(basename "$db")',
        '$db',
        $size_bytes,
        '$mtime_human',
        $tables_count,
        '$now'
      )
      ON CONFLICT(path) DO UPDATE SET
        size_bytes   = excluded.size_bytes,
        mtime        = excluded.mtime,
        tables_count = excluded.tables_count,
        last_scan    = excluded.last_scan;
    "
    log "Indexed meta DB into registry: $(basename "$db")"
  done
}

op_rebuild_registry() {
  log "op_rebuild_registry: full rebuild of meta_dbs registry in $REG_DB ..."
  op_scan_meta_dbs
  log "op_rebuild_registry: done (hf_db_registry.meta_dbs). hf_registry.db left unchanged for now."
}

# ============================
#   Files Index
# ============================

ensure_files_index_schema() {
  log "ensure_files_index_schema: ensuring files_index table exists in $FILES_INDEX_DB ..."
  sqlite3 "$FILES_INDEX_DB" "
    CREATE TABLE IF NOT EXISTS files_index (
      id INTEGER PRIMARY KEY,
      path       TEXT NOT NULL,
      name       TEXT NOT NULL,
      parent     TEXT,
      type       TEXT NOT NULL,
      size_bytes INTEGER,
      mtime      TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_files_index_path ON files_index(path);
  "
}

op_rebuild_index() {
  log "op_rebuild_index: rebuilding files_index in $FILES_INDEX_DB ..."
  ensure_files_index_schema
  sqlite3 "$FILES_INDEX_DB" "DELETE FROM files_index;"

  # Index شجرة HyperFFactory حتى عمق 10، مع استثناء .git و __pycache__
  while IFS= read -r file; do
    local name parent size_bytes mtime_epoch mtime_human
    name=$(basename "$file")
    parent=$(dirname "$file")
    size_bytes=$(stat -c '%s' "$file")
    mtime_epoch=$(stat -c '%Y' "$file")
    mtime_human=$(date -d "@$mtime_epoch" +'%Y-%m-%d %H:%M:%S')

    sqlite3 "$FILES_INDEX_DB" "
      INSERT OR REPLACE INTO files_index (path, name, parent, type, size_bytes, mtime)
      VALUES (
        '$file',
        '$name',
        '$parent',
        'file',
        $size_bytes,
        '$mtime_human'
      );
    "
  done < <(find "$ROOT" -maxdepth 10 -type f ! -path '*/.git/*' ! -path '*/__pycache__/*')

  local cnt
  cnt=$(sqlite3 "$FILES_INDEX_DB" "SELECT COUNT(*) FROM files_index;")
  log "op_rebuild_index: done – total files indexed: $cnt"
}

# ============================
#   تنفيذ المهام وتحديث الحالة
# ============================

for row in "${TASKS[@]}"; do
  id="${row%%|*}"
  scope="${row#*|}"
  log "Processing task id=$id scope=$scope"

  case "$scope" in
    db_manager:meta_dbs:check_schema)
      op_check_schema
      ;;
    db_manager:meta_dbs:integrity_check)
      op_integrity_check
      ;;
    db_manager:meta_dbs:vacuum)
      op_vacuum
      ;;
    db_manager:meta_dbs:size_report)
      op_size_report
      ;;
    db_manager:meta_dbs:backup_policy)
      op_backup_policy
      ;;
    db_manager:meta_dbs:scan_meta_dbs)
      op_scan_meta_dbs
      ;;
    db_manager:meta_dbs:rebuild_registry)
      op_rebuild_registry
      ;;
    db_manager:meta_dbs:rebuild_index)
      op_rebuild_index
      ;;
    *)
      log "WARN: unknown scope for hf_db_manager: $scope – skipped."
      continue
      ;;
  esac

  # تحديث حالة المهمة إلى DONE
  sqlite3 "$TASKS_DB" "
    UPDATE tasks
    SET status='DONE', updated_at='$TS_RUN'
    WHERE id=$id;
  " || log "WARN: failed to update task id=$id to DONE"
done

log "hf_db_manager_run finished."
echo "Log file: $LOG"
