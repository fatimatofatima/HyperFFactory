#!/usr/bin/env bash
# HyperFFactory – Fix SmartFriend sf-* WorkingDirectory → /opt/smartfriend-suite

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_ops_fix_sf_workdir_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Fix SmartFriend sf-* WorkingDirectory"
log "ROOT       : $ROOT"
log "SUITE_ROOT : $SUITE_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

if [ ! -d "$SUITE_ROOT" ]; then
  log "❌ المجلد $SUITE_ROOT غير موجود – لا يمكن إصلاح WorkingDirectory"
  exit 1
fi

SERVICES=(sf-core sf-web sf-health sf-memory sf-bot)

log "== إنشاء/تحديث override.conf لخدمات sf-* =="

for s in "${SERVICES[@]}"; do
  UNIT="/etc/systemd/system/${s}.service"
  DROPIN_DIR="/etc/systemd/system/${s}.service.d"
  DROPIN_FILE="${DROPIN_DIR}/override.conf"

  if systemctl list-unit-files "${s}.service" >/dev/null 2>&1; then
    log "  → معالجة ${s}.service"
    mkdir -p "$DROPIN_DIR"

    cat > "$DROPIN_FILE" <<EOC
[Service]
WorkingDirectory=$SUITE_ROOT
EOC

    log "    ✓ تم كتابة $DROPIN_FILE"
  else
    log "  ⚠️ ${s}.service غير معرّف (تخطّي)"
  fi
done

log "== systemd daemon-reload =="
systemctl daemon-reload

log "== إعادة تشغيل خدمات SmartFriend sf-* =="
for s in "${SERVICES[@]}"; do
  if systemctl list-unit-files "${s}.service" >/dev/null 2>&1; then
    log "  → systemctl restart ${s}.service"
    if systemctl restart "${s}.service"; then
      log "    ✓ ${s}.service restarted"
    else
      log "    ⚠️ فشل restart لـ ${s}.service (تحقق من journalctl)"
    fi
  fi
done

log "== snapshot سريع لحالة الخدمات =="
for s in "${SERVICES[@]}"; do
  if systemctl list-unit-files "${s}.service" >/dev/null 2>&1; then
    state="$(systemctl is-active "${s}.service" || true)"
    log "  - ${s}.service : ${state}"
  fi
done

log "====================================================="
log "DONE – Fixed WorkingDirectory overrides for SmartFriend sf-*"
log "Report: $LOG"
log "====================================================="
