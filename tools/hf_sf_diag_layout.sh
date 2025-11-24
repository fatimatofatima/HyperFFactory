#!/usr/bin/env bash
# HyperFFactory – SmartFriend sf-* layout & error diagnostics (READ-ONLY)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
FF_ROOT="/opt/ffactory"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_diag_layout_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

header() {
  echo "" | tee -a "$LOG"
  echo "=====================================================" | tee -a "$LOG"
  echo "$*" | tee -a "$LOG"
  echo "=====================================================" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – SmartFriend sf-* DIAGNOSTIC (layout + errors)"
log "ROOT       : $ROOT"
log "SUITE_ROOT : $SUITE_ROOT"
log "FF_ROOT    : $FF_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

SEARCH_ROOTS=()
[ -d "$SUITE_ROOT" ] && SEARCH_ROOTS+=("$SUITE_ROOT")
[ -d "$FF_ROOT" ] && SEARCH_ROOTS+=("$FF_ROOT")
[ -d "$ROOT" ] && SEARCH_ROOTS+=("$ROOT")

if [ "${#SEARCH_ROOTS[@]}" -eq 0 ]; then
  log "❌ لا توجد جذور صالحة للبحث (لا يوجد أي من /opt/smartfriend-suite /opt/ffactory /root/HyperFFactory)"
  exit 1
fi

log "Search roots: ${SEARCH_ROOTS[*]}"

find_one() {
  local label="$1"; shift
  local pattern="$1"; shift
  local found
  found=$(find "${SEARCH_ROOTS[@]}" -maxdepth 10 -type f -path "$pattern" 2>/dev/null | head -n1 || true)
  if [ -n "$found" ]; then
    log "✓ $label: $found"
    ls -l "$found" 2>/dev/null | tee -a "$LOG" || true
  else
    log "⚠️ $label: لم يتم العثور على أي ملف يطابق $pattern"
  fi
}

header "1) Locate Python entrypoints (simple_api / health_gate / memory_api / run_web / main_bot)"

# نحاول أولًا في شكل الحزم الأصلية المتوقعة
find_one "simple_api (services.ffactory.simple_api.py)" "*/services/ffactory/simple_api.py"
find_one "health_gate (ops.health_gate.py)"           "*/ops/health_gate.py"
find_one "memory_api (apps.memory_api.py)"            "*/apps/memory_api.py"
find_one "run_web.py (anywhere)"                      "*/run_web.py"
find_one "main_bot.py (anywhere)"                     "*/main_bot.py"

header "2) systemd unit definitions (sf-core / sf-health / sf-memory / sf-web / sf-bot)"

for u in sf-core sf-health sf-memory sf-web sf-bot; do
  echo "" | tee -a "$LOG"
  log "--- systemctl cat ${u}.service ---"
  if systemctl list-unit-files | awk '{print $1}' | grep -q "^${u}.service$"; then
    systemctl cat "$u" 2>&1 | tee -a "$LOG" || true
  else
    log "ℹ️ ${u}.service غير موجود في list-unit-files (تخطي cat)"
  fi
done

header "3) systemctl status snapshot"

systemctl --no-pager -l status sf-core sf-health sf-memory sf-web sf-bot 2>&1 | tee -a "$LOG" || true

header "4) Last Python errors from journalctl"

for u in sf-core sf-health sf-memory sf-web sf-bot; do
  echo "" | tee -a "$LOG"
  log "--- journalctl -u ${u}.service (آخر 40 سطر) ---"
  if systemctl list-unit-files | awk '{print $1}' | grep -q "^${u}.service$"; then
    journalctl -u "${u}.service" -n 40 --no-pager 2>&1 | tee -a "$LOG" || true
  else
    log "ℹ️ ${u}.service غير موجود – تخطي journalctl"
  fi
done

header "5) Grep common Python import/module errors"

grep -Ei 'ModuleNotFoundError|ImportError|No module named|Traceback|uvicorn.error' "$LOG" 2>/dev/null | tail -n 80 | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_sf_diag_layout finished"
log "Report: $LOG"
log "====================================================="
