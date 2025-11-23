#!/usr/bin/env bash
# HyperFFactory – Check file/dir list against actual tree
# الاستخدام:
#   tools/hf_check_paths_from_list.sh /root/HyperFFactory قائمة_المسارات.txt
# أو:
#   tools/hf_check_paths_from_list.sh ROOT LIST

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
LIST_FILE="${2:-}"

if [ -z "${LIST_FILE}" ]; then
  echo "Usage: $0 ROOT_PATH LIST_FILE"
  echo "مثال: $0 /root/HyperFFactory reports/paths_to_check.txt"
  exit 1
fi

if [ ! -d "$ROOT" ]; then
  echo "❌ ROOT غير موجود: $ROOT"
  exit 1
fi

if [ ! -f "$LIST_FILE" ]; then
  echo "❌ ملف القائمة غير موجود: $LIST_FILE"
  exit 1
fi

cd "$ROOT"

echo "=================================================="
echo "📂 HyperFFactory – Paths Existence Check"
echo "ROOT : $ROOT"
echo "LIST : $LIST_FILE"
echo "TIME : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

total=0
present=0
missing=0

while IFS= read -r raw; do
  line="$raw"

  # إزالة بادئات git مثل "?? " أو "M " أو "A " ...
  line="${line#?? }"
  line="${line#M }"
  line="${line#A }"
  line="${line#D }"
  line="${line#R }"

  # إزالة المسافات في أول السطر
  line="$(echo "$line" | sed 's/^[[:space:]]*//')"

  # تجاهل الفراغات والتعليقات / نصوص واضحة ليست مسارات
  [ -z "$line" ] && continue
  case "$line" in
    \#*|"> "* ) continue ;;
  esac

  # لو السطر لا يحتوي على "/" وليس imported*/opt/* اعتبره نص عادي وليس path
  if [[ "$line" != *"/"* ]] && [[ "$line" != imported* ]] && [[ "$line" != opt/* ]]; then
    continue
  fi

  path="$line"

  # تحديد المسار الفعلي
  if [[ "$path" = /* ]]; then
    test_path="$path"
  else
    test_path="$ROOT/$path"
  fi

  ((total++))

  if [ -e "$test_path" ]; then
    echo "✅ EXISTS   $path"
    ((present++))
  else
    echo "❌ MISSING  $path"
    ((missing++))
  fi

done < "$LIST_FILE"

echo "--------------------------------------------------"
echo "📊 SUMMARY"
echo "  الإجمالي : $total"
echo "  موجود    : $present"
echo "  مفقود    : $missing"
echo "=================================================="
