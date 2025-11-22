#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/smartfriend/sf_suite.env"
BACKUP_DIR="/opt/smartfriend-suite/env_backups"
mkdir -p "$BACKUP_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP="$BACKUP_DIR/sf_suite.env.${TS}.bak"

log(){ echo "[$(date '+%F %T')] $*"; }

# التوكنات الجديدة
declare -A TOKENS=(
    ["TELEGRAM_MAIN_BOT_TOKEN"]="7985788141:AAGEWK4Qs-NTamwaN3F10q6qC3CVq3d_QA8"
    ["TELEGRAM_SMARTFACTORY_TOKEN"]="8241529778:AAHEJRnUC1ZkFXDLvJrsVrPBs2YTXNPsU6w"
    ["TELEGRAM_AUDIT_BOT_TOKEN"]="8493429114:AAGQrZ42tFGo4UvaOjbr2cu5qfS59TZE70g"
    ["TELEGRAM_PSMART_TOKEN"]="8338003920:AAH7jN2cIOg_hz2AlR_k5B0L5G8ObJgzO7s"
    ["TELEGRAM_NEXTSMART_TOKEN"]="8228013890:AAF7qv4-ShMV1z9FDskjvyQ1b3Ook7B1ekw"
    ["TELEGRAM_WINNWONET_TOKEN"]="8236695795:AAG6VT6KIo4XjTtHVYz92d8MKzzaTJOEUQ0"
    ["TELEGRAM_MYSERVTIYDATA_TOKEN"]="7979966842:AAF6TQORUPJZ0ZBqYSwnvKNOAQL3ymUDtpw"
)

main() {
    log "بدء تحديث جميع التوكنات وإصلاح الخدمات"
    
    # نسخ احتياطي للملف الحالي
    if [[ -f "$ENV_FILE" ]]; then
        cp "$ENV_FILE" "$BACKUP"
        log "تم نسخ النسخة القديمة إلى: $BACKUP"
    fi
    
    # تحديث التوكنات في الملف الرئيسي
    log "🔄 تحديث التوكنات في $ENV_FILE"
    
    # إنشاء محتوى جديد للملف
    cat > "$ENV_FILE" <<'ENVEOF'
# SmartFriend Suite - Central Environment Configuration
# Generated: $(date)

# الأساسيات
export SF_ENV="production"
export SF_TIMEZONE="Asia/Kuwait"
export SF_INSTANCE_NAME="vmi-smartfriend-suite"

# قواعد البيانات
export SF_UNIFIED_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
export SF_MEMORY_DB="/opt/smartfriend-suite/var/db/memory.db"

# البورتات
export SF_CORE_PORT="8383"
export SF_UNIFIED_PORT="8220"
export SF_MEMORY_PORT="8214"
export SF_WEB_PORT="8390"

# التوكنات (محدثة)
export TELEGRAM_MAIN_BOT_TOKEN="7985788141:AAGEWK4Qs-NTamwaN3F10q6qC3CVq3d_QA8"
export TELEGRAM_SMARTFACTORY_TOKEN="8241529778:AAHEJRnUC1ZkFXDLvJrsVrPBs2YTXNPsU6w"
export TELEGRAM_AUDIT_BOT_TOKEN="8493429114:AAGQrZ42tFGo4UvaOjbr2cu5qfS59TZE70g"
export TELEGRAM_PSMART_TOKEN="8338003920:AAH7jN2cIOg_hz2AlR_k5B0L5G8ObJgzO7s"
export TELEGRAM_NEXTSMART_TOKEN="8228013890:AAF7qv4-ShMV1z9FDskjvyQ1b3Ook7B1ekw"
export TELEGRAM_WINNWONET_TOKEN="8236695795:AAG6VT6KIo4XjTtHVYz92d8MKzzaTJOEUQ0"
export TELEGRAM_MYSERVTIYDATA_TOKEN="7979966842:AAF6TQORUPJZ0ZBqYSwnvKNOAQL3ymUDtpw"

# إعدادات إضافية
ENVEOF

    log "✅ تم تحديث جميع التوكنات في الملف الرئيسي"
    
    # تحديث الملفات الأخرى
    update_additional_files
    
    # إصلاح الخدمات الفاشلة
    fix_failed_services
    
    # إعادة تشغيل البوتات
    restart_bots
    
    log "🎉 تم الانتهاء من تحديث التوكنات وإصلاح الخدمات"
}

update_additional_files() {
    log "📝 تحديث الملفات الإضافية"
    
    # تحديث train_secrets.env
    if [[ -f "/etc/smartfriend/train_secrets.env" ]]; then
        sed -i 's/BOT_SMARTFACTORY_TOKEN=.*/BOT_SMARTFACTORY_TOKEN="8241529778:AAHEJRnUC1ZkFXDLvJrsVrPBs2YTXNPsU6w"/' /etc/smartfriend/train_secrets.env
        log "✅ تم تحديث train_secrets.env"
    fi
    
    # تحديث sf-smartfactory.env
    if [[ -f "/etc/smartfriend/sf-smartfactory.env" ]]; then
        sed -i 's/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=8241529778:AAHEJRnUC1ZkFXDLvJrsVrPBs2YTXNPsU6w/' /etc/smartfriend/sf-smartfactory.env
        log "✅ تم تحديث sf-smartfactory.env"
    fi
}

fix_failed_services() {
    log "🔧 إصلاح الخدمات الفاشلة"
    
    local failed_services=(
        "sf-unified.service"
        "sf-memory.service" 
        "sf-web.service"
        "sf-spider.service"
        "sf-health.service"
        "sf-bot-programmer.service"
        "sf-telegram-audit.service"
        "sf-smartfactory.service"
    )
    
    for service in "${failed_services[@]}"; do
        log "معالجة: $service"
        
        # إيقاف الخدمة
        systemctl stop "$service" 2>/dev/null || true
        
        # إعادة تحميل systemd
        systemctl daemon-reload
        
        # بدء الخدمة
        if systemctl start "$service"; then
            log "  ✅ تم بدء $service بنجاح"
        else
            log "  ❌ فشل بدء $service - يحتاج فحص يدوي"
        fi
    done
}

restart_bots() {
    log "🤖 إعادة تشغيل البوتات النشطة"
    
    local active_bots=(
        "sf-bot.service"
        "sf-bot-model.service" 
        "sf-telegram.service"
        "sf-smartfrind.service"
    )
    
    for bot in "${active_bots[@]}"; do
        if systemctl is-active "$bot" >/dev/null 2>&1; then
            log "إعادة تشغيل: $bot"
            systemctl restart "$bot" && log "  ✅ تم إعادة تشغيل $bot"
        fi
    done
}

main
