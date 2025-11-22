#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

echo "=== SmartFriend – Fix reflector state table ==="
echo "[*] قاعدة البيانات: $DB"
echo

if [ ! -f "$DB" ]; then
  echo "[ERROR] DB غير موجود: $DB" >&2
  exit 1
fi

echo "[1] الجداول الحالية:"
sqlite3 "$DB" ".tables"
echo

echo "[2] فحص وجود جدول state ..."
HAS_STATE="$(sqlite3 "$DB" \"SELECT name FROM sqlite_master WHERE type='table' AND name='state';\" 2>/dev/null || true)"

if [ -z "$HAS_STATE" ]; then
  echo "[*] جدول state غير موجود – سيتم إنشاؤه..."
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY,
    last_reflection_at TIMESTAMP,
    last_harvest_at    TIMESTAMP,
    last_ingest_at     TIMESTAMP,
    meta               JSON
);
SQL
  echo "[OK] تم إنشاء جدول state."
else
  echo "[OK] جدول state موجود بالفعل – لن يتم إعادة إنشائه."
fi

echo
echo "[3] سكيمة جدول state:"
sqlite3 "$DB" "PRAGMA table_info(state);"
echo

echo "[4] ضمان وجود صف id=1 ..."
sqlite3 "$DB" "INSERT OR IGNORE INTO state(id,last_reflection_at) VALUES(1, datetime('now'));" || true
echo "[OK] تم ضمان وجود الصف id=1."

echo
echo "[5] اختبار استعلام reflector على state (UPDATE id=1)..."
sqlite3 "$DB" "UPDATE state SET last_reflection_at=CURRENT_TIMESTAMP WHERE id=1;"
echo "[OK] تم تنفيذ UPDATE بنجاح."
echo

echo "[6] إعادة تشغيل smartfrind-reflector.service ..."
systemctl daemon-reload
systemctl restart smartfrind-reflector.service || true
systemctl status smartfrind-reflector.service --no-pager -l || true

echo
echo "[OK] ✅ انتهى إصلاح جدول state (الجزء الخاص بالـ reflector)."
