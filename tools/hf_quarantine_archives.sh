#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
ARCHIVE_ROOT="/root/HyperFFactory_archives"
TS="$(date '+%Y%m%d_%H%M%S')"
LOG="reports/hf_quarantine_archives_${TS}.log"

APPLY=0
if [[ "${1-}" == "--apply" ]]; then
  APPLY=1
fi

cd "$ROOT"
mkdir -p "$ARCHIVE_ROOT"
mkdir -p "$(dirname "$LOG")"

echo "============================================================" | tee -a "$LOG"
echo "[HF] Quarantine archives out of Live Tree" | tee -a "$LOG"
echo "ROOT          : $ROOT" | tee -a "$LOG"
echo "ARCHIVE_ROOT  : $ARCHIVE_ROOT" | tee -a "$LOG"
echo "APPLY (move?) : $APPLY" | tee -a "$LOG"
echo "LOG           : $LOG" | tee -a "$LOG"
echo "============================================================" | tee -a "$LOG"

# 1) مسارات ثابتة معروفة إنها أرشيفات / Snapshots
declare -a FIXED_DIRS=(
  "imported/opt/report"
  "imported/opt/COMPLETE_CODE_BACKUP"
  "imported/opt/deepseek"
  "imported/opt/smartfriend-suite/imported"
)

# 2) مسارات ديناميكية معروفة إنها Legacy أو motd backup
shopt -s nullglob
DYNAMIC_DIRS=( motd_backup_* motd_backup_hide_default_* opt/_root_legacy_* )
shopt -u nullglob

declare -a CANDIDATES=()

for d in "${FIXED_DIRS[@]}"; do
  if [[ -e "$d" ]]; then
    CANDIDATES+=( "$d" )
  fi
done

for d in "${DYNAMIC_DIRS[@]}"; do
  if [[ -e "$d" ]]; then
    CANDIDATES+=( "$d" )
  fi
done

# إزالة التكرار من قائمة المرشحين (بسبب تطابق أكثر من نمط على نفس المجلد)
if [[ "${#CANDIDATES[@]}" -gt 0 ]]; then
  declare -A SEEN=()
  declare -a UNIQUE=()
  for rel in "${CANDIDATES[@]}"; do
    if [[ -n "${SEEN[$rel]-}" ]]; then
      continue
    fi
    SEEN[$rel]=1
    UNIQUE+=( "$rel" )
  done
  CANDIDATES=( "${UNIQUE[@]}" )
fi

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
  echo "[HF] لا يوجد أي مجلدات أرشيف/Legacy مطابقة للأنماط المحددة." | tee -a "$LOG"
  exit 0
fi

echo "[HF] المجلدات المرشحة للنقل خارج الـ Live Tree:" | tee -a "$LOG"
for d in "${CANDIDATES[@]}"; do
  echo "  - $d" | tee -a "$LOG"
done

echo "------------------------------------------------------------" | tee -a "$LOG"

for rel in "${CANDIDATES[@]}"; do
  SRC="${ROOT}/${rel}"
  DEST="${ARCHIVE_ROOT}/${rel}"

  echo "[HF] معالجة: $SRC" | tee -a "$LOG"
  echo "      -> $DEST" | tee -a "$LOG"

  if [[ $APPLY -eq 1 ]]; then
    mkdir -p "$(dirname "$DEST")"
    mv "$SRC" "$DEST"
    echo "      ✅ تم النقل فعلياً." | tee -a "$LOG"
  else
    echo "      (DRY-RUN) لم يتم النقل، فقط عرض ما سيحدث." | tee -a "$LOG"
  fi

  echo "------------------------------------------------------------" | tee -a "$LOG"
done

echo "[HF] انتهى الفحص/النقل. راجع اللوج: $LOG" | tee -a "$LOG"
