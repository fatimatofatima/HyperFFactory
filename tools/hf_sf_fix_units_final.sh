#!/usr/bin/env bash
# HyperFFactory – Final fix for sf-* units (paths + WorkingDirectory)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
FF_ROOT="/opt/ffactory"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_fix_units_final_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Final sf-* units fix (services/ops/apps/web/bot)"
log "ROOT       : $ROOT"
log "SUITE_ROOT : $SUITE_ROOT"
log "FF_ROOT    : $FF_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

PY_BIN="/usr/bin/python3"

SEARCH_ROOTS=()
[ -d "$SUITE_ROOT" ] && SEARCH_ROOTS+=("$SUITE_ROOT")
[ -d "$FF_ROOT" ] && SEARCH_ROOTS+=("$FF_ROOT")
[ -d "$ROOT" ] && SEARCH_ROOTS+=("$ROOT")

if [ "${#SEARCH_ROOTS[@]}" -eq 0 ]; then
  log "❌ لا توجد جذور صالحة للبحث"
  exit 1
fi

log "Search roots: ${SEARCH_ROOTS[*]}"

# Helper: find first match for patterns
find_first_pattern() {
  local name_desc="$1"; shift
  local patterns=("$@")
  local roots=("${SEARCH_ROOTS[@]}")
  local found=""
  for pat in "${patterns[@]}"; do
    found=$(find "${roots[@]}" -maxdepth 10 -type f -path "$pat" 2>/dev/null | head -n1 || true)
    if [ -n "$found" ]; then
      log "✓ Found $name_desc at: $found"
      echo "$found"
      return 0
    fi
  done
  echo ""
  return 1
}

# Helper: climb up until we find directory with given basename (pkg)
# returns parent of that pkg dir (project root)
find_pkg_root_up() {
  local start="$1"
  local pkg="$2"
  local dir="$start"
  while [ "$dir" != "/" ]; do
    local base
    base="$(basename "$dir")"
    if [ "$base" = "$pkg" ]; then
      dirname "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ---------- sf-core: services.ffactory.simple_api ----------
log "== Step 1: sf-core (services.ffactory.simple_api) =="
CORE_PATH="$(find_first_pattern "simple_api (services.ffactory)" \
  "*/services/ffactory/simple_api.py" \
  "*/services/ffactory/simple_api/__init__.py")"

if [ -n "$CORE_PATH" ]; then
  CORE_ROOT="$(find_pkg_root_up "$(dirname "$CORE_PATH")" "services" || true)"
  if [ -n "$CORE_ROOT" ]; then
    log "✓ Detected project root for services: $CORE_ROOT"
    OV_DIR="/etc/systemd/system/sf-core.service.d"
    mkdir -p "$OV_DIR"
    cat > "$OV_DIR/99-hf-auto.conf" <<EOF_CORE
[Service]
WorkingDirectory=$CORE_ROOT
ExecStart=
ExecStart=$PY_BIN -m uvicorn services.ffactory.simple_api:app --host 127.0.0.1 --port 8211 --workers 1
EOF_CORE
    log "✓ Wrote /etc/systemd/system/sf-core.service.d/99-hf-auto.conf"
  else
    log "⚠️ لم نتمكن من تحديد جذر services لـ sf-core"
  fi
else
  log "⚠️ لم يتم العثور على مسار simple_api (services/ffactory/simple_api)"
fi

# ---------- sf-health: ops.health_gate ----------
log "== Step 2: sf-health (ops.health_gate) =="
HEALTH_PATH="$(find_first_pattern "health_gate (ops)" \
  "*/ops/health_gate.py" \
  "*/ops/health_gate/__init__.py")"

if [ -n "$HEALTH_PATH" ]; then
  HEALTH_ROOT="$(find_pkg_root_up "$(dirname "$HEALTH_PATH")" "ops" || true)"
  if [ -n "$HEALTH_ROOT" ]; then
    log "✓ Detected project root for ops: $HEALTH_ROOT"
    OV_DIR="/etc/systemd/system/sf-health.service.d"
    mkdir -p "$OV_DIR"
    cat > "$OV_DIR/99-hf-auto.conf" <<EOF_HEALTH
[Service]
WorkingDirectory=$HEALTH_ROOT
ExecStart=
ExecStart=$PY_BIN -m uvicorn ops.health_gate:app --host 127.0.0.1 --port 8210 --workers 1 --timeout-keep-alive 30
EOF_HEALTH
    log "✓ Wrote /etc/systemd/system/sf-health.service.d/99-hf-auto.conf"
  else
    log "⚠️ لم نتمكن من تحديد جذر ops لـ sf-health"
  fi
else
  log "⚠️ لم يتم العثور على مسار health_gate (ops/health_gate)"
fi

# ---------- sf-memory: apps.memory_api ----------
log "== Step 3: sf-memory (apps.memory_api) =="
MEM_PATH="$(find_first_pattern "memory_api (apps)" \
  "*/apps/memory_api.py" \
  "*/apps/memory_api/__init__.py")"

if [ -n "$MEM_PATH" ]; then
  MEM_ROOT="$(find_pkg_root_up "$(dirname "$MEM_PATH")" "apps" || true)"
  if [ -n "$MEM_ROOT" ]; then
    log "✓ Detected project root for apps: $MEM_ROOT"
    OV_DIR="/etc/systemd/system/sf-memory.service.d"
    mkdir -p "$OV_DIR"
    cat > "$OV_DIR/99-hf-auto.conf" <<EOF_MEM
[Service]
WorkingDirectory=$MEM_ROOT
ExecStart=
ExecStart=$PY_BIN -m uvicorn apps.memory_api:app --host 127.0.0.1 --port 8214 --workers 1
EOF_MEM
    log "✓ Wrote /etc/systemd/system/sf-memory.service.d/99-hf-auto.conf"
  else
    log "⚠️ لم نتمكن من تحديد جذر apps لـ sf-memory"
  fi
else
  log "⚠️ لم يتم العثور على مسار memory_api (apps/memory_api)"
fi

# ---------- sf-web: run_web.py ----------
log "== Step 4: sf-web (run_web.py) =="
WEB_PATH=""
# نفضّل النسخة تحت /opt/smartfriend-suite إن وُجدت
if [ -d "$SUITE_ROOT" ]; then
  WEB_PATH="$(find "$SUITE_ROOT" -maxdepth 10 -type f -name "run_web.py" 2>/dev/null | head -n1 || true)"
fi
if [ -z "$WEB_PATH" ]; then
  WEB_PATH="$(find_first_pattern "run_web.py" "*/run_web.py")"
fi

if [ -n "$WEB_PATH" ]; then
  WEB_DIR="$(dirname "$WEB_PATH")"
  log "✓ Using run_web.py at: $WEB_PATH"
  log "✓ WorkingDirectory for sf-web: $WEB_DIR"
  OV_DIR="/etc/systemd/system/sf-web.service.d"
  mkdir -p "$OV_DIR"
  cat > "$OV_DIR/99-hf-auto.conf" <<EOF_WEB
[Service]
WorkingDirectory=$WEB_DIR
ExecStart=
ExecStart=$PY_BIN $WEB_PATH
EOF_WEB
  log "✓ Wrote /etc/systemd/system/sf-web.service.d/99-hf-auto.conf"
else
  log "⚠️ لم يتم العثور على run_web.py في أي من الجذور"
fi

# ---------- sf-bot: main_bot.py ----------
log "== Step 5: sf-bot (main_bot.py) =="
BOT_PATH=""
if [ -d "$SUITE_ROOT" ]; then
  BOT_PATH="$(find "$SUITE_ROOT" -maxdepth 10 -type f -name "main_bot.py" 2>/dev/null | head -n1 || true)"
fi
if [ -z "$BOT_PATH" ]; then
  BOT_PATH="$(find_first_pattern "main_bot.py" "*/main_bot.py")"
fi

if [ -n "$BOT_PATH" ]; then
  BOT_DIR="$(dirname "$BOT_PATH")"
  log "✓ Using main_bot.py at: $BOT_PATH"
  log "✓ WorkingDirectory for sf-bot: $BOT_DIR"
  OV_DIR="/etc/systemd/system/sf-bot.service.d"
  mkdir -p "$OV_DIR"
  cat > "$OV_DIR/99-hf-auto.conf" <<EOF_BOT
[Service]
WorkingDirectory=$BOT_DIR
ExecStart=
ExecStart=$PY_BIN $BOT_PATH
EOF_BOT
  log "✓ Wrote /etc/systemd/system/sf-bot.service.d/99-hf-auto.conf"
else
  log "⚠️ لم يتم العثور على main_bot.py – سيتم ترك sf-bot كما هو (أو تعطيله لاحقًا لو حابب)"
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
log "DONE – hf_sf_fix_units_final finished"
log "Report: $LOG"
log "====================================================="
