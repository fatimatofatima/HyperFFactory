#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/smartfriend/sf_suite.env"
BACKUP_DIR="/opt/smartfriend-suite/env_backups"
mkdir -p "$(dirname "$ENV_FILE")" "$BACKUP_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP="$BACKUP_DIR/sf_suite.env.${TS}.bak"

log(){ echo "[$(date '+%F %T')] $*"; }

main() {
  if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "$BACKUP"
    log "تم نسخ النسخة القديمة إلى: $BACKUP"
  fi
  
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

# التوكنات (عدل يدوياً)
export TELEGRAM_MAIN_BOT_TOKEN="CHANGE_ME"
export TELEGRAM_DEV_BOT_TOKEN="CHANGE_ME"
export TELEGRAM_MODEL_BOT_TOKEN="CHANGE_ME"
export TELEGRAM_AUDIT_BOT_TOKEN="CHANGE_ME"

# المسارات
export SF_LOG_DIR="/opt/smartfriend-suite/var/log"
export SF_DATA_DIR="/opt/smartfriend-suite/var/data"
ENVEOF

  chmod 600 "$ENV_FILE"
  log "تم إنشاء ملف البيئة: $ENV_FILE"
  log "تذكر تعديل التوكنات والقيم يدوياً"
}

main
