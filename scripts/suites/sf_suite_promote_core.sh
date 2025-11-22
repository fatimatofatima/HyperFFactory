#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

REPORT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT="$REPORT_DIR/sf_suite_promote_core_${TS}.log"

# DRY_RUN=1 => لا تغيّر شيء، فقط log
# DRY_RUN=0 => تنفيذ فعلي (enable --now)
DRY_RUN="${DRY_RUN:-1}"

# Toggles (يمكن تغييرها من env قبل التشغيل)
ENABLE_CORE="${ENABLE_CORE:-1}"
ENABLE_BRAIN="${ENABLE_BRAIN:-1}"
ENABLE_WEB="${ENABLE_WEB:-0}"
ENABLE_MEMORY="${ENABLE_MEMORY:-0}"
ENABLE_HEALTH="${ENABLE_HEALTH:-0}"
ENABLE_SPIDER="${ENABLE_SPIDER:-0}"
ENABLE_BOTS="${ENABLE_BOTS:-0}"

log(){ echo "[$(date '+%F %T')] $*"; }

ensure_dir() {
  local d="$1"
  if [[ -d "$d" ]]; then
    log "DIR OK   : $d" | tee -a "$REPORT"
  else
    if [[ "$DRY_RUN" == "1" ]]; then
      log "DRY-RUN: would mkdir -p $d" | tee -a "$REPORT"
    else
      log "mkdir -p $d" | tee -a "$REPORT"
      mkdir -p "$d"
    fi
  fi
}

ensure_env_file() {
  local env_dir="/etc/smartfriend"
  local env_file="$env_dir/sf_suite.env"

  if [[ -f "$env_file" ]]; then
    log "ENV OK   : $env_file موجود بالفعل – لن نعدّله." | tee -a "$REPORT"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN: would create $env_file with basic template." | tee -a "$REPORT"
    return 0
  fi

  log "إنشاء ملف إعداد السيوت: $env_file" | tee -a "$REPORT"
  mkdir -p "$env_dir"

  cat > "$env_file" <<'ENVEOF'
# SmartFriend Suite – central environment file
# عدّل القيم حسب احتياجاتك، هذا مجرد قالب مبدئي.

export SF_ENV="production"
export SF_TIMEZONE="Asia/Kuwait"

# قواعد بيانات موحدة
export SF_UNIFIED_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
export SF_MEMORY_DB="/opt/smartfriend-suite/var/db/memory.db"

# معرفات داخلية (يمكن تركها فارغة لاحقاً)
export SF_INSTANCE_NAME="vmi-smartfriend-suite"

# مفاتيح/توكنات (ضع القيم الحقيقية بنفسك – لا تُستخدم هنا تلقائياً)
export TELEGRAM_MAIN_BOT_TOKEN="CHANGE_ME"
export TELEGRAM_DEV_BOT_TOKEN="CHANGE_ME"
export TELEGRAM_MODEL_BOT_TOKEN="CHANGE_ME"
export TELEGRAM_AUDIT_BOT_TOKEN="CHANGE_ME"
ENVEOF

  chmod 600 "$env_file"
  log "تم إنشاء $env_file (تذكر تعديله يدوياً لاحقاً)." | tee -a "$REPORT"
}

apply_unit_enable_now() {
  local svc="$1"
  [[ -z "$svc" ]] && return 0

  local state active
  state="$(systemctl list-unit-files "$svc" --no-legend 2>/dev/null | awk '{print $2}' || echo "unknown")"
  active="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"

  log "Service: $svc (state=$state, active=$active)" | tee -a "$REPORT"

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$state" != "enabled" ]]; then
      log "DRY-RUN: would systemctl enable $svc" | tee -a "$REPORT"
    fi
    if [[ "$active" != "active" ]]; then
      log "DRY-RUN: would systemctl start $svc" | tee -a "$REPORT"
    fi
  else
    if [[ "$state" != "enabled" ]]; then
      log "systemctl enable $svc" | tee -a "$REPORT"
      systemctl enable "$svc" 2>&1 | tee -a "$REPORT" || true
    fi
    if [[ "$active" != "active" ]]; then
      log "systemctl start $svc" | tee -a "$REPORT"
      systemctl start "$svc" 2>&1 | tee -a "$REPORT" || true
    fi
  fi
}

promote_group() {
  local label="$1"; shift
  local enable_flag="$1"; shift
  local -a services=("$@")

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  log "Group: $label (ENABLE=$enable_flag)" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  if [[ "$enable_flag" != "1" ]]; then
    log "Group $label معطل (ENABLE!=1)، لن نلمس الخدمات." | tee -a "$REPORT"
    return 0
  fi

  for s in "${services[@]}"; do
    apply_unit_enable_now "$s"
  done
}

main() {
  {
    echo "============================================================"
    echo " SmartFriend Suite – Promote Core/Brain/Web/Memory"
    echo " Timestamp : $(date '+%F %T')"
    echo " Hostname  : $(hostname)"
    echo " DRY_RUN   : $DRY_RUN (1=log فقط، 0=enable+start فعلي)"
    echo " Toggles   :"
    echo "   ENABLE_CORE   = $ENABLE_CORE"
    echo "   ENABLE_BRAIN  = $ENABLE_BRAIN"
    echo "   ENABLE_WEB    = $ENABLE_WEB"
    echo "   ENABLE_MEMORY = $ENABLE_MEMORY"
    echo "   ENABLE_HEALTH = $ENABLE_HEALTH"
    echo "   ENABLE_SPIDER = $ENABLE_SPIDER"
    echo "   ENABLE_BOTS   = $ENABLE_BOTS"
    echo "============================================================"
    echo
    echo "1) تجهيز هيكل المجلدات للسيوت"
    echo "------------------------------------------------------------"
  } | tee "$REPORT"

  # الهيكل المتوقّع (مجلدات فقط – لا لمس للكود)
  ensure_dir "/opt/smartfriend-suite"
  ensure_dir "/opt/smartfriend-suite/apps"
  ensure_dir "/opt/smartfriend-suite/apps/core"
  ensure_dir "/opt/smartfriend-suite/apps/brain"
  ensure_dir "/opt/smartfriend-suite/apps/harvester"
  ensure_dir "/opt/smartfriend-suite/apps/unified"
  ensure_dir "/opt/smartfriend-suite/apps/web"
  ensure_dir "/opt/smartfriend-suite/apps/telegram"
  ensure_dir "/opt/smartfriend-suite/apps/learning"
  ensure_dir "/opt/smartfriend-suite/apps/memory"
  ensure_dir "/opt/smartfriend-suite/apps/ffactory"

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "2) التأكد من ملف الإعداد المركزي للسيوت" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  ensure_env_file

  # المجموعات

  # Core / APIs – نعتبر sf-core هو الـ Core الرسمي الآن
  CORE_SERVICES=(
    sf-core.service
    # يمكن لاحقاً اعتبار smartfriend-api/unified كجزء من core أيضاً إن أردت:
    # smartfriend-api.service
    # smartfriend-unified.service
  )

  # Brain / Learning / Maintenance
  BRAIN_SERVICES=(
    sf-ingest.service
    sf-kb-build.service
    sf-fts-maint.service
    sf-learn.service
    sf-learning.service
    sf-backup.service
    sf-db-backup.service
    sf-db-maintenance.service
  )

  # Web UI
  WEB_SERVICES=(
    sf-web.service
  )

  # Memory API
  MEMORY_SERVICES=(
    sf-memory.service
  )

  # Health / Smoke
  HEALTH_SERVICES=(
    sf-health.service
    sf-smoke.service
  )

  # Spider
  SPIDER_SERVICES=(
    sf-spider.service
  )

  # Bots (يمكن تقليص القائمة لاحقاً حسب ما تعتمد رسمياً)
  BOT_SERVICES=(
    sf-bot.service
    sf-bot-dev.service
    sf-bot-model.service
    sf-telegram.service
    sf-telegram-audit.service
    sf-smartfriend.service
    sf-smartfrind.service
    sf-smartfactory.service
    sf-bot-assistant.service
    sf-bot-programmer.service
    sf-bot-behavior.service
    sf-audit-bot.service
  )

  promote_group "CORE"   "$ENABLE_CORE"   "${CORE_SERVICES[@]}"
  promote_group "BRAIN"  "$ENABLE_BRAIN"  "${BRAIN_SERVICES[@]}"
  promote_group "WEB"    "$ENABLE_WEB"    "${WEB_SERVICES[@]}"
  promote_group "MEMORY" "$ENABLE_MEMORY" "${MEMORY_SERVICES[@]}"
  promote_group "HEALTH" "$ENABLE_HEALTH" "${HEALTH_SERVICES[@]}"
  promote_group "SPIDER" "$ENABLE_SPIDER" "${SPIDER_SERVICES[@]}"
  promote_group "BOTS"   "$ENABLE_BOTS"   "${BOT_SERVICES[@]}"

  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "3) Snapshot سريع للحالة بعد الترويج (sf-* فقط)" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  log "systemctl list-units 'sf-*' (runtime):" | tee -a "$REPORT"
  systemctl list-units "sf-*" --no-legend 2>/dev/null | tee -a "$REPORT" || true

  echo >> "$REPORT"
  log "systemctl list-unit-files 'sf-*' (unit files):" | tee -a "$REPORT"
  systemctl list-unit-files "sf-*" --no-legend 2>/dev/null | tee -a "$REPORT" || true

  echo >> "$REPORT"
  log "Promote finished. Report: $REPORT" | tee -a "$REPORT"
}

main
