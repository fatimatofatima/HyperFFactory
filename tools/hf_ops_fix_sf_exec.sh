#!/usr/bin/env bash
# HyperFFactory – Fix SmartFriend sf-* ExecStart & WorkingDirectory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
FF_ROOT="/opt/ffactory"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_ops_fix_sf_exec_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Fix SmartFriend sf-* Exec/WorkingDir"
log "ROOT        : $ROOT"
log "SUITE_ROOT  : $SUITE_ROOT"
log "FF_ROOT     : $FF_ROOT"
log "TIME        : $TS"
log "LOG         : $LOG"
log "====================================================="

PY_BIN="/usr/bin/python3"

# 1) تحديد scripts dir لـ FFactory (للـ core/health/memory)
log "== Step 1: Detect ffactory scripts dir =="

SCRIPTS_DIR=""
if [ -d "$FF_ROOT/scripts" ]; then
  SCRIPTS_DIR="$FF_ROOT/scripts"
else
  SCRIPTS_DIR="$(find "$FF_ROOT" "$ROOT" -maxdepth 4 -type d -name "scripts" 2>/dev/null | head -n1 || true)"
fi

if [ -n "$SCRIPTS_DIR" ]; then
  log "✓ Using scripts dir: $SCRIPTS_DIR"
else
  log "⚠️ لم يتم العثور على مجلد scripts تحت $FF_ROOT أو $ROOT – سيتم تخطي إصلاح sf-core/sf-health/sf-memory"
fi

if [ -n "$SCRIPTS_DIR" ]; then
  for s in sf-core sf-health sf-memory; do
    if systemctl list-unit-files | awk '{print $1}' | grep -q "^${s}.service$"; then
      OV_DIR="/etc/systemd/system/${s}.service.d"
      mkdir -p "$OV_DIR"
      cat > "$OV_DIR/override.conf" <<EOF_INNER
[Service]
WorkingDirectory=$SCRIPTS_DIR
EOF_INNER
      log "✓ كتبنا WorkingDirectory=$SCRIPTS_DIR لـ ${s}.service"
    else
      log "ℹ️ ${s}.service غير موجود (تخطي)"
    fi
  done
fi

# 2) إصلاح sf-web (تشغيل run_web.py عبر python3)
log "== Step 2: Fix sf-web.service =="

WEB_SCRIPT="$(find "$ROOT" "$FF_ROOT" "$SUITE_ROOT" -maxdepth 6 -type f -name "run_web.py" 2>/dev/null | head -n1 || true)"

if [ -n "$WEB_SCRIPT" ]; then
  WEB_DIR="$(dirname "$WEB_SCRIPT")"
  OV_DIR="/etc/systemd/system/sf-web.service.d"
  mkdir -p "$OV_DIR"
  cat > "$OV_DIR/override.conf" <<EOF_INNER
[Service]
WorkingDirectory=$WEB_DIR
ExecStart=
ExecStart=$PY_BIN $WEB_SCRIPT
EOF_INNER
  log "✓ sf-web.service → ExecStart=$PY_BIN $WEB_SCRIPT (WD=$WEB_DIR)"
else
  log "⚠️ تعذر العثور على run_web.py تحت $ROOT أو $FF_ROOT أو $SUITE_ROOT – تخطي إصلاح sf-web"
fi

# 3) إصلاح sf-bot (تشغيل main_bot.py عبر python3)
log "== Step 3: Fix sf-bot.service =="

BOT_SCRIPT="$(find "$ROOT" "$FF_ROOT" "$SUITE_ROOT" -maxdepth 6 -type f -name "main_bot.py" 2>/dev/null | head -n1 || true)"

if [ -n "$BOT_SCRIPT" ]; then
  BOT_DIR="$(dirname "$BOT_SCRIPT")"
  OV_DIR="/etc/systemd/system/sf-bot.service.d"
  mkdir -p "$OV_DIR"
  cat > "$OV_DIR/override.conf" <<EOF_INNER
[Service]
WorkingDirectory=$BOT_DIR
ExecStart=
ExecStart=$PY_BIN $BOT_SCRIPT
EOF_INNER
  log "✓ sf-bot.service → ExecStart=$PY_BIN $BOT_SCRIPT (WD=$BOT_DIR)"
else
  log "⚠️ تعذر العثور على main_bot.py – تخطي إصلاح sf-bot"
fi

# 4) daemon-reload + restart الخدمات
log "== Step 4: systemd daemon-reload =="
systemctl daemon-reload

log "== Step 5: Restart sf-* services =="

for s in sf-core sf-health sf-memory sf-web sf-bot; do
  if systemctl list-unit-files | awk '{print $1}' | grep -q "^${s}.service$"; then
    log "  → systemctl restart ${s}.service"
    if systemctl restart "${s}.service"; then
      log "    ✓ ${s}.service restarted"
    else
      log "    ⚠️ فشل restart لـ ${s}.service"
    fi
  else
    log "  ℹ️ ${s}.service غير موجود (تخطي)"
  fi
done

log "== Step 6: Final status snapshot =="
systemctl --no-pager -l status sf-core sf-web sf-health sf-memory sf-bot | sed -n '1,160p' | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_ops_fix_sf_exec finished"
log "Report: $LOG"
log "====================================================="
