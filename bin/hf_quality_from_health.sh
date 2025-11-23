#!/usr/bin/env bash
# HyperFFactory - Import Health Report into Quality/Errors/Learning
# Usage:
#   hf_quality_from_health.sh [health_report.log]
#
# إن لم يمرَّر ملف، يستخدم آخر تقرير:
#   reports/hf_health_report_*.log (أحدث واحد)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
REPORTS_DIR="$ROOT_DIR/reports"

QUALITY_LOG="$ROOT_DIR/bin/hf_quality_log.sh"
ERRORS_LOG="$ROOT_DIR/bin/hf_errors_log.sh"
EXP_LOG="$ROOT_DIR/bin/hf_experience_add.sh"

actor="hf_health_all"

if [[ ! -x "$QUALITY_LOG" || ! -x "$ERRORS_LOG" || ! -x "$EXP_LOG" ]]; then
  echo "❌ مطلوب وجود السكربتات التالية كقابلة للتنفيذ:" >&2
  echo "   $QUALITY_LOG" >&2
  echo "   $ERRORS_LOG" >&2
  echo "   $EXP_LOG" >&2
  exit 1
fi

if [[ $# -ge 1 ]]; then
  REPORT_FILE="$1"
else
  REPORT_FILE="$(ls -t "$REPORTS_DIR"/hf_health_report_*.log 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${REPORT_FILE:-}" || ! -f "$REPORT_FILE" ]]; then
  echo "❌ لم يتم العثور على تقرير Health صالح." >&2
  exit 1
fi

echo "=================================================="
echo "🔄 HyperFFactory – Import Health → Quality/Errors/Learning"
echo "📄 Report : $REPORT_FILE"
echo "=================================================="

# دالة مساعدة لاستخراج بلوك بين عنوانين
extract_block() {
  local start_pattern="$1"
  local end_pattern="$2"
  awk -v start="$start_pattern" -v end="$end_pattern" '
    $0 ~ start {flag=1; next}
    $0 ~ end && flag {flag=0; exit}
    flag
  ' "$REPORT_FILE"
}

# بلوكات الأقسام
smartfriend_block="$(extract_block "🔹 SMARTFRIEND SUITE" "--------------------------------------------------")"
ffactory_block="$(extract_block "🔹 FFACTORY / AI STACK" "==================================================")"

# دالة لتحديد النتيجة العامّة لقسم
decide_result() {
  local block="$1"
  if printf '%s\n' "$block" | grep -q "❌"; then
    echo "FAIL"
  elif printf '%s\n' "$block" | grep -q "⚠️"; then
    echo "WARN"
  else
    echo "PASS"
  fi
}

# 1) SMARTFRIEND SUITE → جودة + أخطاء + خبرة
if [[ -n "$smartfriend_block" ]]; then
  sf_result="$(decide_result "$smartfriend_block")"
  sf_score="NULL"

  case "$sf_result" in
    PASS) sf_score=100 ;;
    WARN) sf_score=70 ;;
    FAIL) sf_score=30 ;;
  esac

  echo "👉 SMARTFRIEND SUITE result: $sf_result (score=$sf_score)"

  "$QUALITY_LOG" "$actor" "health_smartfriend" "smartfriend" "$sf_result" "$sf_score" "Imported from health report $(basename "$REPORT_FILE")"

  # أخطاء لكل سطر تحذير/خطأ
  # ⚠️  sf-core.service : activating
  printf '%s\n' "$smartfriend_block" | grep -E "⚠️|❌" || true | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # استنتاج بسيط لنوع الخطأ
    error_type="service_status"
    severity="MEDIUM"
    if printf '%s\n' "$line" | grep -q "❌"; then
      severity="HIGH"
    fi
    "$ERRORS_LOG" "$actor" "$error_type" "$severity" "$line" "scope=smartfriend;report=$(basename "$REPORT_FILE")"
  done

  # خبرة بسيطة
  case "$sf_result" in
    PASS)
      "$EXP_LOG" "health_smartfriend" 0.9 "smartfriend health stable" "no immediate action" "smartfriend,health,stable"
      ;;
    WARN)
      "$EXP_LOG" "health_smartfriend" 0.7 "smartfriend health warn" "monitor services and restart if needed" "smartfriend,health,warn"
      ;;
    FAIL)
      "$EXP_LOG" "health_smartfriend" 0.5 "smartfriend health fail" "needs manual investigation" "smartfriend,health,fail"
      ;;
  esac
fi

# 2) FFACTORY / AI STACK → جودة + أخطاء + خبرة
if [[ -n "$ffactory_block" ]]; then
  ff_result="$(decide_result "$ffactory_block")"
  ff_score="NULL"

  case "$ff_result" in
    PASS) ff_score=100 ;;
    WARN) ff_score=75 ;;
    FAIL) ff_score=40 ;;
  esac

  echo "👉 FFACTORY / AI STACK result: $ff_result (score=$ff_score)"

  "$QUALITY_LOG" "$actor" "health_ffactory" "ffactory" "$ff_result" "$ff_score" "Imported from health report $(basename "$REPORT_FILE")"

  printf '%s\n' "$ffactory_block" | grep -E "⚠️|❌" || true | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    error_type="ffactory_health"
    severity="MEDIUM"
    if printf '%s\n' "$line" | grep -q "❌"; then
      severity="HIGH"
    fi
    "$ERRORS_LOG" "$actor" "$error_type" "$severity" "$line" "scope=ffactory;report=$(basename "$REPORT_FILE")"
  done

  case "$ff_result" in
    PASS)
      "$EXP_LOG" "health_ffactory" 0.9 "ffactory health stable" "no immediate action" "ffactory,health,stable"
      ;;
    WARN)
      "$EXP_LOG" "health_ffactory" 0.7 "ffactory health warn" "monitor containers and resources" "ffactory,health,warn"
      ;;
    FAIL)
      "$EXP_LOG" "health_ffactory" 0.5 "ffactory health fail" "needs manual investigation" "ffactory,health,fail"
      ;;
  esac
fi

echo "=================================================="
echo "✅ تم استيراد تقرير الصحة إلى:"
echo "   - الجودة   : hf_quality.db"
echo "   - الأخطاء  : hf_errors.db"
echo "   - الخبرات  : hf_learning.db"
echo "=================================================="
