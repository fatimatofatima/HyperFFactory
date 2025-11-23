#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root/HyperFFactory"

echo "=================================================="
echo "🚦 SMARTFRIEND SUITE HEALTH CHECK"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root : $ROOT_DIR"
echo "=================================================="

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "❌ ROOT_DIR غير موجود: $ROOT_DIR"
fi

SF_DIR="/opt/smartfriend-suite"
DB_PATH="$SF_DIR/var/db/smartfriend_unified.db"

if [[ ! -d "$SF_DIR" ]]; then
  echo "❌ مجلد السيوت غير موجود: $SF_DIR"
else
  echo "✅ تم العثور على مجلد السيوت: $SF_DIR"
fi

echo
echo "— نظام الخدمات (systemd) —"
check_service() {
  local svc="$1"
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    local st
    st=$(systemctl is-active "$svc" 2>/dev/null || true)
    case "$st" in
      active)
        echo "✅ $svc : ACTIVE"
        ;;
      inactive)
        echo "🟡 $svc : INACTIVE"
        ;;
      failed)
        echo "❌ $svc : FAILED"
        ;;
      *)
        echo "⚠️  $svc : $st"
        ;;
    esac
  else
    echo "⚪ $svc : غير موجود (Legacy أو غير مستخدم)"
  fi
}

# أهم خدمات السيوت (يمكن توسيع القائمة لاحقًا)
check_service "sf-core.service"
check_service "sf-bot.service"
check_service "sf-web.service"
check_service "sf-health.service"
check_service "sf-memory.service"
check_service "smartfrind-gateway.service"

echo
echo "— قاعدة البيانات الموحّدة smartfriend_unified.db —"
if [[ -f "$DB_PATH" ]]; then
  echo "📁 DB : $DB_PATH"
  if command -v sqlite3 >/dev/null 2>&1; then
    if sqlite3 "$DB_PATH" "SELECT 1" >/dev/null 2>&1; then
      echo "✅ SQLite check: قاعدة البيانات تعمل"
    else
      echo "❌ SQLite check: مشكلة في قاعدة البيانات"
    fi
  else
    echo "⚠️ sqlite3 غير مثبت، لن يتم فحص DB عميق"
  fi
else
  echo "❌ ملف قاعدة البيانات غير موجود: $DB_PATH"
fi

echo
echo "— فحص سكربتات الصحّة داخل السيوت (اختياري) —"
RUN_HEALTH_PY="$SF_DIR/run_health.py"
SF_SERVICE_HEALTH="$SF_DIR/bin/sf-service-health"

if [[ -f "$RUN_HEALTH_PY" ]]; then
  echo "▶ تشغيل run_health.py (اختباري، بدون إيقاف عند الفشل)..."
  if python3 "$RUN_HEALTH_PY" >/tmp/sf_run_health.log 2>&1; then
    echo "✅ run_health.py: نجح (راجع /tmp/sf_run_health.log لو حابب التفاصيل)"
  else
    echo "🟡 run_health.py: أعاد خطأ (راجع /tmp/sf_run_health.log)"
  fi
else
  echo "⚪ run_health.py غير موجود في $RUN_HEALTH_PY"
fi

if [[ -x "$SF_SERVICE_HEALTH" ]]; then
  echo "▶ تشغيل sf-service-health (اختباري، بدون إيقاف عند الفشل)..."
  if "$SF_SERVICE_HEALTH" >/tmp/sf_service_health.log 2>&1; then
    echo "✅ sf-service-health: نجح (راجع /tmp/sf_service_health.log)"
  else
    echo "🟡 sf-service-health: أعاد خطأ (راجع /tmp/sf_service_health.log)"
  fi
else
  echo "⚪ سكربت sf-service-health غير موجود أو غير قابل للتنفيذ: $SF_SERVICE_HEALTH"
fi

echo
echo "✅ SMARTFRIEND HEALTH CHECK انتهى (بدون كسر للهيكل الموحّد)."
