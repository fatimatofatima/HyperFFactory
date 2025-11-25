#!/usr/bin/env bash
# HyperFFactory – سكربت شامل لإكمال النواقص الأساسية (Meta DBs + Plan Sync + Checks)
# آمن قدر الإمكان:
# - الوضع الافتراضي DRY-RUN (لا يغيّر شيء، فقط يطبع ما سيفعله)
# - مع --apply ينفّذ فعليًا
#
# ما يفعله:
# 1) التأكد أننا داخل /root/HyperFFactory ومستودع Git.
# 2) إنشاء مجلد قواعد بيانات Meta: db/meta/
# 3) إنشاء قواعد بيانات:
#    - hf_ops_meta_tasks.db
#    - hf_errors.db
#    - hf_learning.db
#    - hf_ops_meta.db
#    - hf_quality.db
# 4) تطبيق سكربتات SQL إن وُجدت:
#    - sql/init_hf_ops_meta_tasks.sql
#    - sql/meta_hf_errors_schema.sql
#    - sql/meta_hf_learning_schema.sql
#    - sql/meta_hf_ops_meta_schema.sql
#    - sql/meta_hf_quality_schema.sql
# 5) محاولة مزامنة HF_EXEC_PLAN.tsv إلى المهام عبر tools/hf_sync_plan_to_tasks.py
# 6) فحص وضع ffactory stack (Docker) بشكل قرائي فقط.
# 7) طباعة ملخص نهائي.

set -Eeuo pipefail

#--------------------------- الإعداد العام ---------------------------#

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"
mkdir -p "$DB_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_fix_all_gaps_${TIMESTAMP}.log"

MODE="dry-run"
if [[ "${1:-}" == "--apply" ]]; then
    MODE="apply"
fi

log() {
    printf '%s [%s] %s\n' "$(date -Iseconds)" "$MODE" "$*" | tee -a "$LOG_FILE"
}

SECTION() {
    echo | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
    echo "== $*" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"
}

run_cmd() {
    # تشغّل أمر shell مع احترام وضع DRY-RUN
    local desc="$1"; shift
    local cmd=("$@")
    if [[ "$MODE" == "dry-run" ]]; then
        log "DRY-RUN: $desc → ${cmd[*]}"
    else
        log "EXEC: $desc → ${cmd[*]}"
        if ! "${cmd[@]}"; then
            log "⚠️ فشل الأمر: ${cmd[*]}"
        fi
    fi
}

run_sql() {
    # تشغّل سكربت SQL على قاعدة محددة مع احترام DRY-RUN
    local db_path="$1"
    local sql_file="$2"
    if [[ ! -f "$sql_file" ]]; then
        log "ℹ️ سكربت SQL غير موجود (تخطي): $sql_file"
        return 0
    fi
    if [[ "$MODE" == "dry-run" ]]; then
        log "DRY-RUN: تطبيق $sql_file على $db_path"
    else
        if [[ ! -f "$db_path" ]]; then
            log "ℹ️ إنشاء قاعدة بيانات جديدة: $db_path"
            sqlite3 "$db_path" "PRAGMA journal_mode=WAL;" >/dev/null 2>&1 || true
        fi
        log "EXEC: sqlite3 \"$db_path\" < \"$sql_file\""
        if ! sqlite3 "$db_path" < "$sql_file"; then
            log "⚠️ فشل تطبيق $sql_file على $db_path (غالبًا بعض الجداول موجودة مسبقًا)، متابعة..."
        fi
    fi
}

#--------------------------- 0) فحوصات أولية ---------------------------#

SECTION "0) فحوصات أولية للمسار و Git و sqlite3"

if [[ "$(pwd)" != "$ROOT" ]]; then
    log "⚠️ المسار الحالي $(pwd) مختلف عن $ROOT – سأحاول cd تلقائيًا."
    cd "$ROOT" || { log "❌ تعذّر الدخول إلى $ROOT"; exit 1; }
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "❌ هذا المجلد ليس مستودع Git. أخرج الآن بدون أي تعديل."
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "ℹ️ داخل مستودع Git، الفرع الحالي: $CURRENT_BRANCH"

if ! command -v sqlite3 >/dev/null 2>&1; then
    log "❌ sqlite3 غير مثبت. من فضلك ثبّته ثم أعد تشغيل السكربت."
    exit 1
else
    log "ℹ️ sqlite3 متوفر."
fi

if ! command -v python3 >/dev/null 2>&1; then
    log "⚠️ python3 غير متوفر (لن أستطيع تشغيل سكربتات Python المساندة)."
else
    log "ℹ️ python3 متوفر."
fi

#--------------------------- 1) تعريف قواعد بيانات Meta ---------------------------#

SECTION "1) إعداد قواعد بيانات Meta (hf_*.db)"

declare -a DB_NAMES=(
    "hf_ops_meta_tasks"
    "hf_errors"
    "hf_learning"
    "hf_ops_meta"
    "hf_quality"
)

declare -a DB_SQL_FILES=(
    "sql/init_hf_ops_meta_tasks.sql"
    "sql/meta_hf_errors_schema.sql"
    "sql/meta_hf_learning_schema.sql"
    "sql/meta_hf_ops_meta_schema.sql"
    "sql/meta_hf_quality_schema.sql"
)

for i in "${!DB_NAMES[@]}"; do
    name="${DB_NAMES[$i]}"
    sql_file="$ROOT/${DB_SQL_FILES[$i]}"
    db_path="$DB_DIR/${name}.db"

    log "---- معالجة قاعدة: $name.db ----"
    if [[ -f "$db_path" ]]; then
        log "ℹ️ قاعدة البيانات موجودة بالفعل: $db_path"
    else
        if [[ "$MODE" == "dry-run" ]]; then
            log "DRY-RUN: سيتم إنشاء $db_path (قاعدة جديدة)."
        else
            log "EXEC: إنشاء قاعدة جديدة $db_path مع تفعيل WAL"
            sqlite3 "$db_path" "PRAGMA journal_mode=WAL;" >/dev/null 2>&1 || true
        fi
    fi

    run_sql "$db_path" "$sql_file"

    # عرض الجداول (في وضع التنفيذ فقط)
    if [[ "$MODE" == "apply" && -f "$db_path" ]]; then
        log "📋 الجداول داخل $db_path:"
        sqlite3 "$db_path" ".tables" 2>/dev/null | sed 's/^/    /' || log "⚠️ تعذر قراءة الجداول من $db_path"
    fi
done

#--------------------------- 2) مزامنة خطة HF_EXEC_PLAN إلى المهام ---------------------------#

SECTION "2) مزامنة خطة HF_EXEC_PLAN.tsv إلى جداول المهام (إن أمكن)"

PLAN_FILE="$ROOT/plans/HF_EXEC_PLAN.tsv"
SYNC_PY="$ROOT/tools/hf_sync_plan_to_tasks.py"

if [[ ! -f "$PLAN_FILE" ]]; then
    log "⚠️ ملف الخطة غير موجود: $PLAN_FILE (تخطي مزامنة الخطة)."
else
    log "ℹ️ تم العثور على ملف الخطة: $PLAN_FILE"
fi

if [[ ! -f "$SYNC_PY" ]]; then
    log "⚠️ سكربت المزامنة غير موجود: $SYNC_PY (تخطي هذه الخطوة)."
else
    log "ℹ️ سكربت المزامنة موجود: $SYNC_PY"
fi

if [[ -f "$PLAN_FILE" && -f "$SYNC_PY" && "$MODE" == "apply" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        # لو سكربت المزامنة يحتاج متغيرات بيئة لمسار DB يمكن لاحقًا ضبطها هنا
        # مثال:
        #   export HF_TASKS_DB="$DB_DIR/hf_ops_meta_tasks.db"
        log "EXEC: تشغيل سكربت المزامنة hf_sync_plan_to_tasks.py (بدون معرفة وسيطاته، سيتم استدعاؤه كما هو)."
        if ! python3 "$SYNC_PY"; then
            log "⚠️ فشل تشغيل hf_sync_plan_to_tasks.py – راجع السكربت أو اللوجات لاحقًا."
        else
            log "✅ تم تشغيل hf_sync_plan_to_tasks.py بنجاح (بحسب ما يتيحه السكربت)."
        fi
    else
        log "⚠️ python3 غير متوفر، تعذر تشغيل سكربت المزامنة."
    fi
else
    log "ℹ️ وضع DRY-RUN أو نقص الخطة/السكربت – لن يتم تشغيل المزامنة فعليًا."
    if [[ -f "$PLAN_FILE" && -f "$SYNC_PY" ]]; then
        log "DRY-RUN: عند استخدام --apply سيتم استدعاء: python3 $SYNC_PY"
    fi
fi

#--------------------------- 3) فحص حالة ffactory (Docker) بشكل قرائي ---------------------------#

SECTION "3) فحص حالة ffactory stack (Docker) – قراءة فقط"

CORE_COMPOSE="$ROOT/stack/docker-compose.core.yml"

if [[ -f "$CORE_COMPOSE" ]]; then
    log "ℹ️ تم العثور على stack/docker-compose.core.yml"
else
    log "ℹ️ لم يتم العثور على stack/docker-compose.core.yml – قد يكون ffactory غير موجود داخل هذا الريبو."
fi

if command -v docker >/dev/null 2>&1; then
    if [[ -f "$CORE_COMPOSE" ]]; then
        log "ℹ️ فحص حالة الحاويات باستخدام docker compose (لن يتم تشغيل/إيقاف أي شيء، فقط ps):"
        if [[ "$MODE" == "dry-run" ]]; then
            log "DRY-RUN: docker compose -f stack/docker-compose.core.yml ps"
        else
            docker compose -f "$CORE_COMPOSE" ps || log "⚠️ فشل docker compose ps (تحقق من إعداد Docker/ffactory)."
        fi
    else
        log "ℹ️ Docker متوفر، لكن لا يوجد ملف stack/docker-compose.core.yml داخل هذا المسار."
    fi
else
    log "ℹ️ Docker غير متوفر على النظام أو ليس في PATH – تخطي فحص ffactory."
fi

#--------------------------- 4) ملخص نهائي ---------------------------#

SECTION "4) ملخص التنفيذ والنواقص المتبقية"

log "📂 مسار قواعد بيانات Meta المستخدم: $DB_DIR"
for i in "${!DB_NAMES[@]}"; do
    name="${DB_NAMES[$i]}"
    db_path="$DB_DIR/${name}.db"
    if [[ -f "$db_path" ]]; then
        log "✅ موجود: $db_path"
    else
        log "⚠️ مفقود (لم يُنشأ بسبب DRY-RUN أو مشكلة ما): $db_path"
    fi
done

if [[ -f "$PLAN_FILE" ]]; then
    log "ℹ️ HF_EXEC_PLAN.tsv موجود: $PLAN_FILE"
else
    log "⚠️ HF_EXEC_PLAN.tsv غير موجود – لن يكون هناك مزامنة مهام حتى توفره."
fi

if [[ -f "$SYNC_PY" ]]; then
    log "ℹ️ سكربت المزامنة موجود: $SYNC_PY"
else
    log "⚠️ سكربت المزامنة hf_sync_plan_to_tasks.py غير موجود – ستظل مزامنة الخطة ناقصة."
fi

if command -v docker >/dev/null 2>&1 && [[ -f "$CORE_COMPOSE" ]]; then
    log "ℹ️ ffactory stack موجود ويمكن فحصه (docker compose ps تم التعامل معه أعلاه)."
else
    log "ℹ️ ffactory stack غير مؤكد (إما docker غير موجود أو ملف compose غير موجود)."
fi

echo | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "== انتهى hf_fix_all_gaps.sh في وضع: $MODE" | tee -a "$LOG_FILE"
echo "== ملف التقرير: $LOG_FILE" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

