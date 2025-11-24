#!/usr/bin/env bash
# HyperFFactory – Final fix for sf-memory & sf-web to /opt/smartfriend-suite

set -Eeuo pipefail

SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="/root/HyperFFactory/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_memory_final_fix_${TS}.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "====================================================="
log "SmartFriend – Final fix sf-memory / sf-web"
log "SUITE_ROOT : $SUITE_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

# 1) تأكيد مجلدات apps و web تحت /opt/smartfriend-suite
log "=== 1) Ensure /opt/smartfriend-suite/apps & /opt/smartfriend-suite/web ==="
mkdir -p "$SUITE_ROOT/apps" "$SUITE_ROOT/web"
[ -f "$SUITE_ROOT/apps/__init__.py" ] || echo '# SmartFriend apps package' > "$SUITE_ROOT/apps/__init__.py"

# 2) تعديل الملكية لمستخدم smartfriend-suite
log "=== 2) Fix ownership (إذا المستخدم موجود) ==="
if id smartfriend-suite >/dev/null 2>&1; then
  chown -R smartfriend-suite:smartfriend-suite "$SUITE_ROOT/apps" "$SUITE_ROOT/web"
  log "✓ ownership set to smartfriend-suite:smartfriend-suite"
else
  log "ℹ️ user smartfriend-suite not found – skip chown"
fi

# 3) Drop-in نهائي لـ sf-memory
log "=== 3) Write 70-hf-final.conf for sf-memory ==="
mkdir -p /etc/systemd/system/sf-memory.service.d
cat > /etc/systemd/system/sf-memory.service.d/70-hf-final.conf <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=
ExecStart=/usr/bin/python3 -m uvicorn apps.memory_api:app --host 127.0.0.1 --port 8214 --workers 1
CONF
log "✓ sf-memory.service.d/70-hf-final.conf written"

# 4) Drop-in نهائي لـ sf-web
log "=== 4) Write 70-hf-final.conf for sf-web ==="
mkdir -p /etc/systemd/system/sf-web.service.d
cat > /etc/systemd/system/sf-web.service.d/70-hf-final.conf <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite/web
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF
log "✓ sf-web.service.d/70-hf-final.conf written"

# 5) daemon-reload + restart للخدمتين
log "=== 5) systemd daemon-reload + restart sf-memory/sf-web ==="
systemctl daemon-reload

for s in sf-memory sf-web; do
  log "▶️ restart ${s}.service"
  if systemctl restart "${s}.service"; then
    log "✓ ${s}.service restarted"
  else
    log "⚠️ failed to restart ${s}.service"
  fi
done

# 6) snapshot نهائي للحالة
log "=== 6) Final status snapshot ==="
systemctl --no-pager -l status sf-memory sf-web 2>&1 | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_sf_web_memory_final_fix"
log "Report: $LOG"
log "====================================================="
