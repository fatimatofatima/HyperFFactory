#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/root/HyperFFactory/_root_legacy_20251122_023221/hf_backups"
N="${1:-10}"  # عدد النسخ التي سيتم فحصها (افتراضي 10)
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
REPORT="/root/HyperFFactory/hf_backups_report_${TIMESTAMP}.txt"

mkdir -p "$(dirname "$REPORT")"

{
  echo "=== HyperFFactory Backups Report ==="
  echo "Backup dir : $BACKUP_DIR"
  echo "Generated  : $(date)"
  echo "Max files  : $N"
  echo

  echo "--- Disk usage (df -h /) ---"
  df -h /
  echo

  echo "--- Last $N hyper-factory_full*.tar.zst (ordered by mtime desc) ---"
} | tee "$REPORT"

# جمع آخر N ملفات
mapfile -t FILES < <(ls -1t "$BACKUP_DIR"/hyper-factory_full_*.tar.zst 2>/dev/null | head -n "$N" || true)

if ((${#FILES[@]} == 0)); then
  {
    echo "❌ لا توجد ملفات hyper-factory_full_*.tar.zst في:"
    echo "   $BACKUP_DIR"
  } | tee -a "$REPORT"
  exit 0
fi

{
  nl -w2 -s'. ' <<<"$(printf '%s\n' "${FILES[@]}")"
  echo
} | tee -a "$REPORT"

idx=0
for f in "${FILES[@]}"; do
  idx=$((idx+1))
  {
    echo "============================================================"
    echo "### [$idx] $f"
    echo "Size     : $(du -h "$f" | cut -f1)"
  } | tee -a "$REPORT"

  # اختبار سلامة zstd بدون فك فعلي
  if zstd -t "$f" >/dev/null 2>&1; then
    echo "Integrity: OK (zstd -t passed)" | tee -a "$REPORT"
    echo "Sample tar content (first 40 entries):" | tee -a "$REPORT"
    # عرض عينة بدون فك للقرص
    if ! zstdcat "$f" | tar -tf - 2>&1 | head -n 40 | tee -a "$REPORT"; then
      echo "⚠️  tar -tf أعطى خطأ أثناء القراءة (ربما مشكلة في الأرشيف)" | tee -a "$REPORT"
    fi
  else
    echo "Integrity: FAILED (zstd -t failed)" | tee -a "$REPORT"
  fi

  echo | tee -a "$REPORT"
done

{
  echo "============================================================"
  echo "تم حفظ التقرير في:"
  echo "  $REPORT"
} | tee -a "$REPORT"
