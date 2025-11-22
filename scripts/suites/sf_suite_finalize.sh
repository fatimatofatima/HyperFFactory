#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
REPORT_DIR="${APP_ROOT}/reports/integration"
LOG_FILE="/var/log/sf_suite_finalize_$(date +%Y%m%d_%H%M%S).log"

log(){ echo "[$(date +'%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
die(){ echo "[ERR] $*" | tee -a "$LOG_FILE" >&2; exit 1; }

main() {
  [[ -d "$APP_ROOT" ]] || die "APP_ROOT غير موجود: $APP_ROOT"

  mkdir -p "$REPORT_DIR"
  mkdir -p "$(dirname "$LOG_FILE")"

  log "بدء sf_suite_finalize.sh للتثبيت النهائي لـ smartfriend-suite..."

  local INTEGRATION="$APP_ROOT/smart_core_integration_suite.sh"

  if [[ -f "$INTEGRATION" ]]; then
    local backup="${REPORT_DIR}/smart_core_integration_suite_$(date +%Y%m%d_%H%M%S).bak.sh"
    cp "$INTEGRATION" "$backup"
    log "تم أخذ نسخة احتياطية من السكربت القديم: $backup"
  fi

  log "إعادة إنشاء smart_core_integration_suite.sh بنسخة منسقة..."

  cat > "$INTEGRATION" << 'EOSUITE'
#!/bin/bash
set -Eeuo pipefail

APP_ROOT="/opt/smartfriend-suite"
REPORT_DIR="${APP_ROOT}/reports/integration"
LOG_FILE="/tmp/smart_core_integration_$(date +%Y%m%d_%H%M%S).log"
CONFIG_FILE="${APP_ROOT}/ENV/identity.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log(){ echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
err(){ echo -e "${RED}[ERR]${NC} $1" | tee -a "$LOG_FILE" >&2; }

ensure_dirs(){
  mkdir -p "$REPORT_DIR"
}

check_service_port(){
  local name="$1" port="$2"
  if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
    log "✅ ${name} (port ${port})"
    return 0
  else
    warn "❌ ${name} (port ${port}) غير نشط"
    return 1
  fi
}

check_python_pkg(){
  local pkg="$1"
  if python3 - <<PY 2>/dev/null
import importlib
importlib.import_module("${pkg}")
PY
  then
    log "✅ Python package '${pkg}' مثبت"
    return 0
  else
    warn "❌ Python package '${pkg}' غير مثبت"
    return 1
  fi
}

check_system_basic(){
  log "🔍 فحص النظام الأساسي..."
  local cores mem disk load
  cores="$(grep -c ^processor /proc/cpuinfo || echo '?')"
  mem="$(free -h | awk '/Mem:/ {print $2}')"
  disk="$(df -h / | awk 'NR==2{print $4" free / "$2" total"}')"
  load="$(cut -d ' ' -f1-3 /proc/loadavg)"
  log "• المعالج: ${cores} cores"
  log "• الذاكرة: ${mem}"
  log "• التخزين: ${disk}"
  log "• الحمل: ${load}"
}

check_services(){
  log "🌐 فحص الخدمات والشبكات..."
  check_service_port "Ollama" 11434 || true
  check_service_port "FFactory Main" 8000 || true
  check_service_port "Smart Core" 8211 || true
  check_service_port "Memory API" 8214 || true
  check_service_port "FFactory Gateway" 8170 || true
  check_service_port "Unified API" 8220 || true
  check_service_port "PostgreSQL" 5432 || true
}

check_smart_core_health(){
  log "🤖 فحص صحة Smart Core..."
  local root health ask
  root="$(curl -s http://127.0.0.1:8211/ || true)"
  if [[ -n "$root" ]]; then
    log "✅ GET / - الخدمة تعمل"
    log "  📊 ${root}"
  else
    warn "❌ GET / فشل"
  fi

  health="$(curl -s http://127.0.0.1:8211/health || true)"
  if [[ -n "$health" ]]; then
    log "✅ GET /health - ${health}"
  else
    warn "❌ GET /health فشل"
  fi

  ask="$(curl -s -X POST http://127.0.0.1:8211/api/v1/ask \
      -H 'Content-Type: application/json' \
      -d '{"persona":"developer","user_id":"integration-test","input":"Ping من Smart Core Integration Suite."}' || true)"
  if [[ -n "$ask" ]]; then
    log "✅ POST /api/v1/ask - يعمل"
  else
    warn "❌ POST /api/v1/ask فشل"
  fi
}

check_dependencies(){
  log "📚 فحص الاعتمادات..."
  check_python_pkg "fastapi"
  check_python_pkg "requests"
  check_python_pkg "pydantic"
  check_python_pkg "uvicorn"
  check_python_pkg "dotenv"    # python-dotenv
  check_python_pkg "sqlalchemy" || true
}

check_databases(){
  log "🗄️ فحص قواعد البيانات..."
  local db
  for db in \
    "${APP_ROOT}/data/memory.db" \
    "${APP_ROOT}/data/smart_core_memory.db" \
    "${APP_ROOT}/data/smartfriend_unified.db" \
    "${APP_ROOT}/data/unified_memory.db"
  do
    if [[ -f "$db" ]]; then
      local size tables
      size="$(du -h "$db" | awk '{print $1}')"
      tables="$(sqlite3 "$db" '.tables' 2>/dev/null | wc -w || echo 0)"
      log "  • $(basename "$db"): الحجم ${size}, الجداول: ${tables}"
    else
      warn "  • $(basename "$db"): غير موجود"
    fi
  done

  if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ':5432$'; then
    log "  ✅ PostgreSQL - نشط"
  else
    warn "  ❌ PostgreSQL غير نشط"
  fi
}

check_identity(){
  log "⚙️ فحص إعدادات الهوية..."
  if [[ ! -f "$CONFIG_FILE" ]]; then
    err "ملف الهوية غير موجود: $CONFIG_FILE"
    return
  fi
  log "  ✅ ملف الهوية موجود"

  for key in SMART_CORE_API_KEY SMART_CORE_PROVIDER SMART_CORE_MODEL; do
    if grep -q "^${key}=" "$CONFIG_FILE"; then
      log "  ✅ ${key} مضبوط"
    else
      warn "  ❌ ${key} غير مضبوط"
    fi
  done

  local bots_count
  bots_count="$(grep -E '^(DEV_BOT_TOKEN|FORENSIC_BOT_TOKEN|ASSISTANT_BOT_TOKEN)=' "$CONFIG_FILE" | wc -l || echo 0)"
  log "  ℹ️ عدد توكنات البوت: ${bots_count}"
}

quick_check(){
  ensure_dirs
  log "بدء الفحص السريع..."
  check_system_basic
  check_services
  check_smart_core_health
  check_dependencies
  check_databases
  check_identity
  log "✅ الفحص السريع اكتمل!"
}

run_smart_core(){
  log "🚀 تشغيل Smart Core..."
  pkill -f "uvicorn smart_core.app:app" 2>/dev/null || true
  sleep 2
  cd "$APP_ROOT"
  if [[ -x "$APP_ROOT/scripts/run_smart_core.sh" ]]; then
    "$APP_ROOT/scripts/run_smart_core.sh" >> /tmp/smart_core_restored.log 2>&1 &
    log "✅ تم استدعاء scripts/run_smart_core.sh"
  else
    warn "لم يتم العثور على scripts/run_smart_core.sh – تشغيل مباشر..."
    python3 -m uvicorn smart_core.app:app --host 127.0.0.1 --port 8211 --workers 1 >> /tmp/smart_core_restored.log 2>&1 &
  fi
  sleep 8
  check_smart_core_health
}

run_integration_tests(){
  log "🧪 اختبارات التكامل..."
  local ok=0 fail=0

  if curl -s http://127.0.0.1:8211/ >/dev/null 2>&1; then
    log "  ✅ اختبار الخدمة الأساسية"
    ((ok++))
  else
    warn "  ❌ اختبار الخدمة الأساسية"
    ((fail++))
  fi

  if curl -s http://127.0.0.1:8211/health >/dev/null 2>&1; then
    log "  ✅ اختبار /health"
    ((ok++))
  else
    warn "  ❌ اختبار /health"
    ((fail++))
  fi

  if curl -s -X POST http://127.0.0.1:8211/api/v1/ask \
        -H 'Content-Type: application/json' \
        -d '{"persona":"developer","user_id":"integration-test","input":"Test"}' >/dev/null 2>&1; then
    log "  ✅ اختبار /api/v1/ask"
    ((ok++))
  else
    warn "  ❌ اختبار /api/v1/ask"
    ((fail++))
  fi

  local mem_count
  mem_count="$(sqlite3 "${APP_ROOT}/data/smart_core_memory.db" 'SELECT COUNT(*) FROM mem_entries;' 2>/dev/null || echo 0)"
  log "  ℹ️ عدد مدخلات الذاكرة: ${mem_count}"

  if [[ "$fail" -eq 0 ]]; then
    log "🎉 جميع اختبارات التكامل ناجحة (${ok} ناجح)"
  else
    warn "نتائج الاختبارات: ${ok} نجاح, ${fail} فشل"
  fi
}

generate_report(){
  ensure_dirs
  local ts report
  ts="$(date +%Y%m%d_%H%M%S)"
  report="${REPORT_DIR}/integration_report_${ts}.md"

  log "📊 إنشاء تقرير: ${report}"

  {
    echo "# Smart Core Integration Report"
    echo
    echo "- Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- Host: $(hostname)"
    echo
    echo "## System"
    grep "• المعالج" "$LOG_FILE" || true
    grep "• الذاكرة" "$LOG_FILE" || true
    grep "• التخزين" "$LOG_FILE" || true
    grep "• الحمل" "$LOG_FILE" || true
    echo
    echo "## Services"
    grep "✅" "$LOG_FILE" | grep "port" || true
    echo
    echo "## Smart Core"
    grep "GET /" "$LOG_FILE" || true
    grep "/health" "$LOG_FILE" || true
    echo
    echo "## Databases"
    grep "memory.db" "$LOG_FILE" || true
    grep "smart_core_memory.db" "$LOG_FILE" || true
    grep "unified_memory.db" "$LOG_FILE" || true
    echo
    echo "## Identity / ENV"
    grep "SMART_CORE_" "$LOG_FILE" || true
    grep "توكنات البوت" "$LOG_FILE" || true
    echo
    echo "_تم إنشاء التقرير بواسطة Smart Core Integration Suite_"
  } > "$report"

  log "✅ تم إنشاء التقرير: ${report}"
}

full_workflow(){
  log "بدء سير العمل الكامل..."
  quick_check
  run_integration_tests
  generate_report
  log "✅ سير العمل الكامل اكتمل"
}

main_menu(){
  echo "=========================================="
  echo "   🚀 Smart Core Integration Suite"
  echo "=========================================="
  echo "1. فحص سريع"
  echo "2. تشغيل Smart Core"
  echo "3. اختبارات التكامل"
  echo "4. إنشاء تقرير"
  echo "5. سير عمل كامل (فحص + اختبارات + تقرير)"
  echo "6. خروج"
  echo "=========================================="
  read -rp "اختر [1-6]: " choice
  case "$choice" in
    1) quick_check ;;
    2) run_smart_core ;;
    3) run_integration_tests ;;
    4) quick_check; generate_report ;;
    5) full_workflow ;;
    6) log "خروج من Smart Core Integration Suite"; exit 0 ;;
    *) echo "خيار غير صالح";;
  esac
}

ensure_dirs

case "${1:-}" in
  --quick) quick_check ;;
  --full)  full_workflow ;;
  *)       main_menu ;;
esac
EOSUITE

  chmod +x "$INTEGRATION"
  log "تم تحديث السكربت: $INTEGRATION"

  log "تعطيل وحدات systemd القديمة (smartfriend-api, smartfrind-gateway) إن وجدت..."
  systemctl disable --now smartfriend-api.service smartfrind-gateway.service 2>/dev/null || true

  local WRAPPER="/usr/local/bin/smartcore-suite"
  if [[ -f "$WRAPPER" && ! -L "$WRAPPER" ]]; then
    cp "$WRAPPER" "${WRAPPER}.bak_$(date +%Y%m%d_%H%M%S)"
    log "تم أخذ نسخة احتياطية من $WRAPPER"
  fi

  cat > "$WRAPPER" << 'EOWRAP'
#!/bin/bash
exec /opt/smartfriend-suite/smart_core_integration_suite.sh "$@"
EOWRAP
  chmod +x "$WRAPPER"
  log "تم إنشاء الأمر المختصر: smartcore-suite"

  log "تشغيل فحص سريع غير تفاعلي للتحقق..."
  /opt/smartfriend-suite/smart_core_integration_suite.sh --quick || true

  log "اكتمل تنفيذ sf_suite_finalize.sh"
  echo "Log file: $LOG_FILE"
}

main "$@"
