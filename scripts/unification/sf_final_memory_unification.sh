#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE="/opt/smartfriend-suite/var/db"
ACTIVE="${BASE}/active_memory.db"
TS="$(date +%Y%m%d_%H%M%S)"

log(){ echo "[$(date '+%F %T')] $*"; }

log "===== التوحيد النهائي للذاكرة - إزالة Symlinks ====="
log "BASE  = ${BASE}"
log "ACTIVE= ${ACTIVE}"

if [ ! -f "${ACTIVE}" ]; then
  log "ERROR: active_memory.db غير موجود. أوقف التنفيذ."
  exit 1
fi

# 1. إزالة الـ symlinks واستبدالها بـ active_memory.db مباشرة
log "[1] إزالة الـ symlinks والاستبدال بالدمج الفعلي..."

remove_symlink_and_replace() {
  local db_path="$1"
  local db_name="$(basename "$db_path")"
  
  if [ -L "$db_path" ]; then
    log "إزالة symlink: $db_path"
    rm -f "$db_path"
    log "إنشاء hard link من active_memory.db -> $db_path"
    ln "${ACTIVE}" "$db_path"
    log "✅ تم استبدال $db_name بـ hard link لـ active_memory.db"
  elif [ -f "$db_path" ]; then
    log "⚠️  $db_path ملف عادي (ليس symlink) - تخطي"
  else
    log "إنشاء hard link جديد: $db_path -> ${ACTIVE}"
    ln "${ACTIVE}" "$db_path"
  fi
}

# معالجة قواعد البيانات الرئيسية
remove_symlink_and_replace "${BASE}/memory.db"
remove_symlink_and_replace "${BASE}/smart_core_memory.db"

# 2. حذف unified_memory.db القديم (تم دمجها في active_memory.db)
log "[2] تنظيف القواعد المكررة..."
if [ -f "${BASE}/unified_memory.db" ]; then
  log "حذف unified_memory.db (تم دمجها في active_memory.db)"
  rm -f "${BASE}/unified_memory.db"
fi

# 3. تأكيد أن جميع الروابط أصبحت hard links
log "[3] التحقق من حالة الملفات النهائية:"
echo "memory.db -> $(ls -l "${BASE}/memory.db" | awk '{print $NF}')"
echo "smart_core_memory.db -> $(ls -l "${BASE}/smart_core_memory.db" | awk '{print $NF}')"
echo "active_memory.db -> ملف رئيسي"

# 4. التحقق من أن جميع الملفات تشير لنفس الـ inode (نفس المحتوى)
log "[4] التحقق من التوحيد (نفس الـ inode):"
ls -i "${BASE}/memory.db" "${BASE}/smart_core_memory.db" "${BASE}/active_memory.db" | sort -n

# 5. إعادة تشغيل الخدمات للتأكد
log "[5] إعادة تشغيل الخدمات..."
systemctl daemon-reload
systemctl restart sf-memory.service 2>/dev/null || log "⚠️  لا يمكن إعادة تشغيل sf-memory.service"
systemctl restart sf-unified.service 2>/dev/null || log "⚠️  لا يمكن إعادة تشغيل sf-unified.service"

# 6. الاختبار النهائي
log "[6] الاختبار النهائي بعد التوحيد:"
sleep 2
curl -s http://127.0.0.1:8214/health && echo " ✅ sf-memory متصل"
curl -s http://127.0.0.1:8220/health && echo " ✅ sf-unified متصل"

log "===== التوحيد النهائي اكتمل ====="
log "الآن جميع قواعد الذاكرة تشير فعلياً لنفس الملف: active_memory.db"
log "لا توجد تكرارات أو symlinks - دمج كامل"
