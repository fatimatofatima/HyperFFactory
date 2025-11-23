#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-pre}"

# الجذر الموحد للمصنع
ROOT="${HYPER_ROOT:-/root/HyperFFactory}"

CURRENT_DIR=$(pwd -P 2>/dev/null || pwd)
SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[0]:-$0}")

if [ "$MODE" = "post" ]; then
  echo
  echo "===== HyperFFactory – سياسة الهيكل الموحد (تذكير بعد التنفيذ) ====="
  date
  echo "الجذر المسموح      : $ROOT"
  echo "مسار العمل الحالي : $CURRENT_DIR"
  echo
  echo "السياسة:"
  echo "  • ممنوع تشغيل أو حفظ سكربتات خارج الجذر الموحد."
  echo "  • أي سكربت أو خدمة تعمل من خارج $ROOT تعتبر تخريب للبنية ويجب إصلاحها فورًا."
  echo "  • الهدف: التجميع والتكامل الكامل داخل الهيكل الموحد فقط."
  echo "==============================================================="
  exit 0
fi

echo "===== HyperFFactory – Unified Root Enforcement (PRE) ====="
date
echo "Required root  : $ROOT"
echo "Current PWD    : $CURRENT_DIR"
echo "Script path    : $SCRIPT_PATH"
echo
echo "الهدف الرسمي للنظام:"
echo "  • التجميع والتكامل داخل الهيكل الموحد فقط."
echo "  • أي تشغيل أو تخزين سكربتات خارج هذا الهيكل يعتبر مخالفة وتخريب ويجب إصلاحه."
echo

violation=0

# فحص مسار العمل الحالي
case "$CURRENT_DIR" in
  "$ROOT"|"$ROOT"/*)
    echo "✔ PWD داخل الهيكل الموحد."
    ;;
  *)
    echo "✖ PWD خارج الهيكل الموحد – تشغيل غير مسموح."
    violation=1
    ;;
esac

# فحص موقع ملف السكربت نفسه
case "$SCRIPT_PATH" in
  "$ROOT"|"$ROOT"/*)
    echo "✔ موقع السكربت داخل الهيكل الموحد."
    ;;
  *)
    echo "✖ موقع السكربت خارج الهيكل الموحد – هذا تخريب للبنية."
    violation=1
    ;;
esac

if [ "$violation" -ne 0 ]; then
  echo
  echo "⚠ سياسة HyperFFactory:"
  echo "  • الجذر المسموح: $ROOT"
  echo "  • أي سكربت أو عملية تعمل من خارج هذا الجذر تعتبر مخالفة لسياسة التجميع والتكامل."
  echo "  • يجب نقل السكربتات والعمليات إلى الهيكل الموحد وإصلاح المسارات فورًا."
  echo
  echo "تم إيقاف التنفيذ لحماية التكامل."
  exit 1
fi

echo
echo "✅ السياسة محققة – التنفيذ مسموح داخل الهيكل الموحد."
