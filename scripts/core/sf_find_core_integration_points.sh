#!/usr/bin/env bash
set -Eeuo pipefail

echo "🎯 اكتشاف نقاط التكامل الرئيسية في SmartFrind-Core..."

CORE_DIR="/opt/smartfriend-suite"

echo ""
echo "1. 🔍 الملفات التي تستخدم ai_memory مباشرة (أولوية عالية):"
find "$CORE_DIR" -name "*.py" -type f | xargs grep -l "ai_memory" | grep -v "__pycache__" | grep -v "test" | head -10

echo ""
echo "2. 📊 الملفات التي تستخدم استعلامات معرفة:"
find "$CORE_DIR" -name "*.py" -type f | xargs grep -l "SELECT.*FROM.*ai_memory" | grep -v "__pycache__" | head -10

echo ""
echo "3. 🎓 الملفات التي تقدم محتوى تعليمي:"
find "$CORE_DIR" -name "*.py" -type f | xargs grep -l "learning\|education\|curriculum" | grep -v "__pycache__" | head -10

echo ""
echo "4. 💡 الملفات الرئيسية في Core (محتملة للتكامل):"
ls -la "$CORE_DIR/bots/app/smartfrind/"*.py 2>/dev/null | head -10

echo ""
echo "🎯 نقاط التكامل المقترحة (بناء على الاكتشاف):"
echo "   • unified_gateway.py - البوابة الرئيسية"
echo "   • learn.py - نظام التعلم"
echo "   • retrieve.py - استرجاع المعلومات"
echo "   • memory_system.py - نظام الذاكرة"
echo "   • smartfrind_app.py - التطبيق الرئيسي"
