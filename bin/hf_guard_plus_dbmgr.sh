#!/usr/bin/env bash
# HyperFFactory – Guard + DB Manager + Snapshot Runner
# - يربط بين:
#   * bin/hf_guard.sh               (الحراسة العامة + المهام)
#   * tools/hf_db_manager_run.sh    (تشغيل مهام hf_db_manager على meta_dbs)
#   * tools/hf_status_snapshot.sh   (تقرير سريع للحالة)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
cd "$ROOT"

TS="$(date '+%Y-%m-%dT%H:%M:%S%z')"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/hf_guard_plus_dbmgr_${TS}.log"

{
  echo "$TS [GUARD+] =================================================="
  echo "$TS [GUARD+] HyperFFactory – Guard + DB Manager + Snapshot"
  echo "$TS [GUARD+] ROOT = $ROOT"
  echo "$TS [GUARD+] MODE = ${1:-CHECK_ONLY}"

  # 1) تشغيل الـ Main Guard (مع وسيط --fix-tree لو مررته)
  if [[ -x bin/hf_guard.sh ]]; then
    echo "$TS [GUARD+] STEP 1: running hf_guard.sh $* ..."
    if ! bash bin/hf_guard.sh "$@"; then
      echo "$TS [GUARD+][WARN] hf_guard.sh انتهى بتحذير/خطأ – راجع لوجه الخاص." >&2
    fi
  else
    echo "$TS [GUARD+][WARN] bin/hf_guard.sh غير موجود أو غير قابل للتنفيذ."
  fi

  # 2) تشغيل hf_db_manager_run.sh (ينفّذ مهام hf_db_manager على meta_dbs)
  if [[ -x tools/hf_db_manager_run.sh ]]; then
    echo "$TS [GUARD+] STEP 2: running hf_db_manager_run.sh ..."
    if ! bash tools/hf_db_manager_run.sh; then
      echo "$TS [GUARD+][WARN] hf_db_manager_run.sh انتهى بتحذير/خطأ – راجع اللوج." >&2
    fi
  else
    echo "$TS [GUARD+][WARN] tools/hf_db_manager_run.sh غير موجود أو غير قابل للتنفيذ."
  fi

  # 3) Snapshot للحالة (يُحفظ في reports + يطلع على الشاشة لو حابب)
  if [[ -x tools/hf_status_snapshot.sh ]]; then
    SNAP_REPORT="$ROOT/reports/hf_status_snapshot_$(date '+%Y%m%d_%H%M%S').txt"
    mkdir -p "$ROOT/reports"
    echo "$TS [GUARD+] STEP 3: running hf_status_snapshot.sh → $SNAP_REPORT ..."
    if ! bash tools/hf_status_snapshot.sh | tee "$SNAP_REPORT"; then
      echo "$TS [GUARD+][WARN] hf_status_snapshot.sh انتهى بتحذير/خطأ – راجع التقرير." >&2
    fi
  else
    echo "$TS [GUARD+][WARN] tools/hf_status_snapshot.sh غير موجود أو غير قابل للتنفيذ."
  fi

  echo "$TS [GUARD+] DONE."
  echo "$TS [GUARD+] =================================================="
} | tee "$LOG"
