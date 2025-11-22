#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
META_DB="$ROOT/meta/hyper_meta.db"
RUNTIME_ROOT="/opt/hyper-factory/var/db"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/db_audit_${TS}.txt"

log() {
  echo "$@" | tee -a "$REPORT"
}

log "=================================================="
log " HyperFFactory DB Audit (READ-ONLY)"
log " Timestamp : $TS"
log " Root      : $ROOT"
log " Runtime   : $RUNTIME_ROOT"
log " Report    : $REPORT"
log "=================================================="
log ""

########################################
# 1) META DB: hyper_meta.db
########################################
if [[ -f "$META_DB" ]]; then
  log "== [META] hyper_meta.db summary =="
  sqlite3 "$META_DB" "SELECT role, COUNT(*) AS db_count, ROUND(SUM(size_mb),2) AS total_mb FROM db_files GROUP BY role ORDER BY total_mb DESC;" \
    | tee -a "$REPORT" || log "!! خطأ في قراءة db_files من hyper_meta.db"

  log ""
  log "== [META] Top 30 DB files by size (role, size_mb, path) =="
  sqlite3 "$META_DB" "SELECT role, ROUND(size_mb,2) AS size_mb, path FROM db_files ORDER BY size_mb DESC LIMIT 30;" \
    | tee -a "$REPORT" || log "!! تعذر قراءة قائمة أكبر الملفات"
else
  log "!! META DB غير موجود: $META_DB"
fi

########################################
# 2) RUNTIME: identity.db
########################################
IDENTITY_DB="$RUNTIME_ROOT/identity/identity.db"
if [[ -f "$IDENTITY_DB" ]]; then
  log ""
  log "== [RUNTIME] identity.db – basic info =="
  log "Path: $IDENTITY_DB"

  log "-- integrity_check --"
  sqlite3 "$IDENTITY_DB" "PRAGMA integrity_check;" | tee -a "$REPORT" || log "!! integrity_check فشل على identity.db"

  log ""
  log "-- .tables --"
  sqlite3 "$IDENTITY_DB" ".tables" | sed 's/^/tables: /' | tee -a "$REPORT"

  log ""
  log "-- row counts (entities/roles/role_assignments/capabilities/identity_sources/capabilities_profile/entity_capabilities) --"
  for tbl in entities roles role_assignments capabilities entity_capabilities identity_sources capabilities_profile identity_migrations; do
    if sqlite3 "$IDENTITY_DB" ".schema $tbl" >/dev/null 2>&1; then
      cnt="$(sqlite3 "$IDENTITY_DB" "SELECT COUNT(*) FROM $tbl;")"
      log "count($tbl) = $cnt"
    fi
  done

  log ""
  log "-- schema: entities --"
  sqlite3 "$IDENTITY_DB" ".schema entities" | tee -a "$REPORT"
else
  log "!! RUNTIME identity.db غير موجود: $IDENTITY_DB"
fi

########################################
# 3) RUNTIME: memory_core_2025.db
########################################
MEMORY_DB="$RUNTIME_ROOT/memory/memory_core_2025.db"
if [[ -f "$MEMORY_DB" ]]; then
  log ""
  log "== [RUNTIME] memory_core_2025.db – basic info =="
  log "Path: $MEMORY_DB"

  log "-- integrity_check --"
  sqlite3 "$MEMORY_DB" "PRAGMA integrity_check;" | tee -a "$REPORT" || log "!! integrity_check فشل على memory_core_2025.db"

  log ""
  log "-- .tables --"
  sqlite3 "$MEMORY_DB" ".tables" | sed 's/^/tables: /' | tee -a "$REPORT"

  log ""
  log "-- row counts (events/sessions/state_snapshots) --"
  for tbl in events sessions state_snapshots; do
    if sqlite3 "$MEMORY_DB" ".schema $tbl" >/dev/null 2>&1; then
      cnt="$(sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM $tbl;")"
      log "count($tbl) = $cnt"
    fi
  done

  log ""
  log "-- schema: events --"
  sqlite3 "$MEMORY_DB" ".schema events" | tee -a "$REPORT"

  log ""
  log "-- schema: state_snapshots --"
  sqlite3 "$MEMORY_DB" ".schema state_snapshots" | tee -a "$REPORT"
else
  log "!! RUNTIME memory_core_2025.db غير موجود: $MEMORY_DB"
fi

########################################
# 4) Legacy / Knowledge overview (من META فقط)
########################################
if [[ -f "$META_DB" ]]; then
  log ""
  log "== [LEGACY/KNOWLEDGE] ملخص من hyper_meta.db (بدون فتح قواعد البيانات نفسها) =="

  log "-- memory_core مصادر الذاكرة التاريخية (top 10 by size) --"
  sqlite3 "$META_DB" "SELECT role, ROUND(size_mb,2) AS size_mb, path FROM db_files WHERE role='memory_core' ORDER BY size_mb DESC LIMIT 10;" \
    | tee -a "$REPORT" || true

  log ""
  log "-- knowledge_hub مصادر المعرفة (top 10 by size) --"
  sqlite3 "$META_DB" "SELECT role, ROUND(size_mb,2) AS size_mb, path FROM db_files WHERE role='knowledge_hub' ORDER BY size_mb DESC LIMIT 10;" \
    | tee -a "$REPORT" || true

  log ""
  log "-- smartfriend_legacy قواعد البيانات القديمة (كلها) --"
  sqlite3 "$META_DB" "SELECT role, ROUND(size_mb,2) AS size_mb, path FROM db_files WHERE role='smartfriend_legacy' ORDER BY size_mb DESC;" \
    | tee -a "$REPORT" || true
fi

log ""
log "=================================================="
log "انتهى الفحص (READ-ONLY). التقرير محفوظ في:"
log "  $REPORT"
log "=================================================="
