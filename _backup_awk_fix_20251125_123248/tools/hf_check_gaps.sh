#!/usr/bin/env bash
#
# HyperFFactory – Gap Checker
# يفحص النواقص الأساسية:
# 1) تكامل ffactory (وجود docker-compose.* داخل /opt/ffactory/stack)
# 2) سكربتات snapshot/KPI/DB audit
# 3) مهام hf_db_manager داخل hf_tasks.db
# 4) مسار workers
# 5) أي مسارات HyperFFactory/HyperFFactory (ROOT/paths mismatch)

set -euo pipefail

HF_ROOT="/root/HyperFFactory"
META_DIR="$HF_ROOT/db/meta"
TASKS_DB="$META_DIR/hf_tasks.db"

YELLOW="$(tput setaf 3 || true)"
GREEN="$(tput setaf 2 || true)"
RED="$(tput setaf 1 || true)"
BLUE="$(tput setaf 4 || true)"
BOLD="$(tput bold || true)"
RESET="$(tput sgr0 || true)"

header() {
    echo
    echo "${BOLD}${BLUE}========== $* ==========${RESET}"
}

ok()   { echo "  ${GREEN}✔${RESET} $*"; }
warn() { echo "  ${YELLOW}⚠${RESET} $*"; }
err()  { echo "  ${RED}✘${RESET} $*"; }

# 1) فحص تكامل ffactory stack
check_ffactory_stack() {
    header "1) فحص تكامل ffactory تحت /opt/ffactory/stack"

    local ROOT_FF="/opt/ffactory"
    local STACK_DIR="$ROOT_FF/stack"

    if [[ ! -d "$ROOT_FF" ]]; then
        warn "المجلد /opt/ffactory غير موجود – يتم التعامل مع ffactory كـ نظام خارجي (External Mode محتمل)."
        echo "     TODO: حسم وضع ffactory (stack رسمي أو external mode)."
        return 0
    fi

    if [[ ! -d "$STACK_DIR" ]]; then
        warn "المجلد $STACK_DIR غير موجود."
        echo "     TODO: إمّا إنشاء stack رسمي داخل /opt/ffactory/stack أو تعديل سكربتات HyperFFactory للتعامل مع ffactory كـ external."
        return 0
    fi

    local compose_files
    compose_files="$(find "$STACK_DIR" -maxdepth 2 -type f -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' 2>/dev/null || true)"

    if [[ -z "$compose_files" ]]; then
        warn "لا يوجد أي docker-compose.* داخل $STACK_DIR."
        echo "     TODO: تعريف ملفات docker-compose لتعكس الحاويات ffactory/hyper_* الجارية أو إعلان ffactory كـ external."
    else
        ok "تم العثور على ملفات docker-compose في:"
        echo "$compose_files" | sed 's/^/     - /'
    fi
}

# 2) فحص سكربتات snapshot/KPI/DB audit
check_snapshot_scripts() {
    header "2) فحص سكربتات Snapshot/KPI/DB Audit داخل tools/"

    local SCRIPTS=(
        "hf_status_snapshot.sh"
        "hf_kpi_snapshot.sh"
        "hf_db_audit.sh"
    )

    local missing=0
    for s in "${SCRIPTS[@]}"; do
        local path="$HF_ROOT/tools/$s"
        if [[ -x "$path" ]]; then
            ok "$s موجود وقابل للتنفيذ: tools/$s"
        elif [[ -f "$path" ]]; then
            warn "$s موجود لكن ليس قابلًا للتنفيذ (chmod +x ينقص)."
            echo "     TODO: chmod +x tools/$s"
        else
            missing=$((missing + 1))
            warn "$s غير موجود في tools/."
            echo "     TODO: إما إنشاء tools/$s فعليًا أو تعليق استدعائه من الـ Runner/Tasks."
        fi
    done

    if (( missing == 0 )); then
        ok "لا توجد سكربتات Snapshot/KPI/Audit مفقودة وفقًا للأسماء المعروفة."
    fi
}

# 3) فحص مهام hf_db_manager داخل hf_tasks.db
check_db_manager_tasks() {
    header "3) فحص مهام hf_db_manager في hf_tasks.db"

    if [[ ! -f "$TASKS_DB" ]]; then
        warn "ملف المهام غير موجود: $TASKS_DB"
        echo "     TODO: التأكد من أن Stage4/Task System أنشأ hf_tasks.db بشكل صحيح."
        return 0
    fi

    if ! command -v sqlite3 >/dev/null 2>&1; then
        err "sqlite3 غير مثبت – لا يمكن فحص hf_tasks.db."
        echo "     TODO: تثبيت sqlite3 ثم إعادة تشغيل هذا الفحص."
        return 1
    fi

    local count total
    total="$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")"
    count="$(sqlite3 "$TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE actor='hf_db_manager';" 2>/dev/null || echo "0")"

    echo "  إجمالي المهام في hf_tasks.db: $total"
    echo "  عدد مهام hf_db_manager: $count"

    if [[ "$count" == "0" ]]; then
        warn "لا توجد مهام مرتبطة بالـ actor: hf_db_manager."
        echo "     TODO: تعريف مهام مثل scan_meta_dbs / check_integrity_all / rebuild_registry وربطها بالـ DB manager."
    else
        ok "هناك مهام مسجلة لـ hf_db_manager (count=$count)."
    fi
}

# 4) فحص مسار workers وتحذير HyperFFactory/HyperFFactory
check_workers_path() {
    header "4) فحص مسار workers"

    local EXPECTED="$HF_ROOT/workers"
    local DOUBLE="$HF_ROOT/HyperFFactory/workers"

    if [[ -d "$EXPECTED" ]]; then
        ok "مجلد workers موجود: $EXPECTED"
    else
        warn "مجلد workers غير موجود في: $EXPECTED"
        echo "     TODO: إن كان هذا المسار الرسمي، أنشئه: mkdir -p '$EXPECTED'"
    fi

    if [[ -d "$DOUBLE" ]]; then
        warn "تم العثور على مسار مزدوج HyperFFactory/HyperFFactory/workers: $DOUBLE"
        echo "     TODO: مراجعة السكربتات التي تستخدم هذا المسار وتصحيحه إلى $EXPECTED."
    else
        echo "  لم يتم العثور على مسار مزدوج HyperFFactory/HyperFFactory/workers (فقط تحذير نظري من اللوج السابق)."
    fi
}

# 5) فحص مسارات ROOT المزدوجة داخل السكربتات
check_root_misuse() {
    header "5) فحص استخدام HyperFFactory/HyperFFactory داخل tools/ وغيرها"

    local hits
    hits="$(grep -Rsn "HyperFFactory/HyperFFactory" "$HF_ROOT" 2>/dev/null || true)"

    if [[ -z "$hits" ]]; then
        ok "لا يوجد استخدام واضح لمسار HyperFFactory/HyperFFactory داخل المشروع."
        echo "  (أي تحذير سابق كان غالبًا من سكربت قديم أو نسخة سابقة.)"
    else
        warn "تم العثور على أسطر تحتوي على HyperFFactory/HyperFFactory:"
        echo "$hits" | sed 's/^/     /'
        echo "     TODO: تصحيح هذه المسارات إلى HyperFFactory فقط."
    fi
}

# Main
echo "${BOLD}${BLUE}HyperFFactory – Gap Check Report${RESET}"
echo "ROOT  : $HF_ROOT"
echo "META  : $META_DIR"
echo

check_ffactory_stack
check_snapshot_scripts
check_db_manager_tasks
check_workers_path
check_root_misuse

echo
echo "${BOLD}${GREEN}انتهى فحص النواقص.${RESET}"
echo "${YELLOW}راجع بنود TODO أعلاه وحدد ما تريد تنفيذه في الخطوة التالية.${RESET}"
