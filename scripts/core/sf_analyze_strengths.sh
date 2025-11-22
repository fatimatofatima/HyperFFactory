#!/bin/bash
MATRIX_FILE=$(ls -t /opt/smartfriend-suite/reports/sf_service_matrix_*.csv | head -1)

echo "=== تحليل الخدمات حسب القوة والأولوية ==="
echo

echo "1. الخدمات الأقوى (للحفاظ عليها وتطويرها):"
awk -F, '$11 >= 4 {print "   💪 " $1 " - قوة: " $11 " - دور: " $6}' "$MATRIX_FILE" | head -10

echo
echo "2. الخدمات المتوسطة (تحتاج تحسين):"
awk -F, '$11 == 3 {print "   ⚡ " $1 " - قوة: " $11 " - دور: " $6}' "$MATRIX_FILE" | head -10

echo
echo "3. الخدمات الضعيفة (للاستبدال):"
awk -F, '$11 <= 2 {print "   🐌 " $1 " - قوة: " $11 " - دور: " $6}' "$MATRIX_FILE" | head -10

echo
echo "4. التوزيع حسب العائلة:"
awk -F, 'NR>1 {count[$2]++} END {for(fam in count) print "   " fam ": " count[fam] " خدمات"}' "$MATRIX_FILE"

echo
echo "5. التضاربات المحتملة (خدمات بنفس الدور):"
awk -F, 'NR>1 {print $6 "|" $1}' "$MATRIX_FILE" | sort | while IFS='|' read role service; do
  echo "   $role: $service"
done | uniq -c | awk '$1 > 1 {print "   ⚠️  " $2 " - " $1 " خدمات متضاربة"}'
