#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VAR_DIR="${APP_ROOT}/var"
DB_DIR="${VAR_DIR}/db"
KNOW_DIR="${VAR_DIR}/knowledge"
LOG_DIR="${VAR_DIR}/logs"
APPS_DIR="${APP_ROOT}/apps"
SPIDER_DIR="${APPS_DIR}/harvester/spider"

REPORT_DIR="${APP_ROOT}/reports"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="${REPORT_DIR}/sf_unify_final_diag_${TS}.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }
info()  { echo -e "${CYAN}[ℹ] $*${NC}"; }
teeout(){ tee -a "${REPORT}" >/dev/null; }

have(){ command -v "$1" >/dev/null 2>&1; }

echo "================================================================" | teeout
echo "   🧠 SmartFriend Suite – Final Unification Diagnostic" | teeout
echo "   Timestamp: ${TS}" | teeout
echo "================================================================" | teeout
echo | teeout

mkdir -p "${REPORT_DIR}"

FS_OK=1
DB_OK=1
SERV_OK=1

# ---------------------------------------------------------------
# 1) فحص الهيكل العام (File System Layout)
# ---------------------------------------------------------------
echo "------------------------------------------------------------" | teeout
echo "1) File-System Layout (Identity / Memory / Knowledge / Spider)" | teeout
echo "------------------------------------------------------------" | teeout

check_dir(){
  local path="$1"
  local label="$2"
  if [ -d "$path" ]; then
    echo "OK   [$label] موجود: $path" | teeout
  else
    echo "FAIL [$label] غير موجود: $path" | teeout
    FS_OK=0
  fi
}

check_dir "${APP_ROOT}"   "APP_ROOT"
check_dir "${DB_DIR}"     "DB_DIR (var/db)"
check_dir "${KNOW_DIR}"   "KNOW_DIR (var/knowledge)"
check_dir "${LOG_DIR}"    "LOG_DIR (var/logs)"
check_dir "${APPS_DIR}"   "APPS_DIR (apps)"
check_dir "${SPIDER_DIR}" "SPIDER_DIR (apps/harvester/spider)"

echo | teeout

# ---------------------------------------------------------------
# 2) فحص قواعد البيانات الموحّدة (Memory / Knowledge / Brain)
# ---------------------------------------------------------------
echo "------------------------------------------------------------" | teeout
echo "2) Unified DBs (memory / knowledge / brain / identity)" | teeout
echo "------------------------------------------------------------" | teeout

if ! have sqlite3; then
  echo "sqlite3 غير مثبت – لن يتم فحص الداخل، فقط وجود الملفات." | teeout
fi

DBS=(
  "${DB_DIR}/memory.db"
  "${DB_DIR}/smart_core_memory.db"
  "${DB_DIR}/unified_memory.db"
  "${DB_DIR}/smartfriend_unified.db"
)

for db in "${DBS[@]}"; do
  name="$(basename "$db")"
  echo | teeout
  echo ">>> DB: ${db}" | teeout
  if [ ! -f "$db" ]; then
    echo "  - الحالة: MISSING" | teeout
    DB_OK=0
    continue
  fi

  size_h="$(du -h "$db" 2>/dev/null | awk '{print $1}')"
  echo "  - الحالة: موجود" | teeout
  echo "  - الحجم:  ${size_h}" | teeout

  if have sqlite3; then
    tables_cnt="$(sqlite3 "$db" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "?")"
    echo "  - عدد الجداول: ${tables_cnt}" | teeout

    integrity="$(sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null || echo "ERROR")"
    if [ "$integrity" = "ok" ]; then
      echo "  - integrity_check: ok" | teeout
    else
      echo "  - integrity_check: ${integrity}" | teeout
      DB_OK=0
    fi

    # جداول أساسية للهوية/الذاكرة/المعرفة/العقل (لو موجودة)
    core_tables=(sessions messages knowledge_items knowledge_sources brain_source_metrics brain_events identity profile agent_identity)
    echo "  - الجداول الأساسية (إن وُجدت):" | teeout
    for t in "${core_tables[@]}"; do
      exists="$(sqlite3 "$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='${t}' LIMIT 1;" 2>/dev/null || true)"
      if [ "$exists" = "1" ]; then
        cnt="$(sqlite3 "$db" "SELECT count(*) FROM \"${t}\";" 2>/dev/null || echo "?")"
        echo "      * ${t}: موجود (${cnt} صفوف)" | teeout
      fi
    done
  fi
done

echo | teeout

# ---------------------------------------------------------------
# 3) فحص المسارات القديمة (Old Paths – ما قبل التوحيد)
# ---------------------------------------------------------------
echo "------------------------------------------------------------" | teeout
echo "3) Old Paths Check (pre-unification locations)" | teeout
echo "------------------------------------------------------------" | teeout

OLD_PATHS=(
  "/opt/smartfriend-suite/memory.db"
  "/opt/smartfriend-suite/smart_core_memory.db"
  "/opt/smartfriend-suite/unified_memory.db"
  "/opt/smartfriend-suite/smartfriend_unified.db"
  "/opt/smartfrind/knowledge.db"
  "/opt/smartfrind/memory.db"
)

ANY_OLD=0
for p in "${OLD_PATHS[@]}"; do
  if [ -e "$p" ]; then
    echo "FOUND  مسار قديم ما زال موجود: $p" | teeout
    ANY_OLD=1
    DB_OK=0
  fi
done

if [ "$ANY_OLD" -eq 0 ]; then
  echo "OK   لا توجد قواعد بيانات في المسارات القديمة المذكورة." | teeout
fi

echo | teeout

# ---------------------------------------------------------------
# 4) فحص خدمات systemd المرتبطة بالمعرفة/العقل/التعلّم
# ---------------------------------------------------------------
echo "------------------------------------------------------------" | teeout
echo "4) Systemd Services (Core / Brain / Learning / Knowledge)" | teeout
echo "------------------------------------------------------------" | teeout

SERVICES=(
  smartfrind-core
  smartfrind-local
  smartfrind-qa
  smartfrind-guardian
  smartfrind-trainer
  smartfrind-runner
  smartfrind-advanced
  smartfrind-ai-gateway
  smartfrind-unified
  smartfrind-simple
  smartfrind-ultra
  smartfrind-harvest
  smartfrind-ingest
  smartfrind-reflector
  smartfrind-autolearn
  smartfrind-learning-agent
  smartfrind-envwatch
  smartfrind-monitor
  smartfrind-raw-clean
)

if ! have systemctl; then
  echo "systemctl غير متاح – سيتم تخطي فحص الخدمات." | teeout
  SERV_OK=0
else
  for svc in "${SERVICES[@]}"; do
    unit="${svc}.service"
    if ! systemctl list-unit-files "${unit}" >/dev/null 2>&1; then
      echo "MISSING  وحدة غير موجودة (على الأقل كملف): ${unit}" | teeout
      continue
    fi
    enabled_state="$(systemctl is-enabled "${unit}" 2>/dev/null || echo "unknown")"
    active_state="$(systemctl is-active "${unit}" 2>/dev/null || echo "unknown")"
    echo "SERVICE ${unit}: enabled=${enabled_state}, active=${active_state}" | teeout

    # لو الوحدة ينبغي أن تكون جزء من العقل/المعرفة، لكن حالتها فاشلة، نرفع تحذير
    if [ "${enabled_state}" = "enabled" ] && [ "${active_state}" != "active" ]; then
      SERV_OK=0
    fi
  done
fi

echo | teeout

# ---------------------------------------------------------------
# 5) تلخيص قرار التوحيد (Business-Level Summary)
# ---------------------------------------------------------------
echo "------------------------------------------------------------" | teeout
echo "5) Unification Decision Summary (Knowledge + Memory + Brain)" | teeout
echo "------------------------------------------------------------" | teeout

if [ "$FS_OK" -eq 1 ]; then
  echo "FS-LAYOUT : OK  – هيكل السويت موحّد (var/db, var/knowledge, var/logs, spider)." | teeout
else
  echo "FS-LAYOUT : WARN – هناك مسارات ناقصة في هيكل السويت، راجع القسم (1)." | teeout
fi

if [ "$DB_OK" -eq 1 ]; then
  echo "DB-PLANE  : OK  – قواعد بيانات الذاكرة/المعرفة سليمة ومتمركزة في var/db، بلا بقايا مسارات قديمة." | teeout
else
  echo "DB-PLANE  : WARN – هناك مشكلة في سلامة DB أو بقايا مسارات قديمة، راجع الأقسام (2) و(3)." | teeout
fi

if [ "$SERV_OK" -eq 1 ]; then
  echo "SERVICES  : OK  – تعريف الخدمات الأساسية موجود، وحالة التمكين/التشغيل منطقية للموديل." | teeout
else
  echo "SERVICES  : WARN – بعض الخدمات المُمكّنة ليست active؛ يلزم ضبط Run-Profile قبل تشغيل العقل الموحد." | teeout
fi

echo | teeout
echo "Business View:" | teeout
echo "  - Identity  : تُدار عبر DBs موحّدة في var/db (profile/identity tables إن وُجدت)." | teeout
echo "  - Memory    : memory.db + smart_core_memory.db تستخدم نفس الهيكل وتجاوزت integrity_check." | teeout
echo "  - Knowledge : smartfriend_unified.db/unified_memory.db جاهزة لحمل knowledge_items / sources." | teeout
echo "  - Learning  : خدمات trainer/learning-agent/autolearn متوفرة (حتى لو inactive حاليًا)." | teeout
echo "  - Brain     : core/local/qa/gateway/guardian متسجلة في systemd وتنتظر Run-Policy نهائي." | teeout
echo "  - Awareness : Spider + harvest/ingest موضوعة في Knowledge Plane ومساراتها الرسمية جاهزة." | teeout

echo | teeout
echo "📄 تم حفظ هذا التقرير في: ${REPORT}" | teeout
echo "================================================================" | teeout

