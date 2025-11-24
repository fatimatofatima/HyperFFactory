#!/usr/bin/env bash
# HyperFFactory – Backup Policy Snapshot (P2-4)
# لا ينفّذ نسخ احتياطية فعلية؛ فقط:
# - يلخّص المجلدات الحرجة مع أحجامها.
# - يشغّل سكربتات الباك أب الموجودة (report-only).
# - يكتب تقرير في reports/ يمكن اعتباره نواة سياسة رسمية.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPORT_DIR}/hf_backup_policy_snapshot_${TS}.log"

CRITICAL_DIRS=(
  "db"
  "db/meta"
  "sql"
  "config"
  "reports"
  "backups_legacy"
  "data"
)

{
  echo "====================================================="
  echo "[BACKUP-POLICY] HyperFFactory – Backup Policy Snapshot"
  echo "ROOT : ${ROOT}"
  echo "TIME : ${TS}"
  echo "LOG  : ${LOG}"
  echo "====================================================="
  echo
  echo "1) Critical Directories Size Overview (du -sh)"
  echo "-----------------------------------------------------"

  for d in "${CRITICAL_DIRS[@]}"; do
    if [[ -d "$d" ]]; then
      size=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
      echo "[OK]  $d  =>  $size"
    else
      echo "[MISS] $d (directory not found)"
    fi
  done

  echo
  echo "-----------------------------------------------------"
  echo "2) Running existing backup-related tools (if present)"
  echo "-----------------------------------------------------"

  if [[ -x "tools/check_hf_backups.sh" ]]; then
    echo "[RUN] tools/check_hf_backups.sh"
    tools/check_hf_backups.sh || echo "[WARN] check_hf_backups.sh returned non-zero exit code."
  else
    echo "[SKIP] tools/check_hf_backups.sh not found or not executable."
  fi

  echo
  if [[ -x "tools/hf_backups_quick_report.sh" ]]; then
    echo "[RUN] tools/hf_backups_quick_report.sh"
    tools/hf_backups_quick_report.sh || echo "[WARN] hf_backups_quick_report.sh returned non-zero exit code."
  else
    echo "[SKIP] tools/hf_backups_quick_report.sh not found or not executable."
  fi

  echo
  echo "-----------------------------------------------------"
  echo "3) Backup Policy Draft (human-readable)"
  echo "-----------------------------------------------------"
  echo "- Scope:"
  echo "  * قاعدة البيانات: db/, db/meta/"
  echo "  * نماذج البيانات والـ SQL: sql/"
  echo "  * إعدادات المصنع: config/"
  echo "  * التقارير والتحليلات: reports/"
  echo "  * الأرشيفات القديمة: backups_legacy/ (حسب الحاجة)"
  echo
  echo "- Recommended Backup Frequency (اقتراح مبدئي – لا يُنفّذ تلقائيًا):"
  echo "  * يوميًّا: db/, db/meta/, config/"
  echo "  * أسبوعيًّا: sql/, reports/"
  echo "  * شهريًّا أو عند التغيير الكبير: backups_legacy/, data/"
  echo
  echo "- Execution Pattern (للتوثيق فقط):"
  echo "  * rsync/ssh أو tar.zst إلى موقع آمن خارجي."
  echo "  * استخدام check_hf_backups.sh لمراقبة الحالة."
  echo "  * استخدام hf_backups_quick_report.sh لتقارير مختصرة."
  echo
  echo "[NOTE] هذا السكربت لا ينفّذ أي عملية Backup فعلية؛ فقط Snapshot للسياسة + تشغيل أدوات الفحص."
  echo "-----------------------------------------------------"
} | tee "$LOG"

echo
echo "[BACKUP-POLICY] Snapshot report saved to: $LOG"
