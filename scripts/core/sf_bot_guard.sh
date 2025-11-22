#!/usr/bin/env bash
set -Eeuo pipefail

# دالة لمراقبة التضارب وإعادة التشغيل
guard_bot() {
    local unit="$1"
    local bot_name="$2"
    
    # التحقق من وجود تضارب 409 في السجلات
    if journalctl -u "$unit" -n 100 --no-pager 2>/dev/null | grep -qi '409\|Conflict'; then
        echo "🔄 اكتشف تضارب لـ $bot_name - إعادة التشغيل..."
        systemctl restart "$unit"
        return 0
    fi
    
    # التحقق من أن البوت يعمل
    if ! systemctl is-active --quiet "$unit"; then
        echo "🔄 $bot_name غير نشط - إعادة التشغيل..."
        systemctl restart "$unit"
        return 0
    fi
    
    echo "✅ $bot_name - يعمل بشكل طبيعي"
    return 1
}

# مراقبة التلات بوتات
guard_bot sf-smartfrind.service "SmartFrind Bot"
guard_bot sf-smartfactory.service "SmartFactory Bot" 
guard_bot sf-audit-bot.service "Audit Bot"

# منع تشغيل متعدد خارج systemd
pkill -f "python3.*telegram_audit_bot.py" || true
