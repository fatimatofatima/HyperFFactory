#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

echo "=== SmartFriend – Fix reflector summaries table ==="
echo "[*] قاعدة البيانات: $DB"
echo

if [ ! -f "$DB" ]; then
  echo "[ERROR] DB غير موجود: $DB" >&2
  exit 1
fi

echo "[1] عرض الجداول الحالية:"
sqlite3 "$DB" ".tables"
echo

echo "[2] فحص وجود جدول summaries ..."
HAS_SUMMARIES="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='summaries';" || true)"

if [ -z "$HAS_SUMMARIES" ]; then
  echo "[*] جدول summaries غير موجود – سيتم إنشاؤه..."
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS summaries (
    id INTEGER PRIMARY KEY,
    user_id   TEXT    NOT NULL,
    scope     TEXT    NOT NULL,
    text      TEXT    NOT NULL,
    coverage  TEXT    NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
SQL
  echo "[OK] تم إنشاء جدول summaries."
else
  echo "[OK] جدول summaries موجود بالفعل – لن يتم إعادة إنشائه."
fi

echo
echo "[3] سكيمة جدول summaries بعد الإصلاح:"
sqlite3 "$DB" "PRAGMA table_info(summaries);"
echo

echo "[4] اختبار استعلام reflector (INSERT OR REPLACE) على summaries..."
sqlite3 "$DB" "INSERT OR REPLACE INTO summaries(id,user_id,scope,text,coverage,created_at) VALUES(1,'system','daily','test-summary','last24h',CURRENT_TIMESTAMP);"
echo "[OK] تم تنفيذ INSERT OR REPLACE بنجاح (test-summary)."
echo

echo "[5] إعادة تشغيل smartfrind-reflector.service ..."
systemctl daemon-reload
systemctl restart smartfrind-reflector.service || true
systemctl status smartfrind-reflector.service --no-pager -l || true

echo
echo "[OK] ✅ انتهى إصلاح جدول summaries (الجزء الخاص بالـ reflector)."
