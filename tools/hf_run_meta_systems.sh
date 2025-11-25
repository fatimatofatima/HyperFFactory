#!/usr/bin/env bash
# تفعيل أنظمة META: tasks / quality / learning / errors داخل HyperFFactory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
SQL_DIR="$ROOT/sql"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR" "$DB_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_run_meta_systems_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

ensure_db_from_sql() {
    local db_path="$1"
    local sql_path="$2"
    local label="$3"

    if [[ ! -f "$sql_path" ]]; then
        log "⚠️ ملف SQL مفقود لـ $label: $sql_path (تخطي)"
        return
    fi

    if [[ -f "$db_path" ]]; then
        log "ℹ️ DB موجودة مسبقًا لـ $label: $db_path (لن يتم حذفها)"
    else
        log "▶ إنشاء DB جديدة لـ $label: $db_path"
        sqlite3 "$db_path" < "$sql_path"
        log "✅ تم إنشاء DB: $db_path من: $sql_path"
    fi
}

run_if_exists() {
    local script="$1"
    if [[ -x "$script" ]]; then
        log "▶ تشغيل: $script"
        "$script"
        log "✅ انتهى بنجاح: $script"
    elif [[ -f "$script" ]]; then
        log "⚠️ موجود لكنه غير قابل للتنفيذ: $script (تخطي)"
    else
        log "ℹ️ غير موجود (تخطي): $script"
    fi
}

log "============================================================"
log "== HF RUN META SYSTEMS (TASKS / QUALITY / LEARNING / ERRORS)"
log "============================================================"
log "ROOT = $ROOT"
log "DB   = $DB_DIR"
log "LOG  = $LOG_FILE"
log

cd "$ROOT"

# 1) إنشاء قواعد بيانات meta من الـ schema SQL (بدون حذف إن وجدت)
ensure_db_from_sql "$DB_DIR/hf_ops_meta.db"   "$SQL_DIR/meta_hf_ops_meta_schema.sql"   "OPS_META"
ensure_db_from_sql "$DB_DIR/hf_quality.db"    "$SQL_DIR/meta_hf_quality_schema.sql"    "QUALITY"
ensure_db_from_sql "$DB_DIR/hf_learning.db"   "$SQL_DIR/meta_hf_learning_schema.sql"   "LEARNING"
ensure_db_from_sql "$DB_DIR/hf_errors.db"     "$SQL_DIR/meta_hf_errors_schema.sql"     "ERRORS"

# 2) تهيئة جدول المهام في hf_ops_meta.db (init_hf_ops_meta_tasks.sql)
if [[ -f "$SQL_DIR/init_hf_ops_meta_tasks.sql" ]]; then
    log "▶ تهيئة/تحديث جدول المهام في hf_ops_meta.db من init_hf_ops_meta_tasks.sql"
    sqlite3 "$DB_DIR/hf_ops_meta.db" < "$SQL_DIR/init_hf_ops_meta_tasks.sql" || \
        log "⚠️ تحذير أثناء تنفيذ init_hf_ops_meta_tasks.sql (راجع لاحقًا)"
else
    log "⚠️ init_hf_ops_meta_tasks.sql غير موجود (تخطي التهيئة التفصيلية للمهام)"
fi

# 3) تشغيل تقارير المهام والجودة والـ workers
log
log "---- تقارير المهام والجودة والـ workers ----"
run_if_exists "$ROOT/tools/hf_tasks_overview.sh"
run_if_exists "$ROOT/tools/hf_quality_report.sh"
run_if_exists "$ROOT/tools/hf_workers_inventory.sh"
run_if_exists "$ROOT/bin/hf_meta_dump_schemas.sh"

log
log "============================================================"
log "انتهى HF RUN META SYSTEMS (بدون حذف أي سجلات قديمة)."
log "راجع اللوج: $LOG_FILE"
log "============================================================"
