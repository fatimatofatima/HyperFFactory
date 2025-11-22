#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"

echo "ROOT: $ROOT"
echo "فحص قواعد البيانات في all_legacy_dbs ..."

if [[ ! -d "$ROOT/all_legacy_dbs" ]]; then
  echo "لا يوجد مجلد $ROOT/all_legacy_dbs"
  exit 1
fi

python3 "$ROOT/tools/hyper_scan_dbs.py"

echo
echo "أحدث ملفات تقرير (tsv / txt):"
ls -1t "$ROOT"/db_inventory_* 2>/dev/null | head -n 10 || true

LAST_SUMMARY="$(ls -1t "$ROOT"/db_inventory_summary_*.txt 2>/dev/null | head -n 1 || true)"
if [[ -n "$LAST_SUMMARY" ]]; then
  echo
  echo "===== مقتطف من الملخص ====="
  head -n 80 "$LAST_SUMMARY"
fi
