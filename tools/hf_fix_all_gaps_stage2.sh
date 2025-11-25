#!/usr/bin/env bash
# HyperFFactory – Stage2: استكمال النواقص على السيرفر (hf_changes + فحص SmartFriend Suite)
#
# خواص:
# - الوضع الافتراضي: DRY-RUN (لا يغيّر شيء، فقط يطبع ما سيفعله).
# - مع --apply: ينفّذ فعليًا (إنشاء DBs + تطبيق SQL + تشغيل تقارير الفحص).
#
# ما يفعله:
# 1) التأكد من المسار /root/HyperFFactory وتهيئة مجلدات db/meta و logs.
# 2) إنشاء/تحديث قواعد Meta التالية (لو ناقصة):
#      - hf_ops_meta_tasks.db   (من Stage1)
#      - hf_errors.db           (من Stage1)
#      - hf_learning.db         (من Stage1)
#      - hf_ops_meta.db         (من Stage1)
#      - hf_quality.db          (من Stage1)
#      - hf_changes.db          (جديد هنا)
#    مع تطبيق SQL:
#      - sql/init_hf_ops_meta_tasks.sql
#      - sql/meta_hf_errors_schema.sql
#      - sql/meta_hf_learning_schema.sql
#      - sql/meta_hf_ops_meta_schema.sql
#      - sql/meta_hf_quality_schema.sql
#      - sql/meta_hf_changes_schema.sql   (جديد)
# 3) استدعاء تقرير SmartFriend Suite Doctor (إن وجد) للقراءة فقط.
# 4) فحص سريع لقواعد SmartFriend الموحدة (smartfriend_unified.db) – قراءة فقط.
# 5) ملخص بالنواقص المتبقية على السيرفر.
#
# ملاحظات أمان:
# - لا يلمس ffactory ولا Docker.
# - لا يقوم بأي systemctl start/stop/restart.
# - كل الأوامر "تعديل" محمية بوضع DRY-RUN.

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"
mkdir -p "$DB_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_fix_all_gaps_stage2_${TIMESTAMP}.log"

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
            log "ℹ️ إنشاء قاعدة بيانات جديدة: $db_path (مع تفعيل WAL)"
            sqlite3 "$db_path" "PRAGMA journal_mode=WAL;" >/dev/null 2>&1 || true
        fi
        log "EXEC: sqlite3 \"$db_path\" < \"$sql_file\""
        if ! sqlite3 "$db_path" < "$sql_file"; then
            log "⚠️ فشل تطبيق $sql_file على $db_path (ربما بعض الجداول موجودة مسبقًا)، متابعة..."
        fi
    fi
}

#--------------------------- 0) فحوصات عامة ---------------------------#

SECTION "0) فحوصات عامة للمسار والأدوات"

if [[ "$(pwd)" != "$ROOT" ]]; then
    log "ℹ️ المسار الحالي $(pwd)، سأنتقل إلى $ROOT"
    cd "$ROOT" || { log "❌ تعذّر الدخول إلى $ROOT"; exit 1; }
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    log "❌ sqlite3 غير مثبت – هذا السكربت يعتمد عليه. أخرج الآن."
    exit 1
else
    log "ℹ️ sqlite3 متوفر."
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    log "ℹ️ داخل مستودع Git (للمعلومة فقط)، الفرع الحالي: $CURRENT_BRANCH"
else
    log "ℹ️ هذا المسار لا يُعامل الآن كـ Git (أو git غير متوفر) – لا مشكلة، سنكمل."
fi

#--------------------------- 1) إعداد قواعد Meta (إضافة hf_changes) ---------------------------#

SECTION "1) إعداد/استكمال قواعد Meta HyperFFactory (مع hf_changes)"

declare -a DB_NAMES=(
    "hf_ops_meta_tasks"
    "hf_errors"
    "hf_learning"
    "hf_ops_meta"
    "hf_quality"
    "hf_changes"          # جديد
)

declare -a DB_SQL_FILES=(
    "sql/init_hf_ops_meta_tasks.sql"
    "sql/meta_hf_errors_schema.sql"
    "sql/meta_hf_learning_schema.sql"
    "sql/meta_hf_ops_meta_schema.sql"
    "sql/meta_hf_quality_schema.sql"
    "sql/meta_hf_changes_schema.sql"    # جديد
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

    if [[ "$MODE" == "apply" && -f "$db_path" ]]; then
        log "📋 الجداول داخل $db_path:"
        sqlite3 "$db_path" ".tables" 2>/dev/null | sed 's/^/    /' || log "⚠️ تعذر قراءة الجداول من $db_path"
    fi
done

#--------------------------- 2) استدعاء SmartFriend Suite Doctor (قراءة فقط) ---------------------------#

SECTION "2) فحص SmartFriend Suite (قراءة فقط – لا تشغيل/إيقاف خدمات)"

DOCTOR_SCRIPT="$ROOT/tools/hf_smartfriend_suite_doctor.sh"

if [[ -x "$DOCTOR_SCRIPT" ]]; then
    log "ℹ️ سيتم تشغيل hf_smartfriend_suite_doctor.sh لإنتاج تقرير تفصيلي عن السيوت."
    if [[ "$MODE" == "dry-run" ]]; then
        log "DRY-RUN: سيُستدعى لاحقًا بالأمر: $DOCTOR_SCRIPT | tee logs/hf_smartfriend_suite_doctor_from_stage2_${TIMESTAMP}.log"
    else
        DOCTOR_LOG="$LOG_DIR/hf_smartfriend_suite_doctor_from_stage2_${TIMESTAMP}.log"
        log "EXEC: $DOCTOR_SCRIPT | tee $DOCTOR_LOG"
        if ! "$DOCTOR_SCRIPT" | tee "$DOCTOR_LOG"; then
            log "⚠️ فشل تشغيل hf_smartfriend_suite_doctor.sh – راجع السكربت أو اللوج."
        fi
    fi
else
    log "ℹ️ سكربت الدكتور غير موجود أو غير قابل للتنفيذ: $DOCTOR_SCRIPT (تخطي هذه الخطوة)."
fi

#--------------------------- 3) فحص قواعد SmartFriend الموحدة (قراءة فقط) ---------------------------#

SECTION "3) فحص قاعدة smartfriend_unified.db (إن وُجدت) – قراءة فقط"

SF_ROOT="/opt/smartfriend-suite"
SF_DB_MAIN="$SF_ROOT/var/db/smartfriend_unified.db"

if [[ -d "$SF_ROOT" ]]; then
    log "ℹ️ تم العثور على /opt/smartfriend-suite"
    if [[ -f "$SF_DB_MAIN" ]]; then
        log "ℹ️ قاعدة smartfriend_unified.db موجودة: $SF_DB_MAIN"
        if [[ "$MODE" == "apply" ]]; then
            log "📋 الجداول داخل smartfriend_unified.db (عرض أسماء فقط):"
            sqlite3 "$SF_DB_MAIN" ".tables" 2>/dev/null | sed 's/^/    /' || log "⚠️ تعذر قراءة الجداول من smartfriend_unified.db"
        else
            log "DRY-RUN: لن أقرأ الجداول، لكن في وضع --apply سيتم استخدام sqlite3 '.tables'"
        fi
    else
        log "⚠️ smartfriend_unified.db غير موجود في $SF_DB_MAIN – هذه فجوة محتملة تحتاج مراجعة يدوية."
    fi
else
    log "ℹ️ مجلد /opt/smartfriend-suite غير موجود – ربما السيوت مرفوعة من مسار آخر أو غير مثبتة."
fi

# ملاحظة مهمة: لا يوجد هنا أي أوامر systemctl start/stop/restart – فقط قراءة من الدكتور إن وُجد.

#--------------------------- 4) ملخص النواقص المتبقية ---------------------------#

SECTION "4) ملخص التنفيذ والنواقص المتبقية على السيرفر"

log "📂 مسار قواعد Meta المستخدم: $DB_DIR"
for i in "${!DB_NAMES[@]}"; do
    name="${DB_NAMES[$i]}"
    db_path="$DB_DIR/${name}.db"
    if [[ -f "$db_path" ]]; then
        log "✅ موجود: $db_path"
    else
        log "⚠️ مفقود (لم يُنشأ بسبب DRY-RUN أو مشكلة ما): $db_path"
    fi
done

# حالة سكربتات SQL
for sqlf in "${DB_SQL_FILES[@]}"; do
    full="$ROOT/$sqlf"
    if [[ -f "$full" ]]; then
        log "ℹ️ موجود سكربت SQL: $full"
    else
        log "⚠️ سكربت SQL مفقود (لن تُطبّق سكيمة كاملة لهذا الـ DB): $full"
    fi
done

# حالة SmartFriend Suite
if [[ -d "$SF_ROOT" ]]; then
    log "ℹ️ SmartFriend Suite موجودة في: $SF_ROOT"
    if [[ -f "$SF_DB_MAIN" ]]; then
        log "ℹ️ smartfriend_unified.db موجودة – التفاصيل في القسم السابق."
    else
        log "⚠️ smartfriend_unified.db مفقودة – يجب مراجعة توحيد قواعد SmartFriend."
    fi
else
    log "ℹ️ لم يتم العثور على /opt/smartfriend-suite – لو السيوت منصوبة في مكان آخر، عدّل السكربت لاحقًا."
fi

echo | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
echo "== انتهى hf_fix_all_gaps_stage2.sh في وضع: $MODE" | tee -a "$LOG_FILE"
echo "== ملف التقرير: $LOG_FILE" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

