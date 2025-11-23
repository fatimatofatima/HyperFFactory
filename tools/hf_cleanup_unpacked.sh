#!/usr/bin/env bash
set -euo pipefail

BASE="/root/HyperFFactory"

echo "=== HyperFFactory - Cleanup extracted backup directories ==="
echo

# جمع كل مجلدات all_archives_unpacked_*
mapfile -t dirs < <(find "$BASE" -maxdepth 1 -type d -name "all_archives_unpacked_*" | sort || true)

if [ "${#dirs[@]}" -eq 0 ]; then
  echo "لا يوجد مجلدات باسم all_archives_unpacked_* لحذفها تحت $BASE"
  exit 0
fi

echo "سيتم التعامل مع المجلدات التالية:"
for d in "${dirs[@]}"; do
  if [ -d "$d" ]; then
    du -sh "$d" || echo "    $d"
  fi
done

echo
read -rp "تأكيد الحذف النهائي لكل المجلدات أعلاه؟ اكتب بالضبط: yes ثم Enter: " ans
if [ "$ans" != "yes" ]; then
  echo "تم الإلغاء، لم يتم حذف أي شيء."
  exit 0
fi

for d in "${dirs[@]}"; do
  if [ -d "$d" ]; then
    echo "حذف: $d"
    rm -rf --one-file-system "$d"
  fi
done

echo
echo "اكتمل الحذف. حالة القرص الحالية:"
df -h /
