#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VAR_DIR="${APP_ROOT}/var"
DB_DIR="${VAR_DIR}/db"
KNOW_DIR="${VAR_DIR}/knowledge"
LOG_DIR="${VAR_DIR}/logs"
REPORT_DIR="${APP_ROOT}/reports"

TS="$(date +%Y%m%d_%H%M%S)"
AUDIT_FILE="${REPORT_DIR}/sf_unified_stack_audit_${TS}.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

ensure_dir() { mkdir -p "$1"; }

# --- ترويسة التقرير ---
init_report() {
  ensure_dir "${REPORT_DIR}"
  {
    echo "SmartFriend Suite - Unified Stack Final Audit"
    echo "Timestamp: ${TS}"
    echo "APP_ROOT=${APP_ROOT}"
    echo
  } > "${AUDIT_FILE}"
}

append() {
  # append line(s) to main audit file
  cat >> "${AUDIT_FILE}"
}

section() {
  local title="$1"
  {
    echo
    echo "============================================================"
    echo "== ${title}"
    echo "============================================================"
  } >> "${AUDIT_FILE}"
}

# --- فحص هيكل المجلدات الأساسي ---
check_layout() {
  section "1) Core Layout (Platform Identity)"

  local paths=(
    "${APP_ROOT}"
    "${APP_ROOT}/apps"
    "${VAR_DIR}"
    "${DB_DIR}"
    "${KNOW_DIR}"
    "${LOG_DIR}"
    "${REPORT_DIR}"
  )

  {
    for p in "${paths[@]}"; do
      if [ -d "${p}" ]; then
        echo "[OK]  DIR exists: ${p}"
      else
        echo "[MISS] DIR missing: ${p}"
      fi
    done
  } >> "${AUDIT_FILE}"
}

# --- فحص قواعد البيانات: وجود + حجم + سلامة + جداول ---
check_dbs() {
  section "2) Databases (Memory / Knowledge / Brain / Unified)"

  if ! command -v sqlite3 >/dev/null 2>&1; then
    {
      echo "[WARN] sqlite3 غير مثبت – لن يتم إجراء فحص PRAGMA integrity_check."
    } >> "${AUDIT_FILE}"
    return 0
  fi

  local known_dbs=(
    "memory.db:Memory Plane"
    "smart_core_memory.db:Memory Plane (Core Sessions)"
    "unified_memory.db:Memory Plane (Unified Sessions)"
    "smartfriend_unified.db:Brain/Unified"
    "knowledge.db:Knowledge Plane"
    "brain.db:Brain Plane"
  )

  {
    echo "DB_DIR = ${DB_DIR}"
    echo
  } >> "${AUDIT_FILE}"

  for entry in "${known_dbs[@]}"; do
    local name="${entry%%:*}"
    local role="${entry#*:}"
    local path="${DB_DIR}/${name}"

    echo "----------------------------------------" >> "${AUDIT_FILE}"
    echo "DB: ${name}  [Role: ${role}]" >> "${AUDIT_FILE}"

    if [ ! -f "${path}" ]; then
      echo "  [MISS] Not found: ${path}" >> "${AUDIT_FILE}"
      continue
    fi

    local size
    size=$(stat -c '%s' "${path}" 2>/dev/null || echo "N/A")
    echo "  Path : ${path}" >> "${AUDIT_FILE}"
    echo "  Size : ${size} bytes" >> "${AUDIT_FILE}"

    # سلامة القاعدة
    local integrity
    integrity=$(sqlite3 "${path}" "PRAGMA integrity_check;" 2>&1 || true)
    echo "  Integrity: ${integrity}" >> "${AUDIT_FILE}"

    # أول مجموعة جداول (مختصرة فقط)
    {
      echo "  Tables (first 20):"
      sqlite3 "${path}" ".tables" 2>/dev/null | awk '{for(i=1;i<=NF;i++)print "    - "$i}' | head -n 20
    } >> "${AUDIT_FILE}"
  done

  # أي ملفات DB أخرى في DB_DIR
  {
    echo
    echo "== Extra DB files under ${DB_DIR} =="
    find "${DB_DIR}" -maxdepth 1 -type f -name '*.db' -printf "  - %f (%s bytes)\n" | sort || true
  } >> "${AUDIT_FILE}"
}

# --- فحص قواعد بيانات شاردة خارج var/db ---
check_stray_dbs() {
  section "3) Stray DB Paths (should NOT be used after unification)"

  {
    echo "Searching under /opt for memory/knowledge DB files خارج ${DB_DIR}:"
    echo
  } >> "${AUDIT_FILE}"

  find /opt -maxdepth 6 \
    \( -name 'memory.db' -o -name 'smart_core_memory.db' -o -name 'unified_memory.db' -o -name 'smartfriend_unified.db' -o -name 'knowledge.db' -o -name 'brain.db' \) \
    -not -path "${DB_DIR}/*" -print 2>/dev/null >> "${AUDIT_FILE}" || true
}

# --- فحص إشارات لمسارات قديمة (smartfrind / smartfriend القديمة) ---
check_old_paths_refs() {
  section "4) Old Path References (must be cleaned gradually)"

  local patterns=(
    "/opt/smartfriend-suite/memory.db"
    "/opt/smartfriend-suite/smart_core_memory.db"
    "/opt/smartfriend-suite/unified_memory.db"
    "/opt/smartfriend-suite/smartfriend_unified.db"
    "/opt/smartfrind/knowledge.db"
    "/opt/smartfrind/memory.db"
    "/opt/smartfrind/"
    "/opt/smartfriend/"
  )

  {
    echo "البحث في:"
    echo "  - /etc/systemd/system"
    echo "  - ${APP_ROOT}"
    echo "  - /opt/smartfrind (إن وُجد)"
    echo
  } >> "${AUDIT_FILE}"

  for pat in "${patterns[@]}"; do
    echo "------------------------------" >> "${AUDIT_FILE}"
    echo "Pattern: ${pat}" >> "${AUDIT_FILE}"
    local matches
    matches=$(grep -R --line-number --fixed-strings "${pat}" /etc/systemd/system "${APP_ROOT}" /opt/smartfrind 2>/dev/null || true)
    if [ -n "${matches}" ]; then
      echo "${matches}" >> "${AUDIT_FILE}"
    else
      echo "(no matches)" >> "${AUDIT_FILE}"
    fi
    echo >> "${AUDIT_FILE}"
  done
}

# --- فحص وحدات systemd وتصنيفها حسب الطبقة (Memory/Knowledge/Learning/Brain/Gateway) ---
check_systemd_units() {
  section "5) Systemd Units – Classification by Layer (Identity / Brain / Memory / Knowledge / Gateway)"

  {
    echo "Scanning /etc/systemd/system for sf- / smartfriend / smartfrind units..."
    echo
  } >> "${AUDIT_FILE}"

  local unit_files
  unit_files=$(ls /etc/systemd/system/*.service 2>/dev/null | grep -E 'sf-|smartfriend|smartfrind' || true)

  if [ -z "${unit_files}" ]; then
    echo "[INFO] No sf-/smartfriend-/smartfrind-related unit files detected." >> "${AUDIT_FILE}"
    return 0
  fi

  {
    printf "%-40s %-12s %-12s %-12s %-30s\n" "UNIT" "Layer" "Active" "UnitFile" "ExecStart/WD (short)"
    printf "%-40s %-12s %-12s %-12s %-30s\n" "----" "-----" "------" "--------" "------------------"
  } >> "${AUDIT_FILE}"

  while IFS= read -r path; do
    [ -z "${path}" ] && continue
    local unit
    unit=$(basename "${path}")

    # تصنيف الطبقة
    local layer="Other"
    case "${unit}" in
      *memory*|sf-memory.service|smart_core_memory*|*unified_memory* )
        layer="Memory"
        ;;
      *kb*|*ingest*|*harvest*|*spider* )
        layer="Knowledge"
        ;;
      *learn*|*trainer*|*learning* )
        layer="Learning"
        ;;
      *guardian*|*monitor*|*health*|*smoke*|*watchdog*|*audit* )
        layer="Brain"
        ;;
      sf-unified.service|*gateway*|*api*|*web*|*telegram*|*bot*|*smartfactory* )
        layer="Gateway"
        ;;
    esac

    # حالة الخدمة
    local active_state="unknown"
    local sub_state="unknown"
    local unit_state="unknown"

    if command -v systemctl >/dev/null 2>&1; then
      active_state=$(systemctl show -p ActiveState --value "${unit}" 2>/dev/null || echo "n/a")
      sub_state=$(systemctl show -p SubState --value "${unit}" 2>/dev/null || echo "n/a")
      unit_state=$(systemctl show -p UnitFileState --value "${unit}" 2>/dev/null || echo "n/a")
    fi

    # ExecStart / WorkingDirectory (مختصر)
    local exec_line wd_line short_exec short_wd
    exec_line=$(grep -E '^ExecStart=' "${path}" 2>/dev/null | head -n 1 || true)
    wd_line=$(grep -E '^WorkingDirectory=' "${path}" 2>/dev/null | head -n 1 || true)
    short_exec="${exec_line#ExecStart=}"
    short_wd="${wd_line#WorkingDirectory=}"
    [ ${#short_exec} -gt 28 ] && short_exec="${short_exec:0:27}…"
    [ ${#short_wd} -gt 28 ] && short_wd="${short_wd:0:27}…"

    printf "%-40s %-12s %-12s %-12s %-30s\n" \
      "${unit}" \
      "${layer}" \
      "${active_state}/${sub_state}" \
      "${unit_state}" \
      "${short_exec:-${short_wd:-'-'}}" >> "${AUDIT_FILE}"

  done <<< "${unit_files}"
}

# --- تلخيص طبقات الهوية (منظور Business عالي) ---
summary_identity() {
  section "6) High-Level Identity Summary (Business View)"

  {
    echo "هذا الملخص لا يغيّر أي شيء، فقط يصف وضع المنصة حاليًا اعتمادًا على الفحص:"
    echo
    echo "- Platform Root: ${APP_ROOT}"
    echo "- Databases dir: ${DB_DIR}"
    echo "- Knowledge dir: ${KNOW_DIR}"
    echo "- Logs dir     : ${LOG_DIR}"
    echo
    echo "• Memory Plane:"
    echo "  - memory.db, smart_core_memory.db, unified_memory.db (إن كانت موجودة وسليمة)."
    echo
    echo "• Knowledge Plane:"
    echo "  - knowledge.db (إن وجدت) + raw_spider تحت var/knowledge/ (لو سبايدر مفعّل)."
    echo
    echo "• Learning Plane:"
    echo "  - وحدات systemd التي تحتوي learn/trainer/learning، تم تصنيفها في قسم (5)."
    echo
    echo "• Brain / Awareness Plane:"
    echo "  - guardian / monitor / health / smoke / watchdog / audit – تم تصنيفها في قسم (5)."
    echo
    echo "• Gateway / Channels Plane:"
    echo "  - sf-unified / gateways / bots / web / telegram – تم تصنيفها في قسم (5)."
    echo
    echo "الخطوة التالية بعد هذا التقرير (يدويًا):"
    echo "  1) التأكد أن كل الخدمات المهمة تشير لمسارات DB الجديدة فقط تحت var/db."
    echo "  2) تنظيف أي إشارات باقية لـ /opt/smartfrind أو قواعد بيانات قديمة."
    echo "  3) تثبيت خريطة رسمية: أي خدمة = تنتمي لأي Layer وTier."
  } >> "${AUDIT_FILE}"
}

main() {
  echo "================================================================"
  echo "   🧠 SmartFriend Suite – Unified Stack Final Audit"
  echo "   Timestamp: ${TS}"
  echo "================================================================"
  echo

  ensure_dir "${REPORT_DIR}"
  init_report

  log "1) فحص هيكل المجلدات الأساسية"
  check_layout

  log "2) فحص قواعد البيانات تحت var/db (سلامة وهوية)"
  check_dbs

  log "3) البحث عن قواعد بيانات شاردة خارج var/db"
  check_stray_dbs

  log "4) فحص الإشارات لمسارات قديمة (smartfrind / smartfriend القديمة)"
  check_old_paths_refs

  log "5) تحليل وحدات systemd وتصنيفها حسب الطبقة"
  check_systemd_units

  log "6) كتابة ملخص الهوية والتوحيد"
  summary_identity

  echo
  echo "✅ تم إنشاء تقرير الفحص النهائي:"
  echo "   ${AUDIT_FILE}"
  echo "================================================================"
}

main "$@"
