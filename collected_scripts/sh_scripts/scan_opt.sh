#!/bin/bash
echo "=================================================="
echo "   📁 فحص مجلد /opt بشكل عملي"
echo "=================================================="
echo "الوقت: $(date)"

# فحص بسيط وسريع
echo "1. المجلدات في /opt:"
ls -la /opt | head -20

echo ""
echo "2. حجم smartfriend-suite:"
du -sh /opt/smartfriend-suite 2>/dev/null || echo "غير موجود"

echo ""
echo "3. الملفات المهمة:"
find /opt/smartfriend-suite -name "*.db" -type f 2>/dev/null | head -10
find /opt/smartfriend-suite -name "*.py" -type f 2>/dev/null | head -5
find /opt/smartfriend-suite -name "*.sh" -type f 2>/dev/null | head -5

echo ""
echo "✅ تم الفحص بنجاح"
