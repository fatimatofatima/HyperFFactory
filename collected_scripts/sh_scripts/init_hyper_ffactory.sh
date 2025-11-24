#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${1:-/root/HyperFFactory}"

echo "[*] Init HyperFFactory base at: $BASE_DIR"

# إنشاء المجلدات الأساسية فقط (لا نلمس ملفات الكونفيج الحالية الموجودة)
mkdir -p "$BASE_DIR"/config
mkdir -p "$BASE_DIR"/stack/core "$BASE_DIR"/stack/monitoring "$BASE_DIR"/stack/ai_support
mkdir -p "$BASE_DIR"/apps/timeline_analyzer "$BASE_DIR"/apps/netflow_inspector "$BASE_DIR"/apps/backend_coach_api
mkdir -p "$BASE_DIR"/scripts/core "$BASE_DIR"/scripts/health "$BASE_DIR"/scripts/fix "$BASE_DIR"/scripts/ai
mkdir -p "$BASE_DIR"/ai/prompts "$BASE_DIR"/ai/patterns "$BASE_DIR"/ai/skills_tracks "$BASE_DIR"/ai/datasets
mkdir -p "$BASE_DIR"/reports/stack_status "$BASE_DIR"/reports/apps_status "$BASE_DIR"/reports/ai_eval
mkdir -p "$BASE_DIR"/audit

# README فقط إذا غير موجود
if [ ! -f "$BASE_DIR/README.md" ]; then
  cat > "$BASE_DIR/README.md" << 'EOF_README'
# HyperFFactory – Unified Smart Factory

هذا المشروع يمثل مصنع موحّد لإدارة:
- Stacks أساسية (core_elk / monitoring / ai_support / smartfriend_suite)
- سكربتات تحكم مركزية في scripts/core و scripts/health
- تقارير حالة في reports/stack_status و reports/apps_status
EOF_README
fi

echo "[*] HyperFFactory init done. Example:"
echo "    cd $BASE_DIR"
echo "    scripts/core/ffactory.sh health"
echo "    scripts/core/ffactory.sh status"
