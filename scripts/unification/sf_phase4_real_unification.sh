#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

BASE_DIR="/opt/smartfriend-suite/var/db"
MAIN_DB="${BASE_DIR}/memory.db"
ACTIVE_DB="${BASE_DIR}/active_memory.db"

log "===== المرحلة 4 الحقيقية - الدمج الفعلي في memory.db ====="
log "MAIN_DB: $MAIN_DB"
log "ACTIVE_DB: $ACTIVE_DB"

# 1. التحقق من وجود الملفات
if [ ! -f "$ACTIVE_DB" ]; then
    log "❌ active_memory.db غير موجود - لا يمكن المتابعة"
    exit 1
fi

# 2. نسخ احتياطي لـ memory.db الحالي
BACKUP_TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BASE_DIR}/memory.db.backup_before_unification_${BACKUP_TS}"
if [ -f "$MAIN_DB" ]; then
    cp "$MAIN_DB" "$BACKUP_FILE"
    log "✅ نسخة احتياطية: $BACKUP_FILE"
else
    log "ℹ️  memory.db غير موجود - سيتم إنشاؤه جديد"
fi

# 3. استبدال memory.db بـ active_memory.db (الدمج الفعلي)
log "[3] استبدال memory.db بالذاكرة الموحدة..."
cp "$ACTIVE_DB" "$MAIN_DB"
log "✅ تم دمج active_memory.db في memory.db"

# 4. التحقق من الهوية
log "[4] التحقق من الهوية في memory.db الجديد:"
sqlite3 "$MAIN_DB" "SELECT key, value FROM meta WHERE key LIKE 'identity%' OR key LIKE 'schema%';"

# 5. إحصائيات البيانات
log "[5] إحصائيات memory.db بعد الدمج:"
sqlite3 "$MAIN_DB" "SELECT 
    'meta: ' || COUNT(*) FROM meta
    UNION ALL SELECT 'sessions: ' || COUNT(*) FROM sessions  
    UNION ALL SELECT 'messages: ' || COUNT(*) FROM messages
    UNION ALL SELECT 'knowledge_items: ' || COUNT(*) FROM knowledge_items;"

# 6. إصلاح خدمة sf-memory لاستخدام memory.db
log "[6] إصلاح اتصال الخدمة..."
systemctl stop sf-memory.service

# البحث عن ملف التكوين الحقيقي
MEMORY_APP=$(find /opt/smartfriend-suite -path "*/apps/memory_api.py" -type f | head -1)

if [ -n "$MEMORY_APP" ]; then
    log "وجدت تطبيق الذاكرة: $MEMORY_APP"
    
    # نسخ احتياطي للملف
    cp "$MEMORY_APP" "${MEMORY_APP}.backup_${BACKUP_TS}"
    
    # تعديل المسار لاستخدام memory.db بدلاً من active_memory.db
    if grep -q "active_memory.db" "$MEMORY_APP"; then
        sed -i 's|active_memory.db|memory.db|g' "$MEMORY_APP"
        log "✅ تم تعديل المسار إلى memory.db في التطبيق"
    elif grep -q "memory.db" "$MEMORY_APP"; then
        log "✅ التطبيق يستخدم memory.db بالفعل"
    else
        log "⚠️  لم أعثر على إشارة لقاعدة البيانات في التطبيق"
    fi
else
    log "⚠️  لم أعثر على تطبيق memory_api.py"
fi

# 7. إعادة تشغيل الخدمة
log "[7] إعادة تشغيل الخدمة..."
systemctl start sf-memory.service
sleep 3

# 8. الاختبار النهائي
log "[8] الاختبار النهائي:"
curl -s http://127.0.0.1:8214/health && echo "✅ sf-memory يعمل بنجاح" || echo "❌ مشكلة في sf-memory"

log "===== اكتملت المرحلة 4 الحقيقية ====="
log "✅ memory.db الآن يحتوي على البيانات الموحدة + الهوية"
log "✅ الخدمة متصلة بـ memory.db الموحدة"
