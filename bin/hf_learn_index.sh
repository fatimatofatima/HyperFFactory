#!/usr/bin/env bash
# HyperFFactory - Learning Layer: Scripts Indexer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
LEARN_DIR="$ROOT_DIR/learning"
PATTERNS_FILE="$LEARN_DIR/learning_patterns.cfg"
OUT_CSV="$LEARN_DIR/scripts_index.csv"

mkdir -p "$LEARN_DIR"

if [[ ! -f "$PATTERNS_FILE" ]]; then
  echo "❌ ملف الأنماط غير موجود: $PATTERNS_FILE" >&2
  exit 1
fi

echo "id,role,priority,system,category,name,path" > "$OUT_CSV"
id=0

classify_and_add() {
  local path="$1"
  local name system category role priority

  name="$(basename "$path")"
  system="other"
  category="uncategorized"
  role="worker"
  priority=5

  # تحديد النظام حسب المسار
  case "$path" in
    "$ROOT_DIR"/*) system="hyper" ;;
    /opt/smartfriend-suite/*) system="smartfriend" ;;
    /opt/ffactory/*) system="ffactory" ;;
  esac

  # تطبيق أنماط التعلّم
  while IFS='|' read -r pattern p_system p_category p_role p_priority; do
    # تخطي السطور الفارغة أو المعلّقات
    [[ -z "${pattern:-}" ]] && continue
    [[ "$pattern" =~ ^# ]] && continue

    if [[ "$name" == $pattern ]]; then
      [[ "${p_system:-}" != "-" ]] && system="$p_system"
      category="$p_category"
      role="$p_role"
      priority="$p_priority"
      break
    fi
  done < "$PATTERNS_FILE"

  id=$((id + 1))

  # منع الفواصل داخل CSV
  local name_sanitized="${name//,/ }"
  local path_sanitized="${path//,/ }"

  echo "$id,$role,$priority,$system,$category,$name_sanitized,$path_sanitized" >> "$OUT_CSV"
}

scan_dir() {
  local base="$1"
  [[ -d "$base" ]] || return 0

  # البحث عن سكربتات شيل أو ملفات تنفيذية
  find "$base" -maxdepth 6 -type f \( -name '*.sh' -o -perm -u+x \) 2>/dev/null \
    | sort \
    | while read -r f; do
        classify_and_add "$f"
      done
}

echo "🔎 بناء فهرس السكربتات (Learning Index) ..."
scan_dir "$ROOT_DIR/bin"
scan_dir "$ROOT_DIR/scripts"
scan_dir "$ROOT_DIR/collected_scripts/sh_scripts"
scan_dir "/opt/smartfriend-suite"
scan_dir "/opt/ffactory"

echo "✅ تمت كتابة الفهرس إلى: $OUT_CSV"
