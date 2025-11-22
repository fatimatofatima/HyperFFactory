#!/usr/bin/env bash
set -euo pipefail

# تحديد جذر المشروع اعتمادًا على مكان السكربت
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "PROJECT_ROOT = ${PROJECT_ROOT}"

# مسارات البحث عن نسخ Hyper Factory داخل المشروع
search_roots=(
  "${PROJECT_ROOT}"
  "${PROJECT_ROOT}/backups"
  "${PROJECT_ROOT}/backups_legacy"
  "${PROJECT_ROOT}/backups_legacy/extracted"
)

valid_roots=()
for d in "${search_roots[@]}"; do
  if [ -d "$d" ]; then
    valid_roots+=("$d")
  fi
done

if [ "${#valid_roots[@]}" -eq 0 ]; then
  echo "لا توجد أي مجلدات نسخ احتياطي معروفة داخل المشروع."
  exit 1
fi

echo
echo "مسارات البحث عن نسخ hyper-factory:"
for d in "${valid_roots[@]}"; do
  echo "  - $d"
done

echo
echo "البحث عن ملفات: hyper-factory-backup-*.tar.zst ..."
mapfile -t lines < <(
  find "${valid_roots[@]}" \
    -maxdepth 6 \
    -type f \
    -name 'hyper-factory-backup-*.tar.zst' \
    -printf '%T@ %p\n' 2>/dev/null | sort -n
)

if [ "${#lines[@]}" -eq 0 ]; then
  echo "لا توجد أي ملفات hyper-factory-backup-*.tar.zst في المسارات المحددة."
  exit 0
fi

echo
echo "أحدث نسخ Hyper Factory (من الأقدم إلى الأحدث):"
printf '%-3s | %-19s | %-10s | %s\n' "#" "تاريخ الملف" "الحجم" "المسار"
printf '----+---------------------+------------+---------------------------------------------\n'

paths=()
for i in "${!lines[@]}"; do
  line="${lines[$i]}"
  ts="${line%% *}"
  path="${line#* }"
  paths+=("$path")

  epoch=${ts%.*}
  dt="$(date -d "@${epoch}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "${ts}")"

  size_bytes=$(stat -c '%s' "$path" 2>/dev/null || echo 0)

  human="${size_bytes}B"
  if [ "$size_bytes" -ge 1073741824 ]; then
    human=$(awk -v b="$size_bytes" 'BEGIN{printf "%.2fG", b/1073741824}')
  elif [ "$size_bytes" -ge 1048576 ]; then
    human=$(awk -v b="$size_bytes" 'BEGIN{printf "%.2fM", b/1048576}')
  elif [ "$size_bytes" -ge 1024 ]; then
    human=$(awk -v b="$size_bytes" 'BEGIN{printf "%.2fK", b/1024}')
  fi

  printf '%-3d | %-19s | %-10s | %s\n' "$((i+1))" "$dt" "$human" "$path"
done

echo
echo "ملخص:"
echo "  - عدد النسخ المكتشفة: ${#paths[@]}"

last_index=$(( ${#paths[@]} - 1 ))
echo "  - آخر نسخة: ${paths[$last_index]}"

# فحص سلامة آخر 3 نسخ (لو zstd متوفر)
if command -v zstd >/dev/null 2>&1; then
  to_check=3
  if [ "${#paths[@]}" -lt "$to_check" ]; then
    to_check="${#paths[@]}"
  fi

  echo
  echo "فحص سلامة آخر ${to_check} ملف باستخدام: zstd -t"

  start_index=$(( ${#paths[@]} - to_check ))
  check_counter=1
  for (( j=start_index; j<${#paths[@]}; j++ )); do
    f="${paths[$j]}"
    echo "[${check_counter}] zstd -t \"$f\""
    if zstd -t "$f" >/dev/null 2>&1; then
      echo "    سليم"
    else
      echo "    به مشكلة (zstd -t فشل)"
    fi
    check_counter=$((check_counter+1))
  done
else
  echo
  echo "أداة zstd غير مثبتة؛ لن يتم فحص سلامة الملفات، فقط عرضها."
fi
