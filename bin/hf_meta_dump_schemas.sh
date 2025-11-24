#!/usr/bin/env bash
# HyperFFactory – Dump Meta DB Schemas
# قراءة فقط: لا يغيّر أي DB، فقط يكتب ملفات .sql تحت sql/

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

DB_DIR="db/meta"
SQL_DIR="sql"
mkdir -p "$SQL_DIR"

declare -A MAP=(
  [hf_quality.db]="${SQL_DIR}/meta_hf_quality_schema.sql"
  [hf_learning.db]="${SQL_DIR}/meta_hf_learning_schema.sql"
  [hf_errors.db]="${SQL_DIR}/meta_hf_errors_schema.sql"
  [hf_ops_meta.db]="${SQL_DIR}/meta_hf_ops_meta_schema.sql"
)

echo "====================================================="
echo "[META-SCHEMA] Dumping SQLite schemas from db/meta → ${SQL_DIR}"
echo "ROOT : ${ROOT}"
echo "TIME : $(date +'%Y-%m-%d %H:%M:%S')"
echo "====================================================="
echo

for db in "${!MAP[@]}"; do
  src="${DB_DIR}/${db}"
  out="${MAP[$db]}"

  if [[ -f "$src" ]]; then
    echo "[OK]  Found DB: ${src}"
    echo "     → Writing schema to: ${out}"
    sqlite3 "$src" ".schema" > "$out"
  else
    echo "[SKIP] DB not found: ${src}"
  fi

  echo
done

echo "-----------------------------------------------------"
echo "[DONE] Schema dump finished. Check files under: ${SQL_DIR}"
echo "-----------------------------------------------------"
