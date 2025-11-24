#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

BACK_BASE="$ROOT/data/backups/hf"
mkdir -p "$BACK_BASE"

ts="$(date +%Y%m%d_%H%M%S)"
archive="$BACK_BASE/hyper-factory_full_${ts}.tar.zst"

echo "====================================================="
echo "HyperFFactory – Full Data Backup"
echo "ROOT    : $ROOT"
echo "ARCHIVE : $archive"
echo "TIME    : $ts"
echo "====================================================="

# إنشاء الأرشيف (داتا فقط – الكود نفسه تحت git)
tar --use-compress-program="zstd -T0 -19" \
    -cf "$archive" \
    --exclude="./backups_legacy" \
    --exclude="./data/backups" \
    ./db \
    ./sql \
    ./config \
    ./reports \
    ./data

echo
echo "== Backup created =="
ls -lh "$archive" || true

echo
if [ -x "tools/hf_backups_quick_report.sh" ]; then
  echo "== Running hf_backups_quick_report.sh =="
  tools/hf_backups_quick_report.sh || true
else
  echo "hf_backups_quick_report.sh غير موجود أو غير قابل للتنفيذ."
fi

echo
echo "== Done =="
