#!/usr/bin/env bash
set -Eeuo pipefail

ENV_FILE="/etc/smartfriend/sf_suite.env"
SERVICE_DIR="/etc/systemd/system"

log(){ echo "[$(date '+%F %T')] $*"; }

update_service_env() {
  local service="$1"
  local service_file="$SERVICE_DIR/$service"
  
  if [[ ! -f "$service_file" ]]; then
    log "الخدمة غير موجودة: $service"
    return 1
  fi
  
  # نسخ احتياطي
  cp "$service_file" "$service_file.backup.$(date +%s)"
  
  # تحديث أو إضافة EnvironmentFile
  if grep -q "EnvironmentFile" "$service_file"; then
    sed -i 's|#*EnvironmentFile=.*|EnvironmentFile='"$ENV_FILE"'|' "$service_file"
  else
    # إضافة بعد [Service]
    sed -i '/\[Service\]/a EnvironmentFile='"$ENV_FILE" "$service_file"
  fi
  
  log "تم تحديث: $service"
}

main() {
  log "بدء تحديث خدمات systemd لاستخدام ملف البيئة الموحد"
  
  # الخدمات الأساسية التي تحتاج البيئة
  SERVICES=(
    "sf-bot.service"
    "sf-bot-dev.service" 
    "sf-bot-model.service"
    "sf-telegram.service"
    "sf-telegram-audit.service"
    "sf-smartfactory.service"
    "sf-cognitive.service"
    "sf-memory.service"
    "sf-unified.service"
    "sf-web.service"
  )
  
  for service in "${SERVICES[@]}"; do
    update_service_env "$service"
  done
  
  # إعادة تحميل systemd
  systemctl daemon-reload
  log "تم systemctl daemon-reload"
  
  log "تم تحديث جميع الخدمات لاستخدام ملف البيئة الموحد"
}

main
