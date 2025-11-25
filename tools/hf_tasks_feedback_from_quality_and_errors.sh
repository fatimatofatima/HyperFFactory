#!/usr/bin/env bash
# HyperFFactory – Feed hf_tasks.db from hf_errors.db + hf_quality.db
# - READ-ONLY على hf_errors.db / hf_quality.db
# - READ/WRITE فقط على hf_tasks.db
#
# منطق العمل:
# 1) قراءة الحوادث من hf_errors.db (جدول incidents أو errors)
# 2) تحويل كل "نوع حادث per actor" إلى Task (مهمة متابعة)
# 3) ON CONFLICT(actor,scope) DO UPDATE → لا كسر للـ UNIQUE
# 4) محاولة استخدام hf_quality.db إن وُجد جدول checks
# 5) عدم الكسر لو الجداول/الملفات غير موجودة؛ فقط تحذيرات

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"

TASKS_DB="$META_DIR/hf_tasks.db"
ERRORS_DB="$META_DIR/hf_errors.db"
QUALITY_DB="$META_DIR/hf_quality.db"

log() {
  local lvl="$1"; shift
  local msg="$*"
  printf '%s [%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$lvl" "$msg"
}

if [[ ! -f "$TASKS_DB" ]]; then
  log "ERROR" "لم يتم العثور على $TASKS_DB"
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR" "sqlite3 غير مثبت على النظام."
  exit 1
fi

log "INFO" "HyperFFactory – tasks feedback من الأخطاء والجودة"
log "INFO" "TASKS_DB  = $TASKS_DB"
log "INFO" "ERRORS_DB = $ERRORS_DB (إن وُجد)"
log "INFO" "QUALITY_DB= $QUALITY_DB (إن وُجد)"

#----------------------------------------
# Helper: escape quotes للاستخدام داخل SQL
#----------------------------------------
sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

#----------------------------------------
# 1) Feed from hf_errors.db → مهام incident:*
#----------------------------------------
if [[ -f "$ERRORS_DB" ]]; then
  log "INFO" "فحص جداول hf_errors.db ..."

  ERR_TABLE=""
  if sqlite3 "$ERRORS_DB" ".tables" | grep -q '^incidents$'; then
    ERR_TABLE="incidents"
  elif sqlite3 "$ERRORS_DB" ".tables" | grep -q '^errors$'; then
    ERR_TABLE="errors"
  fi

  if [[ -z "$ERR_TABLE" ]]; then
    log "WARN" "لا يوجد جدول incidents أو errors داخل hf_errors.db – تخطّي."
  else
    log "INFO" "استخدام جدول $ERR_TABLE داخل hf_errors.db لتوليد مهام."
    # سحب ملخّص لكل (actor,error_type)
    # نستخدم ts أو created_at حسب المتوفر
    sqlite3 -separator '|' "$ERRORS_DB" "
      SELECT
        IFNULL(actor,'unknown'),
        IFNULL(error_type,'UNKNOWN_TYPE'),
        IFNULL(severity,'LOW'),
        IFNULL(COALESCE(ts, created_at, ''),''),
        IFNULL(source_script,''),
        IFNULL(error_message,'')
      FROM $ERR_TABLE
    " | while IFS='|' read -r actor error_type severity ts source_script error_message; do
        [[ -z "$actor" && -z "$error_type" ]] && continue

        # mapping severity → priority
        prio=10
        case "$severity" in
          LOW) prio=20 ;;
          MEDIUM) prio=50 ;;
          HIGH) prio=80 ;;
          CRITICAL) prio=95 ;;
        esac

        local_actor="$(sql_escape "$actor")"
        local_error_type="$(sql_escape "$error_type")"
        local_ts="$ts"
        [[ -z "$local_ts" ]] && local_ts="$(date '+%Y-%m-%d %H:%M:%S %z')"

        local_source_script="$(sql_escape "$source_script")"
        local_error_message="$(sql_escape "$error_message")"

        scope="incident:${error_type}"
        title="Incident: ${error_type}"
        if [[ -n "$source_script" ]]; then
          title="$title in ${source_script}"
        fi
        local_scope="$(sql_escape "$scope")"
        local_title="$(sql_escape "$title")"
        local_created_at="$(sql_escape "$local_ts")"
        local_updated_at="$(sql_escape "$(date '+%Y-%m-%d %H:%M:%S %z')")"

        # UPSERT آمن على (actor,scope) – لا يكسر UNIQUE
        sqlite3 "$TASKS_DB" "
          INSERT INTO tasks(actor, scope, status, priority, title, created_at, updated_at)
          VALUES (
            '$local_actor',
            '$local_scope',
            'PLANNED',
            $prio,
            '$local_title',
            '$local_created_at',
            '$local_updated_at'
          )
          ON CONFLICT(actor, scope) DO UPDATE SET
            status     = excluded.status,
            priority   = excluded.priority,
            title      = excluded.title,
            updated_at = excluded.updated_at
        " >/dev/null 2>&1 || true
      done

    log "INFO" "تم تغذية المهام من hf_errors.db (incident:*) مع احترام UNIQUE(actor,scope)."
  fi
else
  log "WARN" "hf_errors.db غير موجود – تخطّي جزء الأخطاء."
fi

#----------------------------------------
# 2) Feed from hf_quality.db → مهام quality:*
#----------------------------------------
if [[ -f "$QUALITY_DB" ]]; then
  log "INFO" "فحص جداول hf_quality.db ..."

  if sqlite3 "$QUALITY_DB" ".tables" | grep -q '^checks$'; then
    log "INFO" "استخدام جدول checks داخل hf_quality.db لتوليد مهام الجودة."
    sqlite3 -separator '|' "$QUALITY_DB" "
      SELECT
        IFNULL(actor,'unknown'),
        IFNULL(check_name,'unknown_check'),
        IFNULL(result,'UNKNOWN'),
        IFNULL(score,0),
        IFNULL(ts,'')
      FROM checks
    " | while IFS='|' read -r actor check_name result score ts; do
        [[ -z "$actor" && -z "$check_name" ]] && continue

        local_actor="$(sql_escape "$actor")"
        local_check_name="$(sql_escape "$check_name")"
        local_ts="$ts"
        [[ -z "$local_ts" ]] && local_ts="$(date '+%Y-%m-%d %H:%M:%S %z')"

        # تحويل score (0–100) إلى priority تقريبية
        # 0–39 → 40 (متابعة مهمة)
        # 40–79 → 60
        # 80–100 → 80
        prio=40
        if (( score >= 80 )); then
          prio=80
        elif (( score >= 40 )); then
          prio=60
        fi

        scope="quality:${check_name}"
        title="Quality check: ${check_name} (result=${result}, score=${score})"

        local_scope="$(sql_escape "$scope")"
        local_title="$(sql_escape "$title")"
        local_created_at="$(sql_escape "$local_ts")"
        local_updated_at="$(sql_escape "$(date '+%Y-%m-%d %H:%M:%S %z')")"

        sqlite3 "$TASKS_DB" "
          INSERT INTO tasks(actor, scope, status, priority, title, created_at, updated_at)
          VALUES (
            '$local_actor',
            '$local_scope',
            'PLANNED',
            $prio,
            '$local_title',
            '$local_created_at',
            '$local_updated_at'
          )
          ON CONFLICT(actor, scope) DO UPDATE SET
            status     = excluded.status,
            priority   = excluded.priority,
            title      = excluded.title,
            updated_at = excluded.updated_at
        " >/dev/null 2>&1 || true
      done

    log "INFO" "تم تغذية المهام من hf_quality.db (quality:*) مع احترام UNIQUE(actor,scope)."
  else
    log "WARN" "جدول checks غير موجود داخل hf_quality.db – لا توجد فحوص جودة مسجّلة بعد."
  fi
else
  log "WARN" "hf_quality.db غير موجود – تخطّي جزء الجودة."
fi

#----------------------------------------
# 3) Summary
#----------------------------------------
TOTAL_TASKS="$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo 0)"
log "INFO" "إجمالي المهام الآن داخل hf_tasks.db: ${TOTAL_TASKS}"

log "INFO" "انتهى tasks feedback بنجاح (بدون كسر UNIQUE)."
