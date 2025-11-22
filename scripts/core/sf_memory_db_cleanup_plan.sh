#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

DB_DIR="/opt/smartfriend-suite/var/db"

log "خطة تنظيف قواعد الذاكرة (PLAN ONLY – بدون نقل/حذف)"
log "DB_DIR = ${DB_DIR}"
echo

if [ ! -d "$DB_DIR" ]; then
  log "ERROR: مجلد قواعد البيانات غير موجود: $DB_DIR"
  exit 1
fi

echo "=== الملفات الحالية داخل ${DB_DIR} ==="
ls -la "$DB_DIR"
echo

echo "=== ترشيح ملفات الذاكرة القديمة المراد نقلها للأرشيف ==="
# أي ملفات ذاكرة قديمة/باك-أب باستثناء active_memory.db
find "$DB_DIR" -maxdepth 1 -type f \( \
  -name 'memory.db' -o \
  -name 'memory.db.*' -o \
  -name 'smart_core_memory.db' -o \
  -name 'smart_core_memory.db.*' -o \
  -name 'unified_memory.db' -o \
  -name 'unified_memory.db.*' \
  \) ! -name 'active_memory.db' -print

echo
echo "ملاحظة: هذا مجرد PLAN – لا يوجد أي mv أو rm هنا."
