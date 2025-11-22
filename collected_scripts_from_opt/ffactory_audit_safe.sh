#!/usr/bin/env bash
# FFactory audit (safe, read-only)

set -Eeuo pipefail
trap 'echo "خطأ عند السطر $LINENO" >&2' ERR

PROJECT_DIR="${1:-/opt/ffactory}"
REPORT_FILE="/tmp/ffactory_audit_report_$(date +%Y%m%d_%H%M%S).txt"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "المجلد غير موجود: $PROJECT_DIR" >&2
  exit 2
fi

echo "🔍 فحص: $PROJECT_DIR"
echo "📄 تقرير: $REPORT_FILE"

{
  echo "========================================"
  echo "تقرير فحص شامل لمشروع ffactory"
  echo "المجلد: $PROJECT_DIR"
  echo "التاريخ: $(date -Iseconds)"
  echo "========================================"

  # الحجم الكلي
  TOTAL_SIZE="$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)"
  echo "الحجم الكلي للمجلد: ${TOTAL_SIZE:-N/A}"

  echo
  echo "[1] بنية المجلد (مستوى 1):"
  find "$PROJECT_DIR" -maxdepth 1 -mindepth 1 -printf "%y  %p\n" | sort

  echo
  echo "[2] أهم المجلدات الفرعية (مستوى 2 ملفات فقط):"
  find "$PROJECT_DIR" -maxdepth 2 -type f -printf "%p\n" | head -n 100

  echo
  echo "[3] ملفات Python:"
  PY_COUNT="$(find "$PROJECT_DIR" -type f -name '*.py' | wc -l | tr -d ' ')"
  echo "عدد ملفات .py: ${PY_COUNT:-0}"
  find "$PROJECT_DIR" -type f -name 'requirements*.txt' -o -name 'pyproject.toml' -o -name 'setup.cfg' -printf "%p\n" 2>/dev/null

  echo
  echo "[4] صلاحيات عامة:"
  stat -c "%A %U:%G %n" "$PROJECT_DIR"
  find "$PROJECT_DIR" -maxdepth 1 -mindepth 1 -printf "%m %u:%g %p\n" | sort -n

  echo
  echo "[5] فحوص أمنية خفيفة:"
  echo "ملفات أسرار محتملة:"
  find "$PROJECT_DIR" -type f \( -iname "*secret*" -o -iname "*token*" -o -iname "*.env" \) -printf "%p\n" 2>/dev/null || true

  echo
  echo "[6] ملاحظات:"
  echo "- لتشديد الصلاحيات: chmod -R go-w \"$PROJECT_DIR\""
  echo "- هذا الفحص لا يغيّر أي ملفات."
} > "$REPORT_FILE"

echo "✅ تم إنشاء التقرير."
