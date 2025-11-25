#!/usr/bin/env bash
# HyperFFactory – تفعيل قواعد Meta + دفتر تغييرات hf_changes
# الاستخدام:
#   ./tools/hf_apply_meta_and_changes.sh       # تشغيل عادي
#   ./tools/hf_apply_meta_and_changes.sh --dry # فحص فقط بدون أي تعديل

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
SQL_DIR="$ROOT/sql"
LOG_DIR="$ROOT/logs"
mkdir -p "$DB_DIR" "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_apply_meta_and_changes_${STAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

DRY_RUN=0
if [[ "${1:-}" == "--dry" ]]; then
    DRY_RUN=1
fi

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

ensure_db_with_schema() {
    local db_path="$1"
    local sql_path="$2"
    local label="$3"

    if [[ ! -f "$sql_path" ]]; then
        log "⚠️ [$label] ملف SQL غير موجود: $sql_path (تخطي إنشاء/تحديث هذه القاعدة)"
        return
    fi

    if [[ -f "$db_path" ]]; then
        log "ℹ️ [$label] قاعدة موجودة مسبقًا: $db_path"
        if [[ $DRY_RUN -eq 1 ]]; then
            log "   [DRY-RUN] لن أطبق السكيمة، فقط إبلاغ."
        else
            log "   ▶ تطبيق سكيمة $sql_path على القاعدة الحالية"
            sqlite3 "$db_path" < "$sql_path" || \
                log "⚠️ [$label] تحذير: حصل خطأ أثناء تطبيق السكيمة (قد تكون الجداول موجودة مسبقًا)"
        fi
    else
        if [[ $DRY_RUN -eq 1 ]]; then
            log "   [DRY-RUN] سيتم إنشاء القاعدة لاحقًا: $db_path من $sql_path"
        else
            log "▶ [$label] إنشاء قاعدة جديدة: $db_path"
            sqlite3 "$db_path" < "$sql_path"
            log "✅ [$label] تم إنشاء القاعدة وتطبيق السكيمة."
        fi
    fi
}

log "============================================================"
log "== HF APPLY META & CHANGES"
log "============================================================"
log "ROOT = $ROOT"
log "DB   = $DB_DIR"
log "LOG  = $LOG_FILE"
if [[ $DRY_RUN -eq 1 ]]; then
    log "MODE = DRY-RUN (لا يوجد أي تعديل على القواعد)"
else
    log "MODE = APPLY (سيتم إنشاء/تحديث القواعد فعليًا)"
fi
log

if ! command -v sqlite3 >/dev/null 2>&1; then
    log "❌ sqlite3 غير متوفر – لا يمكن تفعيل Meta DBs."
    exit 1
fi

# 1) ضمان إنشاء/تحديث قواعد Meta الأساسية (إن توفرت سكيماتها)
ensure_db_with_schema "$DB_DIR/hf_ops_meta.db"   "$SQL_DIR/meta_hf_ops_meta_schema.sql"   "OPS_META"
ensure_db_with_schema "$DB_DIR/hf_quality.db"    "$SQL_DIR/meta_hf_quality_schema.sql"    "QUALITY"
ensure_db_with_schema "$DB_DIR/hf_learning.db"   "$SQL_DIR/meta_hf_learning_schema.sql"   "LEARNING"
ensure_db_with_schema "$DB_DIR/hf_errors.db"     "$SQL_DIR/meta_hf_errors_schema.sql"     "ERRORS"

# 2) إنشاء/تحديث قاعدة hf_changes
ensure_db_with_schema "$DB_DIR/hf_changes.db"    "$SQL_DIR/meta_hf_changes_schema.sql"    "CHANGES"

# 3) استدعاء hf_run_meta_systems.sh إن وجد
if [[ -x "$ROOT/tools/hf_run_meta_systems.sh" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        log "ℹ️ [DRY-RUN] لن أستدعي hf_run_meta_systems.sh فعليًا."
    else
        log "▶ تشغيل hf_run_meta_systems.sh لتفعيل أنظمة Meta"
        "$ROOT/tools/hf_run_meta_systems.sh"
    fi
else
    log "ℹ️ hf_run_meta_systems.sh غير موجود أو غير قابل للتنفيذ – تخطي."
fi

# 4) تسجيل العملية في hf_changes (لو لسنا في DRY-RUN)
if [[ $DRY_RUN -eq 0 && -f "$DB_DIR/hf_changes.db" ]]; then
    log "▶ تسجيل عملية التفعيل في hf_changes.db"
    sqlite3 "$DB_DIR/hf_changes.db" <<SQL
INSERT INTO hf_changes (ts, actor, change_type, target, details, meta)
VALUES (
    datetime('now'),
    'hf_apply_meta_and_changes.sh',
    'META_INIT',
    'db/meta',
    'تفعيل/تحديث قواعد Meta + أنظمة المهام/الجودة/الأخطاء',
    json_object(
        'log_file', '$LOG_FILE',
        'ops_meta', 'hf_ops_meta.db',
        'quality',  'hf_quality.db',
        'learning', 'hf_learning.db',
        'errors',   'hf_errors.db'
    )
);
SQL
    log "✅ تم تسجيل العملية في hf_changes."
else
    if [[ $DRY_RUN -eq 1 ]]; then
        log "ℹ️ [DRY-RUN] لم يتم كتابة أي صف في hf_changes (متوقع)."
    else
        log "⚠️ لم أجد hf_changes.db بعد، لن أسجّل الصف (تحقق من الأخطاء أعلاه)."
    fi
fi

log
log "============================================================"
log "انتهى HF APPLY META & CHANGES."
log "راجع اللوج: $LOG_FILE"
log "============================================================"
