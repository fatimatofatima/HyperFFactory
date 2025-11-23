#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
BACKUP_DIR="$ROOT/data/backups/hf"
REPORTS_DIR="$ROOT/reports/backups_audit"

echo "===== HyperFFactory – Backups Quick Report ====="
date
echo "ROOT: $ROOT"
echo

# 1) فحص مجلدات الباك أب
if [ -d "$BACKUP_DIR" ]; then
  echo "== Backup directories under $BACKUP_DIR =="
  ls -1 "$BACKUP_DIR"
  echo

  echo "== Latest backup directories (by mtime) =="
  ls -1dt "$BACKUP_DIR"/* 2>/dev/null | head -n 10 || true
  echo
else
  echo "!! Backup directory $BACKUP_DIR not found"
  echo
fi

# 2) تشغيل فحص الباك أب التفصيلي لو متوفر
if [ -x "$ROOT/tools/check_hf_backups.sh" ]; then
  echo "== Running tools/check_hf_backups.sh =="
  "$ROOT/tools/check_hf_backups.sh" || echo "!! check_hf_backups.sh returned non-zero exit code"
  echo
else
  echo "!! Missing $ROOT/tools/check_hf_backups.sh (skipping detailed check)"
  echo
fi

# 3) عرض أحدث تقرير hf_backups_report_*.txt في الجذر
LATEST_ROOT_REPORT=$(ls -1t "$ROOT"/hf_backups_report_*.txt 2>/dev/null | head -n 1 || true)
if [ -n "${LATEST_ROOT_REPORT:-}" ]; then
  echo "== Latest root backup report: $(basename "$LATEST_ROOT_REPORT") =="
  head -n 80 "$LATEST_ROOT_REPORT"
  echo
else
  echo "!! No hf_backups_report_*.txt found in $ROOT"
  echo
fi

# 4) عرض أحدث تقرير من reports/backups_audit
if [ -d "$REPORTS_DIR" ]; then
  LATEST_AUDIT_REPORT=$(ls -1t "$REPORTS_DIR"/*.txt 2>/dev/null | head -n 1 || true)
  if [ -n "${LATEST_AUDIT_REPORT:-}" ]; then
    echo "== Latest backups_audit report: $(basename "$LATEST_AUDIT_REPORT") =="
    head -n 80 "$LATEST_AUDIT_REPORT"
    echo
  else
    echo "!! No .txt reports in $REPORTS_DIR"
    echo
  fi
else
  echo "!! Backups audit directory $REPORTS_DIR not found"
  echo
fi

echo "===== END OF BACKUPS QUICK REPORT ====="
