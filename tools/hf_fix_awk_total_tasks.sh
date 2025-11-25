#!/usr/bin/env bash
# HyperFFactory – Fix awk "إجمالي المهام" pattern
# - يصلّح السطر الخاطئ في سكربتات HyperFFactory
# - يعمل نسخة احتياطية من الملفات قبل التعديل

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
cd "$ROOT"

META_DIR="$ROOT/db/meta"
TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DIR="$ROOT/_backup_awk_fix_$TS"

echo "====================================================="
echo " HyperFFactory – Fix awk إجمالي المهام"
echo " ROOT   : $ROOT"
echo " BACKUP : $BACKUP_DIR"
echo " TIME   : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "====================================================="

mkdir -p "$BACKUP_DIR"

# البحث عن الملفات التي تحتوي على النص "إجمالي المهام"
echo "[*] البحث عن الملفات التي تحتوي على 'إجمالي المهام' تحت tools/ و bin/ ..."
mapfile -t FILES < <(grep -RIl 'إجمالي المهام' tools bin 2>/dev/null || true)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "[INFO] لا توجد ملفات تحتوي على 'إجمالي المهام' – لا شيء لتعديله."
  exit 0
fi

echo "[INFO] تم العثور على ${#FILES[@]} ملف(ات):"
for f in "${FILES[@]}"; do
  echo "  - $f"
done

echo "[*] أخذ نسخة احتياطية من الملفات قبل التعديل ..."
for f in "${FILES[@]}"; do
  # الحفاظ على الهيكل داخل BACKUP_DIR
  dst="$BACKUP_DIR/$f"
  mkdir -p "$(dirname "$dst")"
  cp "$f" "$dst"
done
echo "[OK] النسخ الاحتياطي جاهز تحت: $BACKUP_DIR"

echo "[*] تطبيق إصلاح awk على الملفات ..."
for f in "${FILES[@]}"; do
  # استبدال السطر الخاطئ:
  # {print "   → إجمالي المهام:", $1}
  # بالسطر الصحيح:
  # {print "   → إجمالي المهام:", $1}
  sed -i 's/{print \\\"   → إجمالي المهام:\\\" ,$1}/{print "   → إجمالي المهام:", $1}/' "$f"
  echo "[FIX] تم تعديل: $f"
done

echo "-----------------------------------------------------"
echo "[DONE] تم إصلاح نمط awk الخاص بـ 'إجمالي المهام'."
echo "[NOTE] لو حصل أي خطأ، بإمكانك الرجوع من النسخ الاحتياطية تحت:"
echo "       $BACKUP_DIR"
echo "====================================================="
