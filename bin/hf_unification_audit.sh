#!/usr/bin/env bash
# HyperFFactory - Full Unification Audit Runner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"

cd "$ROOT_DIR"

echo "=================================================="
echo "🧭 HF UNIFICATION AUDIT RUN"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root : $ROOT_DIR"
echo "=================================================="

# 1) فحص الشجرة الموحّدة (يرصد أي روابط جديدة)
if [[ -x "$ROOT_DIR/bin/hf_assert_unified_tree.sh" ]]; then
  echo "▶ تشغيل hf_assert_unified_tree.sh ..."
  "$ROOT_DIR/bin/hf_assert_unified_tree.sh"
else
  echo "⚠️ hf_assert_unified_tree.sh غير موجود أو غير قابل للتنفيذ."
fi

# 2) فحص صحة السيوت و ffactory
if [[ -x "$ROOT_DIR/bin/hf_health_all.sh" ]]; then
  echo "▶ تشغيل hf_health_all.sh ..."
  "$ROOT_DIR/bin/hf_health_all.sh"
else
  echo "⚠️ hf_health_all.sh غير موجود أو غير قابل للتنفيذ."
fi

# 3) تحديث فهرس السكربتات وتحليل التعلّم
if [[ -x "$ROOT_DIR/bin/hf_learn_index.sh" ]]; then
  echo "▶ تشغيل hf_learn_index.sh ..."
  "$ROOT_DIR/bin/hf_learn_index.sh"
else
  echo "⚠️ hf_learn_index.sh غير موجود أو غير قابل للتنفيذ."
fi

if [[ -x "$ROOT_DIR/bin/hf_learn_analyze.sh" ]]; then
  echo "▶ تشغيل hf_learn_analyze.sh ..."
  "$ROOT_DIR/bin/hf_learn_analyze.sh"
else
  echo "⚠️ hf_learn_analyze.sh غير موجود أو غير قابل للتنفيذ."
fi

echo "=================================================="
echo "✅ HF UNIFICATION AUDIT انتهى."
echo "📁 تقارير محتملة داخل: $ROOT_DIR/reports"
echo "   - hf_assert_unified_tree_*.log"
echo "   - hf_health_report_*.log"
echo "   - hf_learn_report_*.log"
echo "=================================================="
