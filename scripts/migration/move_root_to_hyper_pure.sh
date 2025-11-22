#!/usr/bin/env bash
set -euo pipefail

BASE_SRC="/root"
BASE_DST="/root/HyperFFactory/imported/root"
LOG_DIR="/root/HyperFFactory/docs"

mkdir -p "$BASE_DST" "$LOG_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$LOG_DIR/root_move_pure_${TS}.log"

echo "== نقل كل الملفات/المجلدات الظاهرة من /root إلى $BASE_DST (بدون symlinks) ==" | tee "$LOG"
echo "ملف اللوج: $LOG" | tee -a "$LOG"
echo | tee -a "$LOG"

# تجميع كل العناصر في /root (عمق 1)
mapfile -t ITEMS < <(find "$BASE_SRC" -maxdepth 1 -mindepth 1)

MOVE_LIST=()

for item in "${ITEMS[@]}"; do
  name="$(basename "$item")"

  # تخطي HyperFFactory نفسه
  if [[ "$name" == "HyperFFactory" ]]; then
    echo "تخطي مجلد HyperFFactory نفسه: $name" | tee -a "$LOG"
    continue
  fi

  # تخطي أي عنصر مخفي (يبدأ بـ .)
  if [[ "$name" == .* ]]; then
    echo "تخطي عنصر مخفي: $name" | tee -a "$LOG"
    continue
  fi

  MOVE_LIST+=("$item")
done

TOTAL="${#MOVE_LIST[@]}"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "لا يوجد عناصر لنقلها من /root بعد تطبيق القواعد." | tee -a "$LOG"
  exit 0
fi

echo "سيتم نقل $TOTAL عنصراً من /root إلى $BASE_DST (mv فعلي بدون أي روابط)." | tee -a "$LOG"
echo | tee -a "$LOG"

for src in "${MOVE_LIST[@]}"; do
  name="$(basename "$src")"
  echo " - $name" | tee -a "$LOG"
done

echo | tee -a "$LOG"
echo "تحذير: العملية ستنقل كل الملفات/المجلدات الظاهرة من /root إلى داخل HyperFFactory." | tee -a "$LOG"
echo "للتأكيد النهائي اكتب YES بالحروف الكبيرة ثم Enter:" | tee -a "$LOG"
read -r CONFIRM

if [[ "$CONFIRM" != "YES" ]]; then
  echo "تم الإلغاء من المستخدم." | tee -a "$LOG"
  exit 1
fi

MOVED=0
ERRORS=0

for src in "${MOVE_LIST[@]}"; do
  name="$(basename "$src")"
  dst="$BASE_DST/$name"

  echo ">>> mv \"$src\" -> \"$dst\"" | tee -a "$LOG"
  if mv "$src" "$dst"; then
    echo "✓ تم نقل $name" | tee -a "$LOG"
    ((MOVED++))
  else
    echo "❌ فشل في نقل $name" | tee -a "$LOG"
    ((ERRORS++))
  fi
done

echo | tee -a "$LOG"
echo "ملخص العملية:" | tee -a "$LOG"
echo "  تم نقل:   $MOVED" | tee -a "$LOG"
echo "  أخطاء:    $ERRORS" | tee -a "$LOG"
echo | tee -a "$LOG"
echo "اكتملت عملية النقل. راجع اللوج للتفاصيل: $LOG" | tee -a "$LOG"
