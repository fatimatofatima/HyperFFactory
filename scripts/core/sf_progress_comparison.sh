#!/bin/bash
echo "📈 مقارنة التقدم مع آخر تقرير"

CURRENT_REPORT=$(ls -1t /opt/smartfriend-suite/reports/sf_unification_progress_*.txt | head -1)
PREVIOUS_REPORT=$(ls -1t /opt/smartfriend-suite/reports/sf_unification_progress_*.txt | head -2 | tail -1)

if [ -z "$PREVIOUS_REPORT" ]; then
    echo "ℹ️  هذا هو أول تقرير، لا توجد مقارنة ممكنة"
    exit 0
fi

echo "🆕 التقرير الحالي: $(basename $CURRENT_REPORT)"
echo "🆚 التقرير السابق: $(basename $PREVIOUS_REPORT)"
echo

# استخراج الأرقام من التقارير
get_stat() {
    local file=$1
    local pattern=$2
    grep "$pattern" "$file" | grep -o '[0-9]\+' | head -1
}

CURRENT_SF=$(get_stat "$CURRENT_REPORT" "خدمات SmartFriend Suite النشطة")
PREVIOUS_SF=$(get_stat "$PREVIOUS_REPORT" "خدمات SmartFriend Suite النشطة")

CURRENT_LEGACY=$(get_stat "$CURRENT_REPORT" "خدمات Legacy النشطة")
PREVIOUS_LEGACY=$(get_stat "$PREVIOUS_REPORT" "خدمات Legacy النشطة")

CURRENT_CRITICAL=$(get_stat "$CURRENT_REPORT" "الخدمات الحرجة العاملة")
PREVIOUS_CRITICAL=$(get_stat "$PREVIOUS_REPORT" "الخدمات الحرجة العاملة")

echo "📊 التغييرات منذ آخر تقرير:"
echo "   📈 خدمات السيوت النشطة: $PREVIOUS_SF → $CURRENT_SF ($(($CURRENT_SF - $PREVIOUS_SF)))"
echo "   📉 خدمات Legacy النشطة: $PREVIOUS_LEGACY → $CURRENT_LEGACY ($(($CURRENT_LEGACY - $PREVIOUS_LEGACY)))"
echo "   🎯 الخدمات الحرجة العاملة: $PREVIOUS_CRITICAL → $CURRENT_CRITICAL ($(($CURRENT_CRITICAL - $PREVIOUS_CRITICAL)))"

# حساب التقدم الإجمالي
CURRENT_PROGRESS=$(grep "التقدم الكلي" "$CURRENT_REPORT" | grep -o '[0-9]\+%' | head -1)
PREVIOUS_PROGRESS=$(grep "التقدم الكلي" "$PREVIOUS_REPORT" | grep -o '[0-9]\+%' | head -1)

echo
echo "🎯 التقدم الكلي: $PREVIOUS_PROGRESS → $CURRENT_PROGRESS"
