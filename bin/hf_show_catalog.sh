#!/usr/bin/env bash

echo "📁 كتالوج تصنيف سكريبتات HyperFFactory - ملخص سريع"
echo "=================================================="

cat /root/HyperFFactory/docs/scripts_catalog.md | grep -E "^(## |### |#### |[-*] |[0-9]+\.[0-9]+)" | head -50

echo ""
echo "📖 للقائمة الكاملة: cat /root/HyperFFactory/docs/scripts_catalog.md"
echo "📊 إحصائيات: 6 فئات رئيسية - 25 سكريبت جذري - 20 فئة متخصصة"
