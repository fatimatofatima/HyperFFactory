#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

echo "=== SmartFriend – Fix reflector interactions table ==="
echo "[*] قاعدة البيانات: $DB"
echo

if [ ! -f "$DB" ]; then
  echo "[ERROR] DB غير موجود: $DB" >&2
  exit 1
fi

echo "[1] جداول SQLite الحالية:"
sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" || {
  echo "[ERROR] فشل استعلام sqlite_master" >&2
  exit 1
}
echo

echo "[2] فحص وجود جدول interactions ..."
HAS_INTERACTIONS="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='interactions';" || true)"

if [ "$HAS_INTERACTIONS" = "interactions" ]; then
  echo "[OK] جدول interactions موجود بالفعل – لا تعديل على السكيمة."
else
  echo "[*] جدول interactions غير موجود – سيتم إنشاؤه بشكل توافقي مع reflector ..."
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS interactions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    source       TEXT,
    user_id      TEXT,
    input_text   TEXT,
    output_text  TEXT,
    timestamp    TEXT NOT NULL DEFAULT (datetime('now')),
    meta         JSON
);
CREATE INDEX IF NOT EXISTS idx_interactions_ts ON interactions(timestamp);
SQL
  echo "[OK] تم إنشاء جدول interactions + index على timestamp."
fi

echo
echo "[3] عرض سكيمة جدول interactions بعد الإصلاح:"
sqlite3 "$DB" "PRAGMA table_info(interactions);" || true
echo

echo "[4] اختبار استعلام reflector على interactions:"
sqlite3 "$DB" "SELECT COUNT(*) FROM interactions WHERE timestamp > datetime('now','-1 day');" || {
  echo "[WARN] استعلام الاختبار فشل – راجع السكيمة يدوياً." >&2
}
echo

echo "[5] إعادة تشغيل smartfrind-reflector.service ..."
systemctl daemon-reload
systemctl restart smartfrind-reflector.service || true
sleep 1
systemctl status smartfrind-reflector.service --no-pager -l || true

echo
echo "[OK] ✅ انتهى إصلاح جدول interactions (الجزء الخاص بالـ reflector)."
