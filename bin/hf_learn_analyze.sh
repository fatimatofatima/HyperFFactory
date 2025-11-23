#!/usr/bin/env bash
# HyperFFactory - Learning Layer: Scripts Analyzer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
LEARN_DIR="$ROOT_DIR/learning"
IN_CSV="$LEARN_DIR/scripts_index.csv"
REPORT_DIR="$ROOT_DIR/reports"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_REPORT="$REPORT_DIR/hf_learn_report_${TS}.log"

mkdir -p "$REPORT_DIR"

if [[ ! -f "$IN_CSV" ]]; then
  echo "❌ ملف الفهرس غير موجود: $IN_CSV" >&2
  echo "   شغّل bin/hf_learn_index.sh أولاً." >&2
  exit 1
fi

{
  echo "=================================================="
  echo "🧠 HYPERFFACTORY LEARNING LAYER – SCRIPTS SUMMARY"
  echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "📂 Root : $ROOT_DIR"
  echo "📄 Source: $IN_CSV"
  echo "=================================================="
  echo

  echo "1) إجمالي السكربتات حسب النظام:"
  awk -F',' 'NR>1 { c[$4]++ } END { for (k in c) printf "   - %s : %d\n", k, c[k] }' "$IN_CSV" \
    | sort
  echo

  echo "2) المدراء مقابل العمال:"
  awk -F',' 'NR>1 { c[$2]++ } END { for (k in c) printf "   - %s : %d\n", k, c[k] }' "$IN_CSV" \
    | sort
  echo

  echo "3) توزيع الفئات (system/category):"
  awk -F',' 'NR>1 { key=$4 "/" $5; c[key]++ } END { for (k in c) printf "   - %s : %d\n", k, c[k] }' "$IN_CSV" \
    | sort
  echo

  echo "4) أعلى السكربتات أولوية (priority صغيرة = أهم):"
  echo "   id,role,priority,system,category,name,path"
  # ترتيب حسب الأولوية ثم النظام ثم الاسم
  tail -n +2 "$IN_CSV" \
    | sort -t',' -k3,3n -k4,4 -k6,6 \
    | head -n 30 \
    | sed 's/^/   /'
  echo

  echo "5) ملاحظات التعلّم (مبدئية):"
  echo "   - priority=1: مدراء أساسيون (orchestrator/suite_core/stack_core)."
  echo "   - priority=2: سكربتات صحة وقواعد بيانات وجسور تكامل مهمة."
  echo "   - priority=3: نسخ احتياطي/تقارير/تكامل ثانوي."
  echo "   - priority>=4: Legacy / تجارب / سكربتات منخفضة الأهمية."
  echo
  echo "   يمكنك استخدام هذا التقرير لاختيار:"
  echo "   * أي سكربتات تعتبر \"مدراء\" مرتبطة بالجودة والمهام."
  echo "   * أي سكربتات تعتبر \"عمال\" تحت كل مدير."
  echo "   * تحديث learning_patterns.cfg لتنعكس خبرتك بعد كل مراجعة."
  echo

  echo "=================================================="
  echo "✅ LEARNING REPORT مكتمل – التقرير: $OUT_REPORT"
  echo "=================================================="
} | tee "$OUT_REPORT"
