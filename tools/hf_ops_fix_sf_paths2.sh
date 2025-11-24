#!/usr/bin/env bash
# HyperFFactory – Auto-fix sf-* python import roots and ExecStart

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
FF_ROOT="/opt/ffactory"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_ops_fix_sf_paths2_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Fix sf-* python paths (services/ops/apps/web/bot)"
log "ROOT       : $ROOT"
log "SUITE_ROOT : $SUITE_ROOT"
log "FF_ROOT    : $FF_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

PY_BIN="/usr/bin/python3"

SEARCH_ROOTS=()
[ -d "$ROOT" ] && SEARCH_ROOTS+=("$ROOT")
[ -d "$FF_ROOT" ] && SEARCH_ROOTS+=("$FF_ROOT")
[ -d "$SUITE_ROOT" ] && SEARCH_ROOTS+=("$SUITE_ROOT")

if [ "${#SEARCH_ROOTS[@]}" -eq 0 ]; then
  log "❌ لا يوجد أي جذر للبحث (ROOT/FF_ROOT/SUITE_ROOT غير موجودة)"
  exit 1
fi

log "Search roots: ${SEARCH_ROOTS[*]}"

find_first() {
  local name="$1"
  shift
  local roots=("$@")
  find "${roots[@]}" -maxdepth 10 -type f -name "$name" 2>/dev/null | head -n1 || true
}

find_package_root() {
  local file_path="$1"
  local pkg_name="$2"
  local dir
  dir="$(dirname "$file_path")"
  while [ "$dir" != "/" ]; do
    if [ "$(basename "$dir")" = "$pkg_name" ]; then
      echo "$(dirname "$dir")"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ---------- sf-core: services.ffactory.simple_api ----------
log "== Step 1: Fix sf-core (services.ffactory.simple_api) =="
CORE_FILE="$(find_first "simple_api.py" "${SEARCH_ROOTS[@]}")"
if [ -n "$CORE_FILE" ]; then
  log "✓ Found simple_api.py at: $CORE_FILE"
  CORE_ROOT="$(find_package_root "$CORE_FILE" "services" || true)"
  if [ -n "$CORE_ROOT" ]; then
    log "✓ Detected services root for sf-core: $CORE_ROOT"
    OV_DIR="/etc/systemd/system/sf-core.service.d"
    mkdir -p "$OV_DIR"
    cat > "$OV_DIR/override.conf" <<EOF_CORE
[Service]
WorkingDirectory=$CORE_ROOT
ExecStart=
ExecStart=$PY_BIN -m uvicorn services.ffactory.simple_api:app --host 127.0.0.1 --port 8211 --workers 1
EOF_CORE
    log "✓ Wrote override for sf-core.service (WorkingDirectory + ExecStart)"
  else
    log "⚠️ لم يتمكن من تحديد جذر services لـ sf-core رغم وجود simple_api.py"
  fi
else
  log "⚠️ لم يتم العثور على simple_api.py في الجذور المعروفة"
fi

# ---------- sf-health: ops.health_gate ----------
log "== Step 2: Fix sf-health (ops.health_gate) =="
HEALTH_FILE="$(find_first "health_gate.py" "${SEARCH_ROOTS[@]}")"
if [ -n "$HEALTH_FILE" ]; then
  log "✓ Found health_gate.py at: $HEALTH_FILE"
  HEALTH_ROOT="$(find_package_root "$HEALTH_FILE" "ops" || true)"
  if [ -n "$HEALTH_ROOT" ]; then
    log "✓ Detected ops root for sf-health: $HEALTH_ROOT"
    OV_DIR="/etc/systemd/system/sf-health.service.d"
    mkdir -p "$OV_DIR"
    cat > "$OV_DIR/override.conf" <<EOF_HEALTH
[Service]
WorkingDirectory=$HEALTH_ROOT
ExecStart=
ExecStart=$PY_BIN -m uvicorn ops.health_gate:app --host 127.0.0.1 --port 8210 --workers 1 --timeout-keep-alive 30
EOF_HEALTH
    log "✓ Wrote override for sf-health.service (WorkingDirectory + ExecStart)"
  else
    log "⚠️ لم يتمكن من تحديد جذر ops لـ sf-health رغم وجود health_gate.py"
  fi
else
  log "⚠️ لم يتم العثور على health_gate.py في الجذور المعروفة"
fi

# ---------- sf-memory: apps.memory_api ----------
log "== Step 3: Fix sf-memory (apps.memory_api) =="
MEM_FILE="$(find_first "memory_api.py" "${SEARCH_ROOTS[@]}")"
if [ -n "$MEM_FILE" ]; then
  log "✓ Found memory_api.py at: $MEM_FILE"
  MEM_ROOT="$(find_package_root "$MEM_FILE" "apps" || true)"
  if [ -n "$MEM_ROOT" ]; then
    log "✓ Detected apps root for sf-memory: $MEM_ROOT"
    OV_DIR="/etc/systemd/system/sf-memory.service.d"
    mkdir -p "$OV_DIR"
    cat > "$OV_DIR/override.conf" <<EOF_MEM
[Service]
WorkingDirectory=$MEM_ROOT
ExecStart=
ExecStart=$PY_BIN -m uvicorn apps.memory_api:app --host 127.0.0.1 --port 8214 --workers 1
EOF_MEM
    log "✓ Wrote override for sf-memory.service (WorkingDirectory + ExecStart)"
  else
    log "⚠️ لم يتمكن من تحديد جذر apps لـ sf-memory رغم وجود memory_api.py"
  fi
else
  log "⚠️ لم يتم العثور على memory_api.py في الجذور المعروفة"
fi

# ---------- sf-web: run_web.py ----------
log "== Step 4: Fix sf-web (run_web.py) =="
WEB_FILE="$(find_first "run_web.py" "${SEARCH_ROOTS[@]}")"
if [ -n "$WEB_FILE" ]; then
  WEB_DIR="$(dirname "$WEB_FILE")"
  log "✓ Found run_web.py at: $WEB_FILE"
  log "✓ Using WorkingDirectory for sf-web: $WEB_DIR"
  OV_DIR="/etc/systemd/system/sf-web.service.d"
  mkdir -p "$OV_DIR"
  cat > "$OV_DIR/override.conf" <<EOF_WEB
[Service]
WorkingDirectory=$WEB_DIR
ExecStart=
ExecStart=$PY_BIN $WEB_FILE
EOF_WEB
  log "✓ Wrote override for sf-web.service (WorkingDirectory + ExecStart)"
else
  log "⚠️ لم يتم العثور على run_web.py في الجذور المعروفة"
fi

# ---------- sf-bot: main_bot.py ----------
log "== Step 5: Fix sf-bot (main_bot.py) =="
BOT_FILE="$(find_first "main_bot.py" "${SEARCH_ROOTS[@]}")"
if [ -n "$BOT_FILE" ]; then
  BOT_DIR="$(dirname "$BOT_FILE")"
  log "✓ Found main_bot.py at: $BOT_FILE"
  log "✓ Using WorkingDirectory for sf-bot: $BOT_DIR"
  OV_DIR="/etc/systemd/system/sf-bot.service.d"
  mkdir -p "$OV_DIR"
  cat > "$OV_DIR/override.conf" <<EOF_BOT
[Service]
WorkingDirectory=$BOT_DIR
ExecStart=
ExecStart=$PY_BIN $BOT_FILE
EOF_BOT
  log "✓ Wrote override for sf-bot.service (WorkingDirectory + ExecStart)"
else
  log "⚠️ لم يتم العثور على main_bot.py – سيتم ترك إعداد sf-bot كما هو"
fi

log "== Step 6: systemd daemon-reload =="
systemctl daemon-reload

log "== Step 7: Restart sf-* services =="
for s in sf-core sf-health sf-memory sf-web sf-bot; do
  if systemctl list-unit-files | awk '{print $1}' | grep -q "^${s}.service$"; then
    log "  → systemctl restart ${s}.service"
    if systemctl restart "${s}.service"; then
      log "    ✓ ${s}.service restarted"
    else
      log "    ⚠️ ${s}.service failed to restart"
    fi
  else
    log "  ℹ️ ${s}.service غير موجود (تخطي)"
  fi
done

log "== Step 8: Final status snapshot =="
systemctl --no-pager -l status sf-core sf-web sf-health sf-memory sf-bot | sed -n '1,200p' | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_ops_fix_sf_paths2 finished"
log "Report: $LOG"
log "====================================================="
