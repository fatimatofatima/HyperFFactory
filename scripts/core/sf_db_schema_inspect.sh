#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"
BASE_OUT="/opt/report/db_schema_inspect_${TS}"
mkdir -p "${BASE_OUT}/schemas" "${BASE_OUT}/samples"

log(){ echo "[$(date '+%F %T')] $*"; }

DBS=(
  "/opt/smartfriend-suite/var/db/memory.db"
  "/opt/smartfriend-suite/var/db/smart_core_memory.db"
  "/opt/smartfriend-suite/var/db/unified_memory.db"
  "/opt/smartfriend-suite/var/db/smartfriend_unified.db"
  "/opt/BRAIN_CORE/memory/shared.db"
)

log "DB Schema + Data Inspect started"
log "Output base dir: ${BASE_OUT}"

for db in "${DBS[@]}"; do
  if [ ! -f "$db" ]; then
    log "SKIP (not found): $db"
    continue
  fi

  name="$(basename "$db" .db)"
  log "=== Inspecting DB: $db (name=${name}) ==="

  schema_file="${BASE_OUT}/schemas/${name}_schema.sql"
  tables_file="${BASE_OUT}/schemas/${name}_tables.txt"
  integrity_file="${BASE_OUT}/schemas/${name}_integrity.txt"

  log "Dump .schema -> ${schema_file}"
  sqlite3 "$db" ".schema" > "${schema_file}"

  log "List tables + row counts -> ${tables_file}"
  {
    echo "=== Tables & Views in ${db} ==="
    sqlite3 -header -column "$db" \
      "SELECT name, type FROM sqlite_master WHERE type IN ('table','view') ORDER BY name;"

    echo
    echo "=== Row counts (user tables) ==="
    sqlite3 -noheader "$db" \
      "SELECT 'SELECT '''||name||''' AS table_name, COUNT(*) AS rows FROM '||name||';'
         FROM sqlite_master
        WHERE type='table' AND name NOT LIKE 'sqlite_%';" \
      | sqlite3 -header -column "$db"
  } > "${tables_file}"

  log "PRAGMA integrity_check -> ${integrity_file}"
  sqlite3 "$db" "PRAGMA integrity_check;" > "${integrity_file}"

  # عينات من كل جدول
  tables=$(sqlite3 "$db" \
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")

  for t in $tables; do
    sample_file="${BASE_OUT}/samples/${name}_${t}_sample.txt"
    log "Sample from table ${t} -> ${sample_file}"
    sqlite3 -header -column "$db" \
      "SELECT * FROM \"${t}\" LIMIT 20;" > "${sample_file}" || true
  done
done

log "DB Schema + Data Inspect finished"
log "Base output dir: ${BASE_OUT}"
