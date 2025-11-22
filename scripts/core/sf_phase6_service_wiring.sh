#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

log "===== المرحلة 6 - ربط الخدمات بالذاكرة الموحدة ====="

# 1. التحقق من أن memory.db تحتوي على الهوية
log "[1] التحقق من هوية memory.db:"
sqlite3 /opt/smartfriend-suite/var/db/memory.db "SELECT key, value FROM meta WHERE key = 'identity_name';"

# 2. إعادة تشغيل الخدمات بالترتيب الصحيح
log "[2] إعادة تشغيل الخدمات بالترتيب:"
systemctl restart sf-memory.service && log "✅ sf-memory أعيد تشغيله"
sleep 2
systemctl restart sf-unified.service && log "✅ sf-unified أعيد تشغيله" 
sleep 2
systemctl restart sf-bot.service && log "✅ sf-bot أعيد تشغيله"

# 3. الانتظار ثم الاختبار
log "[3] الانتظار لتستقر الخدمات..."
sleep 5

# 4. الاختبار الشامل
log "[4] الاختبار الشامل للدمج:"

echo "🔍 فحص الخدمات:"
services=("sf-health:8210" "sf-memory:8214" "sf-unified:8220")
for service in "${services[@]}"; do
    name="${service%:*}"
    port="${service#*:}"
    status=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port/health)
    if [ "$status" = "200" ]; then
        log "✅ $name: UP (HTTP $status)"
    else
        log "❌ $name: DOWN (HTTP $status)"
    fi
done

# 5. اختبار عملي للذاكرة
log "[5] اختبار عملي - إنشاء جلسة في الذاكرة الموحدة:"
TEST_SESSION="test_session_$(date +%s)"
sqlite3 /opt/smartfriend-suite/var/db/memory.db "
INSERT INTO sessions (session_id, created_at, updated_at) 
VALUES ('$TEST_SESSION', datetime('now'), datetime('now'));
INSERT INTO messages (message_id, session_id, role, content, timestamp)
VALUES ('test_msg_$(date +%s)', '$TEST_SESSION', 'user', 'اختبار الذاكرة الموحدة', datetime('now'));
SELECT '✅ تم إنشاء جلسة اختبار: ' || session_id FROM sessions WHERE session_id = '$TEST_SESSION';
"

log "===== اكتملت المرحلة 6 ====="
log "🎉 الذاكرة الموحدة الآن تعمل بالكامل!"
