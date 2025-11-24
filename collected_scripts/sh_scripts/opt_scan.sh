#!/bin/bash

echo "================================================"
echo "   📁 فحص مجلد /opt"
echo "================================================"
echo "الوقت: $(date)"

echo "1. محتويات /opt:"
ls -la /opt

echo ""
echo "2. البحث عن ملفات SmartFriend:"
find /opt -name "*smart*" -type d 2>/dev/null
find /opt -name "*friend*" -type d 2>/dev/null
find /opt -name "*ffactory*" -type d 2>/dev/null

echo ""
echo "3. الملفات المهمة:"
find /opt -name "*.db" -type f 2>/dev/null | head -10
find /opt -name "*.py" -type f 2>/dev/null | head -5
find /opt -name "*.sh" -type f 2>/dev/null | head -5

echo ""
echo "✅ تم الفحص بنجاح"
