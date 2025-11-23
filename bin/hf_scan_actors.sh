#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
DB_PATH="$ROOT/db/meta/hf_actors.db"

# الرمز الموجود فعليًا في الملفات لتمييز العمال/المديرين
# مثال: HF_MARKER='HF_ACTOR:' أو '# HYPERFFACTORY-ACTOR:'
HF_MARKER="${HF_MARKER:-HF_ACTOR:}"

SEARCH_ROOTS=(
  "/root/HyperFFactory"
  "/opt/smartfriend-suite"
  "/opt/ffactory"
)

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت"
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  echo "ℹ️ قاعدة البيانات غير موجودة، استدعاء hf_init_actors_db.sh..."
  "$ROOT/bin/hf_init_actors_db.sh"
fi

echo "🧹 تنظيف الجداول القديمة من hf_actors.db ..."
sqlite3 "$DB_PATH" "DELETE FROM hf_actor_tags; DELETE FROM hf_actor_links; DELETE FROM hf_actors;"

TMPFILE="$(mktemp)"
trap 'rm -f "$TMPFILE"' EXIT

echo "🔍 البحث عن العلامة: $HF_MARKER"
for root in "${SEARCH_ROOTS[@]}"; do
  if [ -d "$root" ]; then
    grep -RIn --exclude-dir='.git' --binary-files=without-match "$HF_MARKER" "$root" || true
  fi
done > "$TMPFILE"

LINES_COUNT=$(wc -l < "$TMPFILE" | tr -d ' ')
echo "📄 عدد الأسطر المعلمة المكتشفة: $LINES_COUNT"

while IFS= read -r line; do
  # شكل السطر:
  # /path/file:lineno:.... HF_MARKER .....
  file="${line%%:*}"
  rest="${line#*:}"
  lineno="${rest%%:*}"
  content="${rest#*:}"

  # تحديد المصدر (HyperFFactory / SmartFriend / ffactory)
  source_root="external"
  case "$file" in
    /root/HyperFFactory/*)   source_root="hyperffactory" ;;
    /opt/smartfriend-suite/*) source_root="smartfriend-suite" ;;
    /opt/ffactory/*)         source_root="ffactory" ;;
  esac

  # النص بعد العلامة
  payload="${content#*${HF_MARKER}}"
  payload="$(echo "$payload" | sed 's/^[[:space:]]*//')"

  # أول توكن يمكن يكون TYPE (MANAGER/WORKER) أو اسم
  first_token="$(echo "$payload" | awk '{print $1}')"
  role_type="UNKNOWN"
  upper_first="$(echo "$first_token" | tr '[:lower:]' '[:upper:]')"

  name=""
  rest_tokens="$payload"

  if [[ "$upper_first" == "MANAGER" || "$upper_first" == "WORKER" ]]; then
    role_type="$upper_first"
    # لو الصيغة: HF_MARKER MANAGER name=... أو MANAGER sf-core ...
    # نحاول نأخذ التوكن الثاني كاسم مبدئي لو مش key=value
    second_token="$(echo "$payload" | awk '{print $2}')"
    if [[ "$second_token" != *=* && -n "$second_token" ]]; then
      name="$second_token"
      rest_tokens="$(echo "$payload" | cut -d' ' -f3-)"
    else
      rest_tokens="$(echo "$payload" | cut -d' ' -f2-)"
    fi
  else
    # نحاول نستنتج من النص
    case "$payload" in
      *MANAGER*|*Manager*|*manager*) role_type="MANAGER" ;;
      *WORKER*|*Worker*|*worker*)    role_type="WORKER" ;;
    esac
    rest_tokens="$payload"
  fi

  # لو لسه الاسم فاضي، نأخذه من basename
  if [ -z "$name" ]; then
    name="$(basename "$file")"
  fi

  name_escaped=$(printf "%s" "$name" | sed "s/'/''/g")
  payload_escaped=$(printf "%s" "$payload" | sed "s/'/''/g")
  marker_escaped=$(printf "%s" "$HF_MARKER" | sed "s/'/''/g")
  file_escaped=$(printf "%s" "$file" | sed "s/'/''/g")
  root_escaped=$(printf "%s" "$source_root" | sed "s/'/''/g")

  sqlite3 "$DB_PATH" <<SQL
INSERT INTO hf_actors (name, role_type, source_root, source_path, tag_marker, tag_payload, created_at)
VALUES (
  '$name_escaped',
  '$role_type',
  '$root_escaped',
  '$file_escaped',
  '$marker_escaped',
  '$payload_escaped',
  datetime('now','localtime')
);
SQL

  actor_id="$(sqlite3 "$DB_PATH" "SELECT id FROM hf_actors WHERE name='$name_escaped' AND source_path='$file_escaped' ORDER BY id DESC LIMIT 1;")"

  # تحليل key=value من بقية التوكنات إلى جدول hf_actor_tags
  for token in $rest_tokens; do
    if [[ "$token" == *"="* ]]; then
      key="${token%%=*}"
      value="${token#*=}"
      key_esc=$(printf "%s" "$key" | sed "s/'/''/g")
      val_esc=$(printf "%s" "$value" | sed "s/'/''/g")
      sqlite3 "$DB_PATH" <<SQL
INSERT INTO hf_actor_tags (actor_id, key, value)
VALUES ($actor_id, '$key_esc', '$val_esc');
SQL
    fi
  done

done < "$TMPFILE"

echo "✅ تم تحديث جدول hf_actors من التاج: $HF_MARKER"
echo "📊 توزيع حسب النوع:"
sqlite3 "$DB_PATH" "SELECT role_type, COUNT(*) AS cnt FROM hf_actors GROUP BY role_type ORDER BY cnt DESC;"
