#!/usr/bin/env bash
set -euo pipefail

SRC="/opt/ffactory"
DST_BASE="/root/HyperFFactory/imported/opt"
DST="$DST_BASE/ffactory"
LOG_DIR="/root/HyperFFactory/docs"

mkdir -p "$LOG_DIR" "$DST_BASE"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$LOG_DIR/ffactory_move_${TS}.log"

echo "== نقل ffactory من $SRC إلى $DST ==" | tee "$LOG"

if [ ! -d "$SRC" ]; then
  echo "❌ المجلد $SRC غير موجود" | tee -a "$LOG"
  exit 1
fi

if [ -e "$DST" ]; then
  echo "❌ الوجهة $DST موجودة بالفعل – لن أكتب فوقها" | tee -a "$LOG"
  exit 1
fi

echo "سيتم تنفيذ النقل المباشر (mv) بدون نسخ احتياطي:" | tee -a "$LOG"
echo "  mv -v \"$SRC\" \"$DST_BASE/\"" | tee -a "$LOG"
echo | tee -a "$LOG"
echo "لتأكيد النقل النهائي اكتب YES بالحروف الكبيرة ثم Enter:" | tee -a "$LOG"

read -r CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "تم الإلغاء من المستخدم. القيمة المدخلة: '$CONFIRM'" | tee -a "$LOG"
  exit 1
fi

mv -v "$SRC" "$DST_BASE/" 2>&1 | tee -a "$LOG"

echo "✅ اكتمل النقل. المجلد الجديد: $DST" | tee -a "$LOG"
echo "📄 ملف اللوج: $LOG"
