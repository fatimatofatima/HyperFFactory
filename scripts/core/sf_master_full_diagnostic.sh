#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

#===============================
# SmartFriend – Master Full Diagnostic
# Identity / Memory / Knowledge / Learning / Brain / Awareness
#===============================

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
REPORT="${REPORT_DIR}/sf_master_full_diagnostic_${TS}.txt"

mkdir -p "${REPORT_DIR}"

# توجيه كل المخرجات إلى التقرير + الشاشة
: > "${REPORT}"
exec > >(tee -a "${REPORT}") 2>&1

# ألوان بسيطة (في الشاشة فقط)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
info()  { echo -e "${CYAN}[ℹ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
failm() { echo -e "${RED}[FAIL]${NC} $*"; }

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

add_ok()   { OK_COUNT=$((OK_COUNT+1)); }
add_warn() { WARN_COUNT=$((WARN_COUNT+1)); }
add_fail() { FAIL_COUNT=$((FAIL_COUNT+1)); }

section() {
  echo
  echo "============================================================"
  echo " $1"
  echo "============================================================"
}

line() {
  echo "------------------------------------------------------------"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

#===============================
# 1) نظرة عامة على النظام
#===============================
section "1) System Overview (OS / Resources)"

echo "Timestamp      : ${TS}"
echo "Hostname       : $(hostname 2>/dev/null || echo 'N/A')"
echo "Kernel         : $(uname -sr 2>/dev/null || echo 'N/A')"
echo "Uptime         : $(uptime -p 2>/dev/null || echo 'N/A')"
echo "Load Average   : $(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo 'N/A')"

echo
echo "Disk /:"
df -h / || true

echo
echo "Memory:"
free -h || true

add_ok

#===============================
# 2) هيكل SmartFriend Suite
#===============================
section "2) SmartFriend Suite Layout (Identity/Memory/Knowledge/Awareness)"

check_dir() {
  local path="$1"
  local label="$2"
  if [ -d "$path" ]; then
    echo "OK   [$label] موجود: $path"
    add_ok
  else
    echo "WARN [$label] غير موجود: $path"
    add_warn
  fi
}

check_dir "${APP_ROOT}"    "APP_ROOT"
check_dir "${DB_DIR}"      "DB_DIR (var/db)"
check_dir "${KNOW_DIR}"    "KNOW_DIR (var/knowledge)"
check_dir "${LOG_DIR}"     "LOG_DIR (var/logs)"
check_dir "${APPS_DIR}"    "APPS_DIR (apps)"
check_dir "${SPIDER_DIR}"  "SPIDER_DIR (apps/harvester/spider)"

if [ -f "${LEGACY_DB}" ]; then
  echo "OK   Legacy SmartFrind DB موجودة: ${LEGACY_DB}"
  add_ok
else
  echo "WARN Legacy SmartFrind DB غير موجودة في: ${LEGACY_DB}"
  add_warn
fi

#===============================
# 3) صحة قواعد البيانات الموحدة
#===============================
section "3) Unified DBs Health (Identity / Memory / Knowledge)"

if ! have sqlite3; then
  echo "FAIL sqlite3 غير مثبت – لا يمكن فحص قواعد البيانات"
  add_fail
else
  DB_LIST=(
    "memory.db"
    "smart_core_memory.db"
    "unified_memory.db"
    "smartfriend_unified.db"
  )

  for db_name in "${DB_LIST[@]}"; do
    local_path="${DB_DIR}/${db_name}"
    line
    echo ">>> DB: ${db_name}"
    echo "   المسار : ${local_path}"
    if [ -f "${local_path}" ]; then
      size=$(du -h "${local_path}" 2>/dev/null | awk '{print $1}')
      echo "   الحجم  : ${size}"
      icheck=$(sqlite3 "${local_path}" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
      echo "   integrity_check: ${icheck}"
      if [ "${icheck}" = "ok" ]; then
        add_ok
      else
        add_warn
      fi

      # جداول أساسية إن وُجدت
      for t in sessions messages knowledge_items; do
        exists=$(sqlite3 "${local_path}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${t}';" 2>/dev/null || true)
        if [ -n "${exists}" ]; then
          cnt=$(sqlite3 "${local_path}" "SELECT COUNT(*) FROM ${t};" 2>/dev/null || echo "N/A")
          echo "   * ${t}: موجود (${cnt} صفوف)"
        fi
      done
    else
      echo "   ⚠ القاعدة غير موجودة"
      add_warn
    fi
  done
fi

#===============================
# 4) صحة قاعدة legacy smart_memory.db
#===============================
section "4) Legacy SmartFrind DB (smart_memory.db)"

if [ -f "${LEGACY_DB}" ] && have sqlite3; then
  size=$(du -h "${LEGACY_DB}" 2>/dev/null | awk '{print $1}')
  echo "   المسار : ${LEGACY_DB}"
  echo "   الحجم  : ${size}"
  icheck=$(sqlite3 "${LEGACY_DB}" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
  echo "   integrity_check: ${icheck}"
  if [ "${icheck}" = "ok" ]; then
    add_ok
  else
    add_warn
  fi

  # العدّادات الأساسية
  for t in ai_memory knowledge_base ai_memory_fts user_memory interactions; do
    exists=$(sqlite3 "${LEGACY_DB}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${t}';" 2>/dev/null || true)
    if [ -n "${exists}" ]; then
      cnt=$(sqlite3 "${LEGACY_DB}" "SELECT COUNT(*) FROM ${t};" 2>/dev/null || echo "N/A")
      echo "   * ${t}: ${cnt} سجل"
    fi
  done

  echo
  echo "   اختبارات FTS (بحث نصي سريع):"
  for term in "python" "docker" "machine learning"; do
    cnt=$(sqlite3 "${LEGACY_DB}" "SELECT COUNT(*) FROM ai_memory_fts WHERE ai_response MATCH '${term}';" 2>/dev/null || echo "0")
    echo "   - '${term}': ${cnt} نتيجة"
  done
else
  echo "WARN قاعدة legacy غير متاحة أو sqlite3 غير مثبت"
  add_warn
fi

#===============================
# 5) خدمات systemd (Brain / Learning / Gateways / Awareness)
#===============================
section "5) Systemd Services (Brain / Learning / Gateways / Spider)"

SERVICES=(
  "smartfrind-core.service:Core Brain"
  "smartfrind-local.service:Local Brain"
  "smartfrind-qa.service:QA Brain"
  "smartfrind-guardian.service:Guardian / Safety"
  "smartfrind-trainer.service:Trainer / Learning"
  "smartfrind-runner.service:Runner / Orchestrator"
  "smartfrind-advanced.service:Advanced Brain"
  "smartfrind-ai-gateway.service:AI Gateway"
  "smartfrind-unified.service:Unified Mode"
  "smartfrind-simple.service:Simple Mode"
  "smartfrind-ultra.service:Ultra Mode"
  "smartfrind-harvest.service:Harvest"
  "smartfrind-ingest.service:Ingest"
  "smartfrind-reflector.service:Reflector"
  "smartfrind-autolearn.service:AutoLearn"
  "smartfrind-learning-agent.service:Learning Agent"
  "smartfrind-envwatch.service:Env Watch"
  "smartfrind-monitor.service:Monitor"
  "smartfrind-raw-clean.service:Raw Clean"
  "sf-spider.service:Spider / Awareness"
)

for item in "${SERVICES[@]}"; do
  svc="${item%%:*}"
  label="${item#*:}"
  enabled=$(systemctl is-enabled "${svc}" 2>/dev/null || echo "unknown")
  active=$(systemctl is-active "${svc}" 2>/dev/null || echo "unknown")
  echo "SERVICE ${svc} : enabled=${enabled}  active=${active}  (${label})"
  if [ "${active}" = "active" ]; then
    add_ok
  elif [ "${enabled}" = "enabled" ] && [ "${active}" != "active" ]; then
    echo "   -> WARN: الخدمة مُمكّنة لكن غير نشطة (سياسة التشغيل مطلوبة)."
    add_warn
  else
    # static/disabled نعتبرها تحذير وليس فشل حقيقي
    add_warn
  fi
done

#===============================
# 6) فحص بوابات HTTP الأساسية
#===============================
section "6) HTTP Gateways Health (Core / Unified / Memory / Learning / FFactory)"

if ! have curl; then
  echo "WARN curl غير مثبت – لا يمكن فحص البوابات HTTP"
  add_warn
else
  check_http() {
    local name="$1"
    local url="$2"
    local expected="$3"  # e.g. 200 أو "200,404"
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$url" || echo "000")
    echo "   ${name} => ${url} (HTTP ${code})"
    if [[ ",${expected}," == *",${code},"* ]]; then
      add_ok
    elif [ "${code}" = "000" ]; then
      add_fail
    else
      add_warn
    fi
  }

  echo "Unified Gateway / Docs:"
  check_http "Unified API"  "http://127.0.0.1:8220/docs" "200,404"
  echo
  echo "Memory / Learning Gateways:"
  check_http "Memory API"   "http://127.0.0.1:8214/docs" "200,404"
  check_http "Core API"     "http://127.0.0.1:8211/docs" "200,404"
  check_http "Unified Gateway 8221"  "http://127.0.0.1:8221/docs" "200,404"
  check_http "Learning Gateway 8222" "http://127.0.0.1:8222/docs" "200,404"
  echo
  echo "FFactory Gateway:"
  check_http "FFactory Gateway" "http://127.0.0.1:8170/" "200,301,302,404"
fi

#===============================
# 7) جودة بيانات المعرفة (Distribution / Freshness)
#===============================
section "7) Knowledge Data Quality (Distribution / Freshness)"

if [ -f "${LEGACY_DB}" ] && have sqlite3; then
  echo "إحصائيات عامة:"
  sqlite3 "${LEGACY_DB}" "
    SELECT 'إجمالي السجلات في knowledge_base: ' || COUNT(*) FROM knowledge_base;
    SELECT 'عدد التصنيفات: ' || COUNT(DISTINCT category) FROM knowledge_base;
    SELECT 'أقدم سجل: ' || MIN(created_at) FROM knowledge_base;
    SELECT 'أحدث سجل: ' || MAX(created_at) FROM knowledge_base;
  " 2>/dev/null || true

  echo
  echo "أعلى 10 تصنيفات حسب الحجم:"
  sqlite3 "${LEGACY_DB}" "
    SELECT printf('%-24s|%4d|%5.1f%%',
                  category,
                  COUNT(*),
                  100.0*COUNT(*)/(SELECT COUNT(*) FROM knowledge_base))
    FROM knowledge_base
    GROUP BY category
    ORDER BY COUNT(*) DESC
    LIMIT 10;
  " 2>/dev/null || true

  add_ok
else
  echo "WARN لا يمكن تحليل جودة البيانات (legacy DB غير متاحة أو sqlite3 غير مثبت)"
  add_warn
fi

#===============================
# 8) تلخيص طبقات Identity / Memory / Knowledge / Learning / Brain / Awareness
#===============================
section "8) Business Layers Summary"

echo "Identity  : تُدار عبر قواعد البيانات في ${DB_DIR} + legacy ${LEGACY_DB} (الجداول المرتبطة بالهوية/البروفايل إن وُجدت)."
echo "Memory    : memory.db + smart_core_memory.db + unified_memory.db تعمل كأساس ذاكرة قصيرة/طويلة المدى."
echo "Knowledge : smartfriend_unified.db + knowledge_base داخل smart_memory.db تمثّل طبقة المعرفة القابلة للبحث والتوسّع."
echo "Learning  : خدمات trainer / learning-agent / autolearn / harvest / ingest تقدّم قنوات تعلم من المناهج والمصادر الخارجية."
echo "Brain     : smartfrind-core/local/qa/advanced/ai-gateway + smart_core API تمثّل العقل التنفيذي والتحليلي."
echo "Awareness : Spider الرسمي + FFactory Gateway + مراقبة البوابات تمثّل وعي النظام بالبيئة ومصادر الويب."

#===============================
# 9) القرار النهائي
#===============================
section "9) Final Decision (Readiness / Identity / Unified Brain)"

echo "Metrics:"
echo "   OK   : ${OK_COUNT}"
echo "   WARN : ${WARN_COUNT}"
echo "   FAIL : ${FAIL_COUNT}"

OVERALL="READY_OK"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  OVERALL="NOT_READY"
elif [ "${WARN_COUNT}" -gt 0 ]; then
  OVERALL="READY_WITH_WARNINGS"
else
  OVERALL="READY_OK"
fi

echo
echo "🎯 OVERALL STATE : ${OVERALL}"

case "${OVERALL}" in
  "READY_OK")
    echo " - المنصة متناسقة، يمكن إعلان «تشغيل إنتاجي» مع مراقبة دورية."
    ;;
  "READY_WITH_WARNINGS")
    echo " - البنية سليمة وقابلة للتشغيل الكامل، لكن توجد نقاط تحذير (خدمات غير نشطة أو Health 404) تحتاج ضبط Run-Profile قبل الاعتماد النهائي."
    ;;
  "NOT_READY")
    echo " - توجد أعطال حقيقية (FAIL) يجب إصلاحها قبل الانتقال لأي تكامل عميق بين التعلم/المعرفة/الذاكرة/الوعي/العقل/الهوية."
    ;;
esac

echo
echo "📄 تم حفظ التقرير في:"
echo "   ${REPORT}"
echo "============================================================"
