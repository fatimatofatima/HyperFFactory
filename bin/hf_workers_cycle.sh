#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

LOG_DIR="$ROOT/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hf_workers_cycle.log"

TS="$(date '+%Y-%m-%d %H:%M:%S')"

{
  echo
  echo "==== HF WORKERS CYCLE ${TS} ===="
  echo "ROOT : ${ROOT}"
  echo "LOG  : ${LOG_FILE}"
} >> "$LOG_FILE"

# تفعيل nullglob حتى لا نلف على أسماء غير موجودة
shopt -s nullglob

echo "[INFO] بدء دورة العمال..." >> "$LOG_FILE"

# 1) ملخص حالة العمال (إن وُجد سكربت runtime_status)
if [[ -x bin/hf_workers_runtime_status.sh ]]; then
  echo "[INFO] running hf_workers_runtime_status.sh" >> "$LOG_FILE"
  if ! bin/hf_workers_runtime_status.sh >> "$LOG_FILE" 2>&1; then
    echo "[ERROR] hf_workers_runtime_status.sh انتهى بحالة فشل (راجع التفاصيل أعلاه)." >> "$LOG_FILE"
  else
    echo "[INFO] hf_workers_runtime_status.sh اكتمل بنجاح." >> "$LOG_FILE"
  fi
else
  echo "[WARN] bin/hf_workers_runtime_status.sh غير موجود أو غير قابل للتنفيذ." >> "$LOG_FILE"
fi

# 2) تشغيل كل عامل من نمط hf_worker_*.sh إن وُجد
workers=(bin/hf_worker_*.sh)
if (( ${#workers[@]} == 0 )); then
  echo "[INFO] لا توجد سكربتات عمال مطابقة للنمط bin/hf_worker_*.sh" >> "$LOG_FILE"
else
  for w in "${workers[@]}"; do
    if [[ -x "$w" ]]; then
      echo "[INFO] تشغيل العامل: $w" >> "$LOG_FILE"
      if ! "$w" >> "$LOG_FILE" 2>&1; then
        echo "[ERROR] العامل فشل: $w (راجع السطور السابقة في هذا التقرير)." >> "$LOG_FILE"
      else
        echo "[INFO] العامل اكتمل بنجاح: $w" >> "$LOG_FILE"
      fi
    else
      echo "[WARN] ملف عامل غير قابل للتنفيذ (تجاهله): $w" >> "$LOG_FILE"
    fi
  done
fi

echo "[INFO] انتهاء دورة العمال." >> "$LOG_FILE"

