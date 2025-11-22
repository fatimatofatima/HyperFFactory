#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

echo "=== SmartFriend – Fix knowledge_base.deleted_at column ==="
echo "[*] قاعدة البيانات: $DB"
echo

if [ ! -f "$DB" ]; then
  echo "[ERROR] DB غير موجود: $DB" >&2
  exit 1
fi

echo "[1] عرض أعمدة knowledge_base الحالية:"
sqlite3 "$DB" "PRAGMA table_info(knowledge_base);" || {
  echo "[ERROR] جدول knowledge_base غير موجود!" >&2
  exit 1
}
echo

# هل العمود deleted_at موجود؟
HAS_DELETED_AT="$(sqlite3 "$DB" "PRAGMA table_info(knowledge_base);" | awk -F'|' '$2 == \"deleted_at\" {print 1}' || true)"

if [ "$HAS_DELETED_AT" = "1" ]; then
  echo "[OK] العمود deleted_at موجود بالفعل – لا حاجة لتعديل."
else
  echo "[2] العمود deleted_at غير موجود – سيتم إضافته..."
  # نضيفه كنص اختياري (NULL by default)
  sqlite3 "$DB" "ALTER TABLE knowledge_base ADD COLUMN deleted_at TEXT;" || {
    echo "[ERROR] فشل ALTER TABLE لإضافة deleted_at!" >&2
    exit 1
  }
  echo "[OK] تم إضافة العمود deleted_at بنجاح."
fi

echo
echo "[3] السكيمة بعد التعديل:"
sqlite3 "$DB" "PRAGMA table_info(knowledge_base);"

echo
echo "[4] اختبار استعلام reflector:"
sqlite3 "$DB" "SELECT COUNT(*) FROM knowledge_base WHERE deleted_at IS NULL;" || {
  echo "[WARN] الاستعلام ما زال يفشل – راجع بنية الجدول يدوياً." >&2
  exit 1
}

echo
echo "[OK] ✅ تم إصلاح سكيمة knowledge_base بما يناسب reflector."
