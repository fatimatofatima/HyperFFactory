#!/usr/bin/env bash
# Patch hf_start_smartfriend_and_ffactory.sh – ensure ffactory core is started from /opt/ffactory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TARGET="tools/hf_start_smartfriend_and_ffactory.sh"
BACKUP="tools/hf_start_smartfriend_and_ffactory.sh.bak.$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$TARGET" ]; then
  echo "❌ $TARGET غير موجود"
  exit 1
fi

cp "$TARGET" "$BACKUP"

# نعيد بناء السكربت مع بلوك ffactory جديد (نحافظ على رأس السكربت كما هو قدر الإمكان)
cat > "$TARGET" <<'SCRIPT_EOF'
#!/usr/bin/env bash
# HyperFFactory – Start SmartFriend Suite + FFactory + Telegram Bots (unified runner)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_start_smartfriend_and_ffactory_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Start SmartFriend Suite + FFactory + Telegram Bots"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "====================================================="

SF_ROOT="/opt/smartfriend-suite"
FF_ROOT="/opt/ffactory"

log "SmartFriend root : ${SF_ROOT} (exists: $( [ -d "$SF_ROOT" ] && echo YES || echo NO ))"
log "ffactory root    : ${FF_ROOT}"

########################
# Step 1 – SmartFriend #
########################
log "== Step 1: Start SmartFriend Suite services =="

for s in sf-core sf-web sf-health sf-memory sf-bot; do
  if systemctl list-unit-files | grep -q "^${s}.service"; then
    log "  → starting ${s}.service ..."
    if systemctl start "${s}.service"; then
      log "    ✅ ${s}.service started"
    else
      log "    ⚠️ ${s}.service failed to start (systemctl start error)"
    fi
  else
    log "  ⚠️ ${s}.service not defined on this server – skip."
  fi
done

log "== SmartFriend services status =="
for s in sf-core sf-web sf-health sf-memory sf-bot; do
  if systemctl list-units | grep -q "${s}.service"; then
    st=$(systemctl is-active "${s}.service" 2>/dev/null || echo "unknown")
    log "  - ${s}.service : ${st}"
  fi
done

########################
# Step 2 – HTTP health #
########################
log "== Step 2: HTTP Health checks =="

check_http () {
  local name="$1"
  local url="$2"
  if command -v curl >/dev/null 2>&1; then
    if curl -s -m 3 "$url" >/dev/null 2>&1; then
      log "  ✅ ${name} responding at ${url}"
    else
      log "  ⚠️ ${name} not responding at ${url}"
    fi
  else
    log "  ⚠️ curl not installed – skipping HTTP check for ${name}"
  fi
}

check_http "SmartFriend Memory API"  "http://127.0.0.1:8214/health"
check_http "SmartFriend Web UI"      "http://127.0.0.1:8390/health"
check_http "SmartFriend Health API"  "http://127.0.0.1:8215/health"
check_http "SmartFriend Gateway"     "http://127.0.0.1:8220/health"
check_http "FFactory ASR/Echo"       "http://127.0.0.1:8086/health"
check_http "FFactory Ollama"         "http://127.0.0.1:11435/health"

##################################
# Step 3 – ffactory core (docker)#
##################################
log "== Step 3: Start ffactory stack (Docker core) =="

if [ -d "$FF_ROOT" ]; then
  if command -v docker >/dev/null 2>&1; then
    (
      cd "$FF_ROOT"
      if [ -f "stack/docker-compose.core.yml" ]; then
        log "  ▶️ running: docker compose -f stack/docker-compose.core.yml up -d"
        if docker compose -f stack/docker-compose.core.yml up -d >>"$LOG" 2>&1; then
          log "  ✅ ffactory core stack started (or already running)"
        else
          log "  ⚠️ docker compose core stack returned non-zero exit code – check logs"
        fi
      else
        log "  ⚠️ stack/docker-compose.core.yml not found under $FF_ROOT"
      fi
    )
  else
    log "  ⚠️ docker binary not found – cannot start ffactory core"
  fi
else
  log "  ⚠️ ${FF_ROOT} not found – ffactory stack not available"
fi

log "== ffactory containers snapshot =="
if command -v docker >/dev/null 2>&1; then
  docker ps --format '- {{.Names}}\t{{.Status}}' | tee -a "$LOG" || true
else
  log "  ⚠️ docker not installed – skip docker ps"
fi

###########################################
# Step 4 – Telegram bots (SmartFriend)    #
###########################################
log "== Step 4: Telegram bots (SmartFriend) – systemd status snapshot =="

for s in sf-bot sf-bot-assistant sf-bot-pro sf-bot-mod; do
  if systemctl list-unit-files | grep -q "^${s}.service"; then
    log "--- status: ${s}.service ---"
    systemctl --no-pager -l status "${s}.service" | sed -n '1,15p' | tee -a "$LOG" || true
  else
    log "ℹ️ bot ${s}.service not defined on this server (skip)."
  fi
done

log "====================================================="
log "✅ HyperFFactory Orchestrator (SmartFriend + FFactory + Telegram snapshot) finished"
log "📄 Report: $LOG"
log "====================================================="
SCRIPT_EOF

echo "✅ Patched: $TARGET"
echo "💾 Backup saved as: $BACKUP"
