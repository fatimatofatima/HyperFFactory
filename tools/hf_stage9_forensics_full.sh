#!/usr/bin/env bash
# HyperFFactory – Stage9 Wrapper:
# Forensics / Integration Scan / Gaps / DB Audit

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT" || { echo "❌ لا يمكن الدخول إلى $ROOT"; exit 1; }

CORE_SCAN="./tools/hf_full_integration_scan.sh"
FIX_GAPS="./tools/hf_fix_all_gaps.sh"
GAPS_REPORT="./tools/hf_gap_and_tasks_report.sh"
DB_AUDIT="./tools/hf_db_audit.sh"
DB_SHADOW="./tools/hf_db_shadow_audit.sh"

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "=================================================="
echo " HyperFFactory – Stage9 Forensics & Gaps Full Wrapper"
echo " ROOT : $ROOT"
echo " TIME : $NOW"
echo "=================================================="
echo

run_step() {
  local label="$1"
  local script="$2"

  echo "--------------------------------------------------"
  echo "▶ $label"
  echo "--------------------------------------------------"

  if [ ! -x "$script" ]; then
    echo "⚠️ السكربت غير موجود أو غير قابل للتنفيذ: $script"
    echo
    return
  fi

  set +e
  "$script" | sed 's/^/  /'
  local rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    echo "✅ $label – OK"
  else
    echo "⚠️ $label – فشل برمز $rc (متابعة باقي المراحل)"
  fi
  echo
}

# 1) فحص تكامل شامل بين الأنظمة (HyperFFactory / SmartFriend / FFactory)
run_step "Stage9 Core – Full Integration Scan (hf_full_integration_scan.sh)" "$CORE_SCAN"

# 2) محاولة إصلاح الفجوات المسجّلة (Gaps)
run_step "Fix All Gaps (hf_fix_all_gaps.sh)" "$FIX_GAPS"

# 3) تقرير فجوات + مهام متعلقة بها
run_step "Gaps & Tasks Report (hf_gap_and_tasks_report.sh)" "$GAPS_REPORT"

# 4) تدقيق قواعد البيانات الرسمية
run_step "DB Audit (hf_db_audit.sh)" "$DB_AUDIT"
run_step "DB Shadow Audit (hf_db_shadow_audit.sh)" "$DB_SHADOW"

echo "=================================================="
echo " ملخص Stage9 – Forensics & Gaps:"
echo "  - تم تشغيل فحص التكامل، إصلاح الفجوات، تقارير gaps، وتدقيق DB."
echo "  - راجع تقارير /root/HyperFFactory/reports/ لمزيد من التفاصيل."
echo "=================================================="
