#!/usr/bin/env bash
# HyperFFactory – Cleanup bad drop-ins + fix sf-web to /opt/smartfriend-suite/web

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
SUITE_ROOT="/opt/smartfriend-suite"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_cleanup_fix_${TS}.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "====================================================="
log "SmartFriend – Cleanup 70-hf-autopath + fix sf-web"
log "SUITE_ROOT : $SUITE_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

# 1) تنظيف 70-hf-autopath.conf لكل sf-*
log "=== 1) Remove bad 70-hf-autopath.conf drop-ins (core/health/memory/web) ==="
for svc in sf-core sf-health sf-memory sf-web; do
  FILE="/etc/systemd/system/${svc}.service.d/70-hf-autopath.conf"
  if [ -f "$FILE" ]; then
    log "✓ removing $FILE"
    rm -f "$FILE"
  else
    log "ℹ️ $FILE not found – skip"
  fi
done

# 2) تأكيد وجود /opt/smartfriend-suite/web/run_web.py
log "=== 2) Ensure /opt/smartfriend-suite/web/run_web.py exists ==="
if [ ! -f "$SUITE_ROOT/web/run_web.py" ]; then
  log "⚠️ $SUITE_ROOT/web/run_web.py is missing – sf-web will still fail"
fi

# 3) تعديل override.conf لـ sf-web ليكون هو الحاكم الأخير
log "=== 3) Rewrite sf-web override.conf (WorkingDirectory + ExecStart) ==="
OVR_DIR="/etc/systemd/system/sf-web.service.d"
OVR_FILE="$OVR_DIR/override.conf"
mkdir -p "$OVR_DIR"

if [ -f "$OVR_FILE" ]; then
  BAK="${OVR_FILE}.hfbackup_${TS}"
  cp "$OVR_FILE" "$BAK"
  log "✓ backup override.conf -> $BAK"
fi

cat > "$OVR_FILE" <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite/web
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF

log "✓ wrote new sf-web override.conf"

# 4) daemon-reload + restart الخدمات الأربع (مع التركيز على sf-web)
log "=== 4) systemd daemon-reload + restart sf-core/sf-health/sf-memory/sf-web ==="
systemctl daemon-reload

for s in sf-core sf-health sf-memory sf-web; do
  log "▶️ restart ${s}.service"
  if systemctl restart "${s}.service"; then
    log "✓ ${s}.service restarted"
  else
    log "⚠️ failed to restart ${s}.service"
  fi
done

# 5) snapshot نهائي للحالة
log "=== 5) Final status snapshot ==="
systemctl --no-pager -l status sf-core sf-health sf-memory sf-web 2>&1 | tee -a "$LOG" || true

# 6) اختبار /health
log "=== 6) Test /health endpoints ==="

log "---- curl 8211 (core) ----"
curl -s http://127.0.0.1:8211/health || echo "❌ Core API غير متاح" | tee -a "$LOG"

log "---- curl 8210 (health gate) ----"
curl -s http://127.0.0.1:8210/health || echo "❌ Health API غير متاح" | tee -a "$LOG"

log "---- curl 8214 (memory) ----"
curl -s http://127.0.0.1:8214/health || echo "❌ Memory API غير متاح" | tee -a "$LOG"

log "---- curl 8390 (web) ----"
curl -s http://127.0.0.1:8390/health || echo "❌ Web UI غير متاح" | tee -a "$LOG"

log "====================================================="
log "DONE – hf_sf_web_cleanup_fix"
log "Report: $LOG"
log "====================================================="
