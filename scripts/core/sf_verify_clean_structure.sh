#!/usr/bin/env bash
log(){ echo "[$(date '+%F %T')] $*"; }

log "===== التحقق من الهيكل النهائي ====="

log "1. قواعد البيانات المتبقية:"
find /opt/smartfriend-suite /opt/BRAIN_CORE /opt/ffactory -name "*.db" -type f 2>/dev/null | while read db; do
    size=$(du -h "$db" | cut -f1)
    echo "   📁 $db ($size)"
done

log ""
log "2. حالة الخدمات:"
systemctl is-active sf-memory.service && echo "   ✅ sf-memory.service نشط"
systemctl is-active sf-unified.service && echo "   ✅ sf-unified.service نشط" 
systemctl is-active sf-health.service && echo "   ✅ sf-health.service نشط"
systemctl is-active sf-bot.service && echo "   ✅ sf-bot.service نشط"

log ""
log "3. الاختبار العملي:"
curl -s http://127.0.0.1:8214/health && echo "   ✅ Memory API يعمل"
curl -s http://127.0.0.1:8220/health && echo "   ✅ Unified API يعمل"

log ""
log "🎉 الهيكل النهائي جاهز!"
