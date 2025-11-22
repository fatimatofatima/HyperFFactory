#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# =========================
# SmartFriend – Final Identity Decision Check
# =========================

APP_ROOT="/opt/smartfriend-suite"
VAR_DIR="${APP_ROOT}/var"
DB_DIR="${VAR_DIR}/db"
KNOW_DIR="${VAR_DIR}/knowledge"
LOG_DIR="${VAR_DIR}/logs"
APPS_DIR="${APP_ROOT}/apps"
SPIDER_DIR="${APPS_DIR}/harvester/spider"

LEGACY_DB="/var/lib/smartfrind/smart_memory.db"

REPORT_DIR="${APP_ROOT}/reports"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="${REPORT_DIR}/sf_final_identity_decision_${TS}.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }
info()  { echo -e "${CYAN}[ℹ] $*${NC}"; }

declare -i OK_COUNT=0
declare -i WARN_COUNT=0
declare -i FAIL_COUNT=0

pass() { echo "   ✅ $*"; OK_COUNT+=1; }
pwarn() { echo "   ⚠️  $*"; WARN_COUNT+=1; }
pfail() { echo "   ❌ $*"; FAIL_COUNT+=1; }

mkdir -p "${REPORT_DIR}"

# توجيه المخرجات إلى التقرير + الشاشة
exec > >(tee -a "${REPORT}") 2>&1

echo "================================================================"
echo "   🧠 SmartFriend – Final Identity / Memory / Knowledge Decision"
echo "   Timestamp: ${TS}"
echo "================================================================"
echo

# -------------------------------------------------
# 1) فحص هيكل الملفات (هوية المنصة)
# -------------------------------------------------
echo "1) File-System Layout (Identity / Memory / Knowledge / Awareness)"
echo "------------------------------------------------------------"

[ -d "${APP_ROOT}" ] && pass "APP_ROOT موجود: ${APP_ROOT}" || pfail "APP_ROOT غير موجود: ${APP_ROOT}"
[ -d "${DB_DIR}" ] && pass "DB_DIR (var/db) موجود: ${DB_DIR}" || pfail "DB_DIR غير موجود: ${DB_DIR}"
[ -d "${KNOW_DIR}" ] && pass "KNOW_DIR (var/knowledge) موجود: ${KNOW_DIR}" || pwarn "KNOW_DIR غير موجود: ${KNOW_DIR}"
[ -d "${LOG_DIR}" ] && pass "LOG_DIR (var/logs) موجود: ${LOG_DIR}" || pwarn "LOG_DIR غير موجود: ${LOG_DIR}"
[ -d "${APPS_DIR}" ] && pass "APPS_DIR (apps) موجود: ${APPS_DIR}" || pwarn "APPS_DIR غير موجود: ${APPS_DIR}"
[ -d "${SPIDER_DIR}" ] && pass "SPIDER_DIR (apps/harvester/spider) موجود: ${SPIDER_DIR}" || pwarn "SPIDER_DIR غير موجود: ${SPIDER_DIR}"

if [ -f "${LEGACY_DB}" ]; then
  pass "Legacy SmartFrind DB موجودة: ${LEGACY_DB}"
else
  pwarn "Legacy SmartFrind DB غير موجودة (اختياري): ${LEGACY_DB}"
fi

echo

# -------------------------------------------------
# 2) فحص قواعد البيانات (Memory / Knowledge / Brain / Identity)
# -------------------------------------------------
echo "2) Unified DBs Health (memory / unified / legacy)"
echo "------------------------------------------------------------"

check_sqlite_suite() {
  local label="$1"
  local path="$2"

  echo ">>> DB: ${label}"
  if [ ! -f "${path}" ]; then
    pwarn "DB غير موجودة: ${path}"
    echo
    return
  fi

  local size
  size=$(du -h "${path}" | awk '{print $1}')
  echo "   المسار : ${path}"
  echo "   الحجم  : ${size}"

  local ic
  ic=$(sqlite3 "${path}" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
  if [ "${ic}" = "ok" ]; then
    pass "integrity_check: ok"
  else
    pfail "integrity_check: ${ic}"
  fi

  # جداول قياسية لو موجودة
  sqlite3 "${path}" "
    SELECT '   sessions='||COUNT(*) FROM sessions;
    SELECT '   messages='||COUNT(*) FROM messages;
    SELECT '   knowledge_items='||COUNT(*) FROM knowledge_items;
  " 2>/dev/null || pwarn "لا يمكن قراءة الجداول القياسية (sessions/messages/knowledge_items) من ${label}"

  echo
}

check_sqlite_legacy() {
  local label="$1"
  local path="$2"

  echo ">>> LEGACY DB: ${label}"
  if [ ! -f "${path}" ]; then
    pwarn "Legacy DB غير موجودة: ${path}"
    echo
    return
  fi

  local size
  size=$(du -h "${path}" | awk '{print $1}')
  echo "   المسار : ${path}"
  echo "   الحجم  : ${size}"

  local ic
  ic=$(sqlite3 "${path}" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
  if [ "${ic}" = "ok" ]; then
    pass "integrity_check: ok"
  else
    pfail "integrity_check: ${ic}"
  fi

  sqlite3 "${path}" "
    SELECT '   ai_memory='||COUNT(*) FROM ai_memory;
    SELECT '   knowledge_base='||COUNT(*) FROM knowledge_base;
    SELECT '   ai_memory_fts='||COUNT(*) FROM ai_memory_fts;
  " 2>/dev/null || pwarn "لا يمكن قراءة جداول legacy (ai_memory / knowledge_base / ai_memory_fts)"

  echo
}

check_sqlite_suite "memory.db"              "${DB_DIR}/memory.db"
check_sqlite_suite "smart_core_memory.db"    "${DB_DIR}/smart_core_memory.db"
check_sqlite_suite "unified_memory.db"       "${DB_DIR}/unified_memory.db"
check_sqlite_suite "smartfriend_unified.db"  "${DB_DIR}/smartfriend_unified.db"

check_sqlite_legacy "smart_memory.db (legacy)" "${LEGACY_DB}"

echo

# -------------------------------------------------
# 3) فحص الخدمات (Brain / Learning / Gateways / Awareness)
# -------------------------------------------------
echo "3) Systemd Services (Brain / Learning / Gateways / Spider)"
echo "------------------------------------------------------------"

check_service() {
  local unit="$1"
  local desc="$2"
  local enabled active

  enabled="$(systemctl is-enabled "${unit}" 2>/dev/null || echo unknown)"
  active="$(systemctl is-active "${unit}" 2>/dev/null || echo unknown)"

  printf "SERVICE %-30s: enabled=%-8s active=%-8s  (%s)\n" "${unit}" "${enabled}" "${active}" "${desc}"

  if [ "${active}" = "active" ]; then
    pass "الخدمة ${unit} (${desc}) تعمل."
  elif [ "${enabled}" = "enabled" ] && [ "${active}" != "active" ]; then
    pwarn "الخدمة ${unit} (${desc}) مُمكّنة لكن غير نشطة."
  else
    pwarn "الخدمة ${unit} (${desc}) غير نشطة (أو غير مُمكّنة) – حسب سياسة التشغيل."
  fi
}

# طبقة العقل والبوابات (SmartFrind legacy)
check_service "smartfrind-core.service"          "Core Brain"
check_service "smartfrind-local.service"         "Local Brain"
check_service "smartfrind-qa.service"            "QA Brain"
check_service "smartfrind-guardian.service"      "Guardian / Safety"
check_service "smartfrind-trainer.service"       "Trainer / Learning"
check_service "smartfrind-runner.service"        "Runner / Orchestrator"
check_service "smartfrind-advanced.service"      "Advanced Brain"
check_service "smartfrind-ai-gateway.service"    "AI Gateway"

# طبقة التعلم / الإدخال
check_service "smartfrind-harvest.service"       "Harvest"
check_service "smartfrind-ingest.service"        "Ingest"
check_service "smartfrind-reflector.service"     "Reflector"
check_service "smartfrind-autolearn.service"     "AutoLearn"
check_service "smartfrind-learning-agent.service" "Learning Agent"
check_service "smartfrind-envwatch.service"      "Env Watch"
check_service "smartfrind-monitor.service"       "Monitor"
check_service "smartfrind-raw-clean.service"     "Raw Clean"

# Spider الرسمي
check_service "sf-spider.service"                "Spider / Awareness"
echo

# -------------------------------------------------
# 4) فحص البوابات HTTP (Unified / Learning / Core)
# -------------------------------------------------
echo "4) HTTP Gateways Health (Identity API / Learning API / Core)"
echo "------------------------------------------------------------"

check_http() {
  local name="$1"
  local url="$2"
  if ! command -v curl >/dev/null 2>&1; then
    pwarn "curl غير مثبت – لا يمكن فحص ${name} (${url})"
    return
  fi
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "${url}" || echo "000")"
  if [ "${code}" = "200" ] || [ "${code}" = "307" ] || [ "${code}" = "302" ]; then
    pass "${name} OK (HTTP ${code}) - ${url}"
  elif [ "${code}" = "404" ]; then
    pwarn "${name} يعمل لكن مسار health/docs يرجع 404 (HTTP 404) - ${url}"
  else
    pfail "${name} غير سليم أو لا يستجيب (HTTP ${code}) - ${url}"
  fi
}

check_http "Unified Gateway"  "http://127.0.0.1:8221/docs"
check_http "Learning Gateway" "http://127.0.0.1:8222/docs"
check_http "Smart Core API"   "http://127.0.0.1:8211/docs"
check_http "Unified API"      "http://127.0.0.1:8220/docs"
check_http "Memory API"       "http://127.0.0.1:8214/docs"
check_http "FFactory Gateway" "http://127.0.0.1:8170/"

echo

# -------------------------------------------------
# 5) قرار التوحيد النهائي (Business View)
# -------------------------------------------------
echo "5) Final Unification Decision (Business View)"
echo "------------------------------------------------------------"

echo "Metrics:"
echo "   OK     : ${OK_COUNT}"
echo "   WARN   : ${WARN_COUNT}"
echo "   FAIL   : ${FAIL_COUNT}"
echo

READY_STATE=""
if [ "${FAIL_COUNT}" -eq 0 ] && [ "${WARN_COUNT}" -eq 0 ]; then
  READY_STATE="READY"
elif [ "${FAIL_COUNT}" -eq 0 ] && [ "${WARN_COUNT}" -gt 0 ]; then
  READY_STATE="READY_WITH_WARNINGS"
else
  READY_STATE="NOT_READY"
fi

case "${READY_STATE}" in
  READY)
    echo "🎯 OVERALL STATE : READY"
    echo "   - يمكن اعتماد قرار: توحيد ودمج (المعرفة + الذاكرة + التعلم + العقل + الوعي + الهوية) في وضع تشغيل فعلي."
    ;;
  READY_WITH_WARNINGS)
    echo "🎯 OVERALL STATE : READY_WITH_WARNINGS"
    echo "   - البنية سليمة وقواعد البيانات والبوابات الأساسية في حالة جيدة."
    echo "   - توجد تحذيرات في بعض الخدمات (systemd) أو نقاط Health، لكن لا تمنع التشغيل."
    echo "   - يوصى بمراجعة التحذيرات قبل إعلان «تشغيل إنتاجي كامل»."
    ;;
  *)
    echo "⛔ OVERALL STATE : NOT_READY"
    echo "   - توجد أعطال (FAIL) في بعض الطبقات (خدمات/بوابات/قواعد بيانات)."
    echo "   - لا يوصى باعتبار العقل الموحد «جاهزًا بالكامل» قبل إصلاح عناصر الفشل."
    ;;
esac

echo
echo "Business Layers View:"
echo "----------------------"
echo "  • Identity  : تُدار عبر قواعد البيانات الموحدة في var/db + legacy smart_memory.db (ملفات الهوية/البروفايل إن وُجدت)."
echo "  • Memory    : memory.db + smart_core_memory.db + unified_memory.db تم فحصها بـ integrity_check، وتعمل كأساس ذاكرة قصيرة/طويلة المدى."
echo "  • Knowledge : smartfriend_unified.db + knowledge_base (داخل smart_memory.db) تمثل طبقة المعرفة، وجاهزة للبحث والتغذية."
echo "  • Learning  : خدمات trainer / learning-agent / autolearn / harvest / ingest متوفرة كقنوات تعلم من المناهج والمصادر الخارجية."
echo "  • Brain     : smartfrind-core/local/qa/advanced/ai-gateway + smart_core API تمثّل طبقة العقل والتنفيذ، وتحتاج Run-Profile نهائي لتفعيل ما يلزم."
echo "  • Awareness : Spider الرسمي + بوابة FFactory + مراقبة الخدمات تمثّل وعي النظام بالبيئة الخارجية ومصادر الويب."

echo
echo "📄 تم حفظ تقرير القرار النهائي في:"
echo "   ${REPORT}"
echo "================================================================"
