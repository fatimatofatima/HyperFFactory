#!/usr/bin/env bash
# HyperFFactory – تهيئة/إكمال قواعد Meta (tasks/quality/errors/learning/changes)
# يلتزم بسياسة:
# - العمل فقط تحت /root/HyperFFactory
# - عدم لمس /opt/*
# - عدم حذف أي DB، فقط إنشاء/تكميل schemas

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
SQL_DIR="$ROOT/sql"
LOG_DIR="$ROOT/logs"

mkdir -p "$DB_DIR" "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_apply_meta_dbs_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

log "============================================================"
log "== HF APPLY META DBS (INIT/COMPLETE)"
log "============================================================"
log "ROOT = $ROOT"
log "DB_DIR = $DB_DIR"
log "SQL_DIR = $SQL_DIR"
log "LOG  = $LOG_FILE"
log "============================================================"

# فحص المسار
if [[ "$(pwd)" != "$ROOT" ]]; then
    log "ℹ️ تغيير المسار إلى $ROOT"
    cd "$ROOT"
fi

# فحص sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
    log "❌ sqlite3 غير متوفر على النظام – خروج."
    exit 1
fi

# قائمة قواعد البيانات والـ SQL المرتبطة (لو موجودة)
DB_ITEMS=(
  "hf_ops_meta_tasks.db|${SQL_DIR}/init_hf_ops_meta_tasks.sql"
  "hf_errors.db|${SQL_DIR}/meta_hf_errors_schema.sql"
  "hf_learning.db|${SQL_DIR}/meta_hf_learning_schema.sql"
  "hf_ops_meta.db|${SQL_DIR}/meta_hf_ops_meta_schema.sql"
  "hf_quality.db|${SQL_DIR}/meta_hf_quality_schema.sql"
  "hf_changes.db|${SQL_DIR}/meta_hf_changes_schema.sql"
)

ensure_db_with_sql() {
    local db_name="$1"
    local sql_file="$2"

    local db_path="${DB_DIR}/${db_name}"

    log "------------------------------------------------------------"
    log "▶ معالجة قاعدة البيانات: ${db_name}"
    log "   المسار: ${db_path}"
    log "   SQL   : ${sql_file}"

    if [[ ! -f "$db_path" ]]; then
        log "ℹ️ قاعدة البيانات غير موجودة – سيتم إنشاؤها الآن."
        sqlite3 "$db_path" "PRAGMA journal_mode=WAL;" >/dev/null 2>&1 || \
            log "⚠️ تحذير: مشكلة أثناء إنشاء DB (قد تكون غير مؤثرة)."
    else
        log "ℹ️ قاعدة البيانات موجودة مسبقاً."
    fi

    if [[ -f "$sql_file" ]]; then
        log "ℹ️ تطبيق سكربت SQL على القاعدة."
        if sqlite3 "$db_path" < "$sql_file" 2>>"$LOG_FILE"; then
            log "✅ تم تطبيق SQL بنجاح على ${db_name}"
        else
            log "⚠️ تحذير: فشل جزئي أثناء تطبيق SQL على ${db_name} (قد تكون الجداول موجودة مسبقا)."
        fi
    else
        log "ℹ️ ملف SQL غير موجود (${sql_file}) – سيتم الاكتفاء بوجود DB فقط."
    fi

    # طباعة الجداول الموجودة (للتوثيق)
    log "ℹ️ الجداول داخل ${db_name}:"
    sqlite3 "$db_path" ".tables" 2>/dev/null | sed 's/^/    /' || \
        log "⚠️ تعذر قراءة الجداول من ${db_name}"
}

for item in "${DB_ITEMS[@]}"; do
    IFS='|' read -r db_name sql_file <<<"$item"
    ensure_db_with_sql "$db_name" "$sql_file"
done

# تسجيل حدث في hf_changes لو الجدول جاهز
CHANGES_DB="${DB_DIR}/hf_changes.db"
if [[ -f "$CHANGES_DB" ]]; then
    log "------------------------------------------------------------"
    log "📌 محاولة تسجيل عملية INIT في hf_changes"
    SQLITE_ERR=0
    sqlite3 "$CHANGES_DB" "INSERT INTO hf_changes
        (ts, actor, change_type, target, details, meta)
        VALUES (
            strftime('%Y-%m-%dT%H:%M:%S','now','localtime'),
            'hf_apply_meta_dbs.sh',
            'INIT',
            'META_DBS',
            'Ensure meta DBs (tasks/quality/errors/learning/ops_meta/changes)',
            '{}'
        );" 2>>"$LOG_FILE" || SQLITE_ERR=$?
    if [[ "$SQLITE_ERR" -eq 0 ]]; then
        log "✅ تم تسجيل عملية INIT في جدول hf_changes."
    else
        log "⚠️ تعذر إدراج سجل في hf_changes (ربما الجدول غير معرف بالكامل)."
    fi
else
    log "ℹ️ hf_changes.db غير موجود بعد (رغم المحاولة أعلاه) – تحقق من اللوج."
fi

log "============================================================"
log "انتهى hf_apply_meta_dbs. راجع اللوج عند الحاجة:"
log "  $LOG_FILE"
log "============================================================"
