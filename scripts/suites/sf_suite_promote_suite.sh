#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

REPORT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT="$REPORT_DIR/sf_suite_promote_suite_${TS}.log"

DRY_RUN="${DRY_RUN:-1}"

log(){ echo "[$(date '+%F %T')] $*"; }

ENV_FILE="/etc/smartfriend/sf_suite.env"

ensure_env_file() {
  log "Checking unified env file: $ENV_FILE"

  if [[ ! -f "$ENV_FILE" ]]; then
    log "Creating new env file: $ENV_FILE"
    cat > "$ENV_FILE" <<'EOC'
# SmartFriend Suite unified environment
# هذه القيم يمكن تعديلها لاحقًا عند الحاجة.

# قاعدة البيانات الرسمية الموحدة
SMARTFRIEND_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

# قاعدة بيانات الذاكرة
SMARTFRIEND_MEMORY_DB="/opt/smartfriend-suite/var/db/memory.db"
SMARTFRIEND_ACTIVE_MEMORY_DB="/opt/smartfriend-suite/var/db/active_memory.db"

# مسار الـ knowledge
SMARTFRIEND_KNOWLEDGE_DIR="/opt/smartfriend-suite/var/knowledge"

# عناوين APIs الداخلية (يمكن تعديلها لاحقاً عند switch كامل)
SMARTFRIEND_UNIFIED_URL="http://127.0.0.1:8220"
SMARTFRIEND_CORE_URL="http://127.0.0.1:8383"
SMARTFRIEND_FACTORY_URL="http://127.0.0.1:8210"

# إعدادات عامة أخرى يمكن استخدامها من الخدمات لاحقاً
SMARTFRIEND_ENV="production"
EOC
  else
    # لو الملف موجود، نضيف بلوك تعريفي بسيط إذا لم يكن موجوداً
    if ! grep -q 'SMARTFRIEND_DB=' "$ENV_FILE"; then
      log "Appending SmartFriend DB defaults to existing env file"
      cat >> "$ENV_FILE" <<'EOC'

# SmartFriend Suite unified DB defaults (appended)
SMARTFRIEND_DB="${SMARTFRIEND_DB:-/opt/smartfriend-suite/var/db/smartfriend_unified.db}"
SMARTFRIEND_MEMORY_DB="${SMARTFRIEND_MEMORY_DB:-/opt/smartfriend-suite/var/db/memory.db}"
SMARTFRIEND_ACTIVE_MEMORY_DB="${SMARTFRIEND_ACTIVE_MEMORY_DB:-/opt/smartfriend-suite/var/db/active_memory.db}"
SMARTFRIEND_KNOWLEDGE_DIR="${SMARTFRIEND_KNOWLEDGE_DIR:-/opt/smartfriend-suite/var/knowledge}"
SMARTFRIEND_UNIFIED_URL="${SMARTFRIEND_UNIFIED_URL:-http://127.0.0.1:8220}"
SMARTFRIEND_CORE_URL="${SMARTFRIEND_CORE_URL:-http://127.0.0.1:8383}"
SMARTFRIEND_FACTORY_URL="${SMARTFRIEND_FACTORY_URL:-http://127.0.0.1:8210}"
SMARTFRIEND_ENV="${SMARTFRIEND_ENV:-production}"
EOC
    fi
  fi

  chmod 640 "$ENV_FILE"
  chown root:root "$ENV_FILE"
  log "Env file ready: $ENV_FILE"
}

PROMOTE_UNITS=(
  sf-core.service
  sf-unified.service
  sf-memory.service
  sf-web.service
)

get_unit_state() {
  local svc="$1"
  systemctl list-unit-files "$svc" --no-legend 2>/dev/null | awk '{print $2}' || true
}

get_unit_active() {
  local svc="$1"
  systemctl is-active "$svc" 2>/dev/null || echo "unknown"
}

promote_units() {
  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "Promoting core sf-* services (DRY_RUN=$DRY_RUN)" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"

  for svc in "${PROMOTE_UNITS[@]}"; do
    if ! systemctl list-unit-files "$svc" &>/dev/null; then
      log "SKIP (unit file not found): $svc" | tee -a "$REPORT"
      continue
    fi

    local state active
    state="$(get_unit_state "$svc")"
    active="$(get_unit_active "$svc")"

    log "Current: $svc unit_state=$state active=$active" | tee -a "$REPORT"

    if [[ "$DRY_RUN" == "1" ]]; then
      if [[ "$state" != "enabled" ]]; then
        log "DRY-RUN would: systemctl enable $svc" | tee -a "$REPORT"
      fi
      if [[ "$active" != "active" ]]; then
        log "DRY-RUN would: systemctl start $svc" | tee -a "$REPORT"
      fi
    else
      if [[ "$state" != "enabled" ]]; then
        log "Enabling $svc" | tee -a "$REPORT"
        systemctl enable "$svc" 2>&1 | tee -a "$REPORT" || true
      fi
      if [[ "$active" != "active" ]]; then
        log "Starting $svc" | tee -a "$REPORT"
        systemctl start "$svc" 2>&1 | tee -a "$REPORT" || true
      fi
    fi
  done
}

dump_ports() {
  echo >> "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  echo "Listening ports snapshot (core relevant ports)" | tee -a "$REPORT"
  echo "------------------------------------------------------------" | tee -a "$REPORT"
  ss -tulpnH 2>/dev/null | egrep '(:8210|:8211|:8220|:8214|:8383|:8390)' || true | tee -a "$REPORT"
}

main() {
  {
    echo "============================================================"
    echo " SmartFriend Suite – Promote Suite Runbook"
    echo " Timestamp : $(date '+%F %T')"
    echo " Hostname  : $(hostname)"
    echo " DRY_RUN   : $DRY_RUN (1=only log, 0=enable+start)"
    echo "============================================================"
    echo
    echo "1) Ensure unified env file"
  } | tee "$REPORT"

  ensure_env_file | tee -a "$REPORT"

  promote_units

  dump_ports

  log "Promote Suite completed. Report: $REPORT" | tee -a "$REPORT"
}

main
