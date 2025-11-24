#!/usr/bin/env bash
# HyperFFactory – Fix SmartFriend sf-* PythonPath & WorkingDirectory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_fix_sf_pythonpath_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

ensure_dropin_dir() {
  local unit="$1"
  local d="/etc/systemd/system/${unit}.service.d"
  if [ ! -d "$d" ]; then
    mkdir -p "$d"
  fi
  echo "$d"
}

log "====================================================="
log "HyperFFactory – Fix sf-core/sf-health/sf-memory/sf-web PythonPath & WD"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "====================================================="

UNITS=("sf-core" "sf-health" "sf-memory" "sf-web")

for u in "${UNITS[@]}"; do
  if ! systemctl list-unit-files | grep -q "^${u}.service"; then
    log "ℹ️ ${u}.service غير موجود (تخطي)"
    continue
  fi

  local d
  d=$(ensure_dropin_dir "$u")
  local f="$d/60-hf-root.conf"

  cat > "$f" <<CONF
[Service]
WorkingDirectory=$ROOT
Environment=PYTHONPATH=$ROOT
CONF

  log "✅ كتبنا $f لـ $u (WorkingDirectory=$ROOT, PYTHONPATH=$ROOT)"
done

# sf-bot: إيقاف مؤقتًا لو الكود غير موجود
BOT_UNIT="sf-bot"
if systemctl list-unit-files | grep -q "^${BOT_UNIT}.service"; then
  if [ ! -f "/opt/smartfriend-suite/bots/main_bot.py" ]; then
    log "⚠️ main_bot.py غير موجود تحت /opt/smartfriend-suite/bots – سيتم إيقاف ${BOT_UNIT}.service وتعطيله مؤقتًا"
    systemctl stop "${BOT_UNIT}.service" || true
    systemctl disable "${BOT_UNIT}.service" || true
  else
    log "ℹ️ main_bot.py موجود – لم نلمس ${BOT_UNIT}.service"
  fi
else
  log "ℹ️ ${BOT_UNIT}.service غير موجود (تخطي)"
fi

log "▶️ systemctl daemon-reload"
systemctl daemon-reload

# إعادة تشغيل الخدمات الأساسية
for u in "${UNITS[@]}"; do
  if systemctl list-unit-files | grep -q "^${u}.service"; then
    log "▶️ إعادة تشغيل ${u}.service"
    if systemctl restart "${u}.service"; then
      log "✅ ${u}.service تم إعادة تشغيله"
    else
      log "⚠️ فشل في إعادة تشغيل ${u}.service – راجع journalctl -u ${u}.service"
    fi
  fi
done

log "====================================================="
log "✅ انتهى سكربت hf_fix_sf_pythonpath"
log "📄 تقرير التنفيذ في: $LOG"
log "====================================================="
