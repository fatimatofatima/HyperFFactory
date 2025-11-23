#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root/HyperFFactory"

echo "=================================================="
echo "🚦 FFACTORY / AI STACK HEALTH CHECK"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root : $ROOT_DIR"
echo "=================================================="

FF_DIR="/opt/ffactory"

if [[ -d "$FF_DIR" ]]; then
  echo "✅ تم العثور على مجلد ffactory: $FF_DIR"
else
  echo "⚠️ مجلد ffactory غير موجود: $FF_DIR (قد يكون المسار مختلفًا)"
fi

echo
echo "— فحص حاويات Docker الخاصة بـ ffactory —"
if command -v docker >/dev/null 2>&1; then
  if docker ps >/dev/null 2>&1; then
    echo "📦 الحاويات التي تحتوي على ffactory في الاسم:"
    docker ps --format ' - {{.Names}}  | {{.Status}}' | grep -i 'ffactory' || echo "⚪ لا توجد حاويات ffactory شغّالة حاليًا"
  else
    echo "⚠️ docker ps فشل (تحقّق من خدمة Docker)"
  fi
else
  echo "⚠️ docker غير مثبت أو غير متاح في PATH"
fi

echo
echo "— سكربتات صحة ffactory (إن وجدت) —"
FF_HEALTH_BIN="/usr/local/bin/ffactory-health-check.sh"
FF_READY_BIN="/usr/local/sbin/ffactory-ready-check.sh"

if [[ -x "$FF_HEALTH_BIN" ]]; then
  echo "▶ تشغيل ffactory-health-check.sh (اختباري، بدون إيقاف عند الفشل)..."
  if "$FF_HEALTH_BIN" >/tmp/ffactory_health_check.log 2>&1; then
    echo "✅ ffactory-health-check.sh: نجح (راجع /tmp/ffactory_health_check.log)"
  else
    echo "🟡 ffactory-health-check.sh: أعاد خطأ (راجع /tmp/ffactory_health_check.log)"
  fi
else
  echo "⚪ سكربت ffactory-health-check.sh غير موجود أو غير قابل للتنفيذ: $FF_HEALTH_BIN"
fi

if [[ -x "$FF_READY_BIN" ]]; then
  echo "▶ تشغيل ffactory-ready-check.sh (اختباري، بدون إيقاف عند الفشل)..."
  if "$FF_READY_BIN" >/tmp/ffactory_ready_check.log 2>&1; then
    echo "✅ ffactory-ready-check.sh: نجح (راجع /tmp/ffactory_ready_check.log)"
  else
    echo "🟡 ffactory-ready-check.sh: أعاد خطأ (راجع /tmp/ffactory_ready_check.log)"
  fi
else
  echo "⚪ سكربت ffactory-ready-check.sh غير موجود أو غير قابل للتنفيذ: $FF_READY_BIN"
fi

echo
echo "✅ FFACTORY HEALTH CHECK انتهى (بدون كسر للهيكل الموحّد)."
