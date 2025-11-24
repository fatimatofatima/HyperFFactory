#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
META_DB="$ROOT/meta/hyper_meta.db"

echo "=== hyper_meta.db (أرقام الميتا المسجلة) ==="
sqlite3 "$META_DB" "
  SELECT role,
         COUNT(*)              AS files_meta,
         ROUND(SUM(size_mb),2) AS size_mb_meta 
  FROM db_files
  GROUP BY role
  ORDER BY size_mb_meta DESC;
"

echo
echo "=== الحجم الفعلي على الديسك (للملفات الموجودة فقط) ==="

TMP="$(mktemp)"
sqlite3 -separator '|' "$META_DB" "
  SELECT role, file_path
  FROM db_files
  WHERE file_path IS NOT NULL
    AND file_path != '';
" > "$TMP"

declare -A COUNT_REAL
declare -A SIZE_REAL

while IFS='|' read -r role path; do
  # تخطي الأسطر الفارغة أو المسارات غير الموجودة
  [[ -z "$path" ]] && continue
  [[ ! -f "$path" ]] && continue

  # توحيد الدور لو فاضي
  if [[ -z "$role" ]]; then
    role="unknown"
  fi

  # حجم الملف بالبايت
  bytes=$(du -b "$path" 2>/dev/null | cut -f1 || echo 0)

  # تهيئة العدادات لهذا الدور لو أول مرة
  if [[ -z "${COUNT_REAL["$role"]+x}" ]]; then
    COUNT_REAL["$role"]=0
    SIZE_REAL["$role"]=0
  fi

  COUNT_REAL["$role"]=$(( COUNT_REAL["$role"] + 1 ))
  SIZE_REAL["$role"]=$(( SIZE_REAL["$role"] + bytes ))
done < "$TMP"

rm -f "$TMP"

printf "\n%-20s %10s %15s\n" "ROLE" "FILES_OK" "SIZE_MB_REAL"
printf "%-20s %10s %15s\n" "--------------------" "----------" "---------------"

total_bytes=0
for role in "${!SIZE_REAL[@]}"; do
  bytes=${SIZE_REAL["$role"]}
  total_bytes=$(( total_bytes + bytes ))
  mb=$(awk -v b="$bytes" 'BEGIN{printf "%.2f", b/1024/1024}')
  printf "%-20s %10s %15s\n" "$role" "${COUNT_REAL["$role"]}" "$mb"
done

total_mb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.2f", b/1024/1024}')
echo
echo "TOTAL_REAL_MB = $total_mb"
