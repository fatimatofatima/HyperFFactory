#!/usr/bin/env bash
# HyperFFactory - Learning Layer: Full learning cycle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
REPORT_DIR="$ROOT_DIR/reports"

mkdir -p "$REPORT_DIR"

echo "=================================================="
echo "🧠 HYPERFFACTORY LEARNING LAYER – FULL CYCLE"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root : $ROOT_DIR"
echo "=================================================="
echo

# 1) بناء الفهرس من السكربتات
echo "1) 🔎 بناء فهرس السكربتات (scripts_index.csv) ..."
bin/hf_learn_index.sh
echo

# 2) تحميل الفهرس إلى قاعدة التعلّم
echo "2) 🧠 تحميل الفهرس إلى قاعدة التعلّم (hf_learning.db) ..."
bin/hf_learn_to_db.sh
echo

# 3) تقرير التعلّم من CSV (ملخّص سريع)
echo "3) 📊 توليد تقرير CSV (hf_learn_report_*.log) ..."
bin/hf_learn_analyze.sh
echo

# 4) تقرير التعلّم من DB (الرؤية العميقة)
echo "4) 📚 توليد تقرير DB (hf_learning_db_report_*.log) ..."
bin/hf_learn_report_db.sh
echo

# عرض أسماء آخر تقريرين للراحة
LAST_CSV_REPORT="$(ls -t "$REPORT_DIR"/hf_learn_report_*.log 2>/dev/null | head -n 1 || true)"
LAST_DB_REPORT="$(ls -t "$REPORT_DIR"/hf_learning_db_report_*.log 2>/dev/null | head -n 1 || true)"

echo "=================================================="
echo "✅ دورة التعلّم مكتملة."
if [[ -n "$LAST_CSV_REPORT" ]]; then
  echo "📄 آخر تقرير CSV : $LAST_CSV_REPORT"
fi
if [[ -n "$LAST_DB_REPORT" ]]; then
  echo "📄 آخر تقرير DB  : $LAST_DB_REPORT"
fi
echo "=================================================="
