#!/usr/bin/env bash
set -e

AGENT_ID="$1"
USER_INPUT="${2:-طلب مساعدة عامة}"

echo "🚀 HyperFFactory AI - الإصدار الآمن"
echo "🤖 تشغيل: $AGENT_ID"
echo "📝 المدخلات: $USER_INPUT"
echo ""

python3 "$(dirname "$0")/secure_llm_runner.py" "$AGENT_ID" "$USER_INPUT"
