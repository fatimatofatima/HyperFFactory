#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
# HyperFFactory – حالة العمال (Workers) على السيرفر
# ---------------------------------------------------------

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

LOG_FILE="$REPORT_DIR/hf_workers_runtime_status_$(date +%Y%m%d_%H%M%S).log"

SFS_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
RUNTIME_ROOT="/opt/hyper-factory/var/db"
TASK_DB="$RUNTIME_ROOT/tasks/tasks.db"
IDENTITY_DB="$RUNTIME_ROOT/identity/identity.db"

log() {
  echo "[$(date +%F_%T)] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "🚦 HyperFFactory – حالة العمال (Workers) على السيرفر"
log "ROOT : $ROOT"
log "SFS  : $SFS_DB"
log "TASKS: $TASK_DB"
log "IDENT: $IDENTITY_DB"
log "============================================================"

# --------------------------------------------------
# 1) عمال المهام من /opt/hyper-factory/var/db/tasks/tasks.db
# --------------------------------------------------
if [[ -f "$TASK_DB" ]]; then
  log "📁 تم العثور على tasks.db – فحص جداول العمال والمهام..."

  workers_exist="$(sqlite3 "$TASK_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='workers';" 2>/dev/null || true)"
  hb_exist="$(sqlite3 "$TASK_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='worker_heartbeats';" 2>/dev/null || true)"

  if [[ -n "$workers_exist" ]]; then
    log "--------------------------------------------------"
    log "📊 جدول workers في tasks.db"

    log "   • PRAGMA table_info(workers):"
    sqlite3 "$TASK_DB" "PRAGMA table_info('workers');" 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true

    log "   • عدد العمال:"
    sqlite3 "$TASK_DB" "SELECT COUNT(*) FROM workers;" 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true

    log "   • عينة عمال (id, worker_code, entity_id, host, status, max_concurrent_jobs, current_jobs, last_heartbeat):"
    sqlite3 "$TASK_DB" "
      SELECT
        id,
        worker_code,
        entity_id,
        host,
        status,
        max_concurrent_jobs,
        current_jobs,
        last_heartbeat
      FROM workers
      ORDER BY status, worker_code
      LIMIT 20;
    " 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true

    # ربط العمال بالهوية إن وُجدت identity.db
    if [[ -f "$IDENTITY_DB" ]]; then
      log "   • ربط العمال بالهوية (entities.name) من identity.db:"
      sqlite3 "$TASK_DB" "
        ATTACH '$IDENTITY_DB' AS idb;
        SELECT
          w.id,
          w.worker_code,
          w.status,
          COALESCE(e.name, 'N/A') AS entity_name,
          w.host,
          w.max_concurrent_jobs,
          w.current_jobs,
          w.last_heartbeat
        FROM workers w
        LEFT JOIN idb.entities e ON e.id = w.entity_id
        ORDER BY w.status, w.worker_code
        LIMIT 20;
      " 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true
    else
      log "   • ⚪ identity.db غير موجود – لا يمكن ربط العمال بالكيانات."
    fi
  else
    log "⚪ جدول workers غير موجود داخل tasks.db."
  fi

  if [[ -n "$hb_exist" ]]; then
    log "--------------------------------------------------"
    log "📊 جدول worker_heartbeats في tasks.db"

    log "   • عدد نبضات الحياة:"
    sqlite3 "$TASK_DB" "SELECT COUNT(*) FROM worker_heartbeats;" 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true

    log "   • آخر 20 نبضة (worker_id, heartbeat_at, status, load_factor):"
    sqlite3 "$TASK_DB" "
      SELECT
        worker_id,
        heartbeat_at,
        status,
        load_factor
      FROM worker_heartbeats
      ORDER BY heartbeat_at DESC
      LIMIT 20;
    " 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true
  fi
else
  log "⚪ tasks.db غير موجود – طبقة العمال runtime غير مهيأة أو في مسار آخر."
fi

# --------------------------------------------------
# 2) فحص smartfriend_unified.db لأي جداول workers (للتوثيق فقط)
# --------------------------------------------------
if [[ -f "$SFS_DB" ]]; then
  log "--------------------------------------------------"
  log "📁 smartfriend_unified.db موجودة – فحص جداول اسمها يحتوي 'worker'..."

  tables="$(sqlite3 "$SFS_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%worker%';" 2>/dev/null || true)"

  if [[ -z "${tables// }" ]]; then
    log "⚪ لا توجد جداول تحتوي على 'worker' في الاسم داخل smartfriend_unified.db (متوقع – العمال في tasks.db)."
  else
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      log "📊 جدول: $t"
      sqlite3 "$SFS_DB" "PRAGMA table_info('$t');" 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true
      sqlite3 "$SFS_DB" "SELECT COUNT(*) FROM '$t';" 2>/dev/null | sed 's/^/      /' >> "$LOG_FILE" || true
    done <<< "$tables"
  fi
else
  log "⚪ smartfriend_unified.db غير موجودة (حالة غير متوقعة بعد الاستعادة التي تمت)."
fi

# --------------------------------------------------
# 3) فحص systemd عن الخدمات التي تقوم بدور عمال / مدراء
# --------------------------------------------------
log "--------------------------------------------------"
log "🛠️ فحص systemd للوحدات المرتبطة بالعمال/المديرين (worker / smartfriend / sf- / ffactory / deepseek)"

systemctl list-units --type=service --no-pager 2>/dev/null \
  | grep -Ei 'worker|workers|smartfriend|sf-|ffactory|deepseek-api' \
  | sed 's/^/[UNIT] /' >> "$LOG_FILE" \
  || log "⚪ لا توجد وحدات systemd مطابقة للأنماط المحددة."

log "============================================================"
log "✅ تقرير حالة العمال جاهز: $LOG_FILE"
