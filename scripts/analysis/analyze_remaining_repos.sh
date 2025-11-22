#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🔍 تحليل الريبوهات المتبقية للتكامل مع HyperFFactory"
echo "===================================================="

# قائمة الريبوهات المطلوب فحصها
REPOS=(
    "https://github.com/fatimatofatima/hyper-factory"
    "https://github.com/fatimatofatima/ffactory" 
    "https://github.com/fatimatofatima/smartfrind"
    "https://github.com/fatimatofatima/smartfriend-suite"
    "https://github.com/fatimatofatima/ffactory2"
    "https://github.com/fatimatofatima/other"
)

echo "📋 جميع الريبوهات:"
for repo in "${REPOS[@]}"; do
    echo "  - $repo"
done

echo
echo "📊 حالة التكامل الحالية في HyperFFactory:"
echo "========================================"

echo "✅ المدمج بالفعل:"
echo "   - hyper-factory (هذا المشروع الأساسي)"
echo "   - smartfriend-suite (مدمج عبر systemd services)"
echo "   - legacy ffactory (مدمج عبر legacy bridges)" 
echo "   - ffactory2 (مدمج حديثاً - جسر متقدم)"

echo
echo "❌ غير مدمج بعد:"
echo "   - ffactory (النسخة الأصلية - تحت الفحص)"
echo "   - smartfrind (ربما typo - يحتاج تأكيد)"
echo "   - other (مشاريع وأدوات مساعدة)"

echo
echo "🎯 خطة التكامل المقترحة:"
echo "========================"
echo "1. ffactory → فحص المحتوى وأخذ الكود المفيد"
echo "2. smartfrind → التأكد من الغرض وتصحيح الاسم إذا لزم"
echo "3. other → دمج الأدوات والوظائف المساعدة"
echo
echo "📈 إحصائيات النظام الحالي:"
echo "=========================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(hyper_|ffactory)" | wc -l | xargs echo "   - عدد الحاويات النشطة:"
echo "   - عدد الريبوهات المدمجة: 4/7"
echo "   - عدد الريبوهات المتبقية: 3/7"
