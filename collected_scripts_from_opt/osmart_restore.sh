#!/usr/bin/env bash
set -euo pipefail
FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "[!] اختر ملف .sql.gz صالح"; exit 1
fi
gunzip -c "$FILE" | sudo -u postgres psql -d osmart
echo "[OK] restored"
