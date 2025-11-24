#!/usr/bin/env bash
set -euo pipefail

IDENTITY_DB="/opt/hyper-factory/var/db/identity/identity.db"

echo "فحص/إصلاح سكيما roles في: $IDENTITY_DB"

if [[ ! -f "$IDENTITY_DB" ]]; then
  echo "❌ identity.db غير موجود: $IDENTITY_DB"
  exit 1
fi

echo "== PRAGMA table_info(roles) قبل =="
sqlite3 "$IDENTITY_DB" "PRAGMA table_info(roles);"
echo

# فحص وجود العمود code باستخدام SQLite مباشرة
HAS_CODE="$(sqlite3 "$IDENTITY_DB" "SELECT 1 FROM pragma_table_info('roles') WHERE name='code' LIMIT 1;" || true)"

if [[ -z "$HAS_CODE" ]]; then
  echo "ℹ️ لا يوجد عمود code، سيتم إضافته..."
  sqlite3 "$IDENTITY_DB" "ALTER TABLE roles ADD COLUMN code TEXT;"
else
  echo "✅ عمود code موجود بالفعل."
fi

echo
echo "🔧 ملء code للقيم الفارغة (إن وجدت)..."
sqlite3 "$IDENTITY_DB" "
  UPDATE roles
  SET code = COALESCE(
      code,
      CASE
        WHEN name IS NOT NULL THEN
          UPPER(REPLACE(name, ' ', '_'))
        ELSE
          'ROLE_' || id
      END
  )
  WHERE code IS NULL OR code = '';
"

echo
echo '🔧 إنشاء Index فريد على code (إن لم يكن موجودًا)...'
sqlite3 "$IDENTITY_DB" "
  CREATE UNIQUE INDEX IF NOT EXISTS idx_roles_code_unique
  ON roles(code);
"

echo
echo "== عينات من roles بعد الإصلاح =="
sqlite3 "$IDENTITY_DB" "SELECT id, code, name FROM roles LIMIT 20;"

echo
echo "== PRAGMA table_info(roles) بعد =="
sqlite3 "$IDENTITY_DB" "PRAGMA table_info(roles);"

echo
echo "✅ تم فحص/إصلاح جدول roles بنجاح."
