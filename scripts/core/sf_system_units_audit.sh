#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================="
echo "  🧩 تدقيق خدمات وملفات systemd للمشروع"
echo "==============================="
echo

# الكلمات المفتاحية لمشروعك
PATTERN='smartfrind|smartfriend|sf-|ffactory|nugxs'

########################################
# 1) unit-files (enabled/disabled/...)
########################################
echo "1) 📦 قائمة unit-files (حالة التفعيل):"
systemctl list-unit-files --type=service \
  | egrep "$PATTERN" \
  || echo "   ❌ لا توجد unit-files مطابقة بالفلتر الحالي"
echo
echo "----------------------------------------"

########################################
# 2) حالة كل خدمة + ملف الوحدة
########################################
echo "2) 📡 حالة كل خدمة + مسار ملف الوحدة + حالة الملف:"

SERVICES=$(systemctl list-unit-files --type=service \
  | egrep "$PATTERN" \
  | awk '{print $1}' \
  | sort -u || true)

if [ -z "$SERVICES" ]; then
  echo "   ❌ لا توجد خدمات مطابقة بالفلتر."
else
  for svc in $SERVICES; do
    echo
    echo "🔹 الخدمة: $svc"
    echo "   ➤ is-enabled: $(systemctl is-enabled "$svc" 2>/dev/null || echo 'unknown')"

    echo "   ➤ حالة التشغيل (status مختصر):"
    systemctl --no-pager --plain status "$svc" -n 3 2>/dev/null || echo "      (status غير متاح / الخدمة لم تُحمّل)"

    echo
    echo "   ➤ معلومات ملف الوحدة (FragmentPath / UnitFileState):"
    systemctl show "$svc" -p FragmentPath -p UnitFileState 2>/dev/null \
      || echo "      (لا توجد معلومات show لهذه الخدمة)"
    echo "----------------------------------------"
  done
fi

echo
echo "✅ انتهى فحص ملفات وخدمات systemd الخاصة بالمشروع."
