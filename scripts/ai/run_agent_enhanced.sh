#!/usr/bin/env bash
set -e

AGENT_ID="$1"
USER_INPUT="${2:-طلب مساعدة عامة}"

echo "🚀 HyperFFactory AI - النظام الذكي المحسن"
echo "🤖 تشغيل: $AGENT_ID"
echo "📝 المدخلات: $USER_INPUT"
echo ""

python3 "$(dirname "$0")/smart_local_ai_enhanced.py" "$AGENT_ID" "$USER_INPUT"
