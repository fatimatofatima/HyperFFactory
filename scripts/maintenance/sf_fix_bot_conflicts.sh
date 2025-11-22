#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

# البوتات التي نريد الحفاظ عليها
ACTIVE_BOTS=(
    "sf-bot.service"           # البوت الرئيسي (التحليلي)
    "sf-bot-programmer.service" # البوت المبرمج  
    "sf-bot-model.service"     # البوت النموذج
)

# البوتات التي سنوقفها (مكررة/تسبب تعارض)
STOP_BOTS=(
    "sf-telegram.service"
    "sf-smartfrind.service"
    "sf-bot-dev.service"
    "sf-bot-behavior.service"
)

main() {
    log "🔧 حل تعارض البوتات مع الحفاظ على البوتات الأساسية"
    
    # 1. إيقاف البوتات المكررة
    log "⏹️  إيقاف البوتات المكررة:"
    for bot in "${STOP_BOTS[@]}"; do
        if systemctl is-active "$bot" >/dev/null 2>&1; then
            systemctl stop "$bot" && log "   ✅ تم إيقاف $bot"
            systemctl disable "$bot" && log "   🔒 تم تعطيل $bot"
        fi
    done
    
    # 2. التأكد من تشغيل البوتات الأساسية فقط
    log "🚀 تشغيل البوتات الأساسية:"
    for bot in "${ACTIVE_BOTS[@]}"; do
        if ! systemctl is-active "$bot" >/dev/null 2>&1; then
            systemctl start "$bot" && log "   ✅ تم تشغيل $bot"
        else
            log "   🔄 $bot مشغل بالفعل"
        fi
        systemctl enable "$bot" && log "   🔧 تم تمكين $bot"
    done
    
    # 3. التحقق من عدم وجود تعارضات
    log "🔍 التحقق من التعارضات:"
    sleep 3
    for bot in "${ACTIVE_BOTS[@]}"; do
        if systemctl is-active "$bot" >/dev/null 2>&1; then
            log "   فحص $bot:"
            journalctl -u "$bot" -n 3 --no-pager 2>/dev/null | grep -E "(Conflict|error|Error)" | head -2 || \
            log "      ✅ لا توجد تعارضات"
        fi
    done
    
    log "🎉 تم حل تعارض البوتات - البوتات النشطة الآن:"
    systemctl list-units "sf-*bot*" --no-legend --state=active | awk '{print "   🤖 " $1}'
}

main
