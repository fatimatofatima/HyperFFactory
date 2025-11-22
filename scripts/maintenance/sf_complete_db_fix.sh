#!/usr/bin/env bash
set -Eeuo pipefail

DB_FILE="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
DB_DIR="/opt/smartfriend-suite/var/db"

echo "=== الحل الشامل لصلاحيات قاعدة البيانات ==="

# 1) إيقاف جميع الخدمات المؤقتة
systemctl stop smartfrind-reflector.service 2>/dev/null || true

# 2) ضبط ملكية الملفات (جذرية لكنها فعالة)
chown -R smartfriend-suite:smartfriend-suite "$DB_DIR" 2>/dev/null || true
chmod -R 775 "$DB_DIR" 2>/dev/null || true
chmod 666 "$DB_FILE" 2>/dev/null || true

# 3) أو بدلاً من ذلك: السماح للجميع بالقراءة/الكتابة (للإصلاح المؤقت)
chmod a+rw "$DB_FILE" 2>/dev/null || true

# 4) التحقق
echo "الصلاحيات الجديدة:"
ls -la "$DB_FILE"

# 5) اختبار
echo "اختبار الوصول إلى قاعدة البيانات:"
sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 3;" 2>/dev/null && echo "✅ الوصول ناجح" || echo "❌ لا يزال هناك مشكلة في الوصول"

# 6) إعادة تشغيل الخدمة
systemctl restart smartfrind-reflector.service
systemctl status smartfrind-reflector.service --no-pager -l
