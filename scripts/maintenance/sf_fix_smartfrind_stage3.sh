#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_DIR="/root/sf_migration"
REPORT="${LOG_DIR}/sf_fix_smartfrind_stage3_${TS}.log"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$REPORT"
}

SF_SUITE="/opt/smartfriend-suite"
SF_SMARTFRIND="${SF_SUITE}/smartfrind"
SF_VENV="${SF_SMARTFRIND}/venv"
BACKUP_ROOT="${SF_SUITE}/_smartfrind_migration_${TS}"

SERVICES=(
  smartfriend-api
  smartfriend-smartcore
  smartfriend-unified
  smartfrind-advanced
  smartfrind-ai-gateway
  smartfrind-api
  smartfrind-core
  smartfrind-gateway
  smartfrind-local
  smartfrind-runner
  smartfrind-trainer
  smartfrind-learning
)

CORE_STACK=(
  smartfrind-qa
  smartfrind-core
  smartfrind-api
)

log "=== Stage3: Rebuild smartfrind venv + finalize move into SmartFriend-Suite ==="
log

# --------------------------------------------------
# 1) إيقاف الخدمات الأساسية مؤقتًا
# --------------------------------------------------
log "1) Stopping SmartFriend / SmartFrind units (best-effort)"
for s in "${SERVICES[@]}"; do
    if systemctl list-unit-files "${s}.service" &>/dev/null; then
        log " - systemctl stop ${s}.service"
        systemctl stop "${s}.service" 2>>"$REPORT" || true
    fi
done

# --------------------------------------------------
# 2) عمل نسخة احتياطية كاملة قبل أي تعديل
# --------------------------------------------------
log
log "2) Backing up current tree and unit files to: ${BACKUP_ROOT}"
mkdir -p "$BACKUP_ROOT"

if [ -d "$SF_SMARTFRIND" ]; then
    log " - Copying ${SF_SMARTFRIND} -> ${BACKUP_ROOT}/smartfrind_tree"
    cp -a "$SF_SMARTFRIND" "${BACKUP_ROOT}/smartfrind_tree"
else
    log " - WARNING: ${SF_SMARTFRIND} not found"
fi

if compgen -G "/etc/systemd/system/smartfrind-*.*" >/dev/null; then
    mkdir -p "${BACKUP_ROOT}/systemd"
    log " - Backing up /etc/systemd/system/smartfrind-* -> ${BACKUP_ROOT}/systemd/"
    cp -a /etc/systemd/system/smartfrind-* "${BACKUP_ROOT}/systemd/" || true
else
    log " - No smartfrind-* unit files found under /etc/systemd/system/"
fi

if [ -d /opt/smartfrind ]; then
    log " - Backing up legacy /opt/smartfrind -> ${BACKUP_ROOT}/legacy_opt_smartfrind"
    cp -a /opt/smartfrind "${BACKUP_ROOT}/legacy_opt_smartfrind"
else
    log " - No legacy /opt/smartfrind directory to backup"
fi

# --------------------------------------------------
# 3) إعادة بناء venv نظيف بدون أي بواقي قديمة
# --------------------------------------------------
log
log "3) Rebuilding virtualenv at ${SF_VENV} (no symlink /opt/smartfrind/*)"

if [ -d "$SF_VENV" ]; then
    log " - Removing old venv: ${SF_VENV}"
    rm -rf "$SF_VENV"
fi

log " - Creating new venv using system python3"
python3 -m venv "$SF_VENV"

log " - Detecting requirements file"
REQ="${SF_SMARTFRIND}/requirements.final.txt"
if [ ! -f "$REQ" ]; then
    REQ="${SF_SMARTFRIND}/requirements.txt"
fi

if [ -f "$REQ" ]; then
    log " - Installing pip/setuptools/wheel"
    "${SF_VENV}/bin/pip" install --upgrade pip setuptools wheel >>"$REPORT" 2>&1 || log " - WARNING: pip bootstrap failed (check log)"
    log " - Installing requirements from $(basename "$REQ")"
    "${SF_VENV}/bin/pip" install -r "$REQ" >>"$REPORT" 2>&1 || log " - WARNING: requirements install failed (check log)"
else
    log " - WARNING: No requirements.final.txt or requirements.txt found under ${SF_SMARTFRIND}"
fi

# --------------------------------------------------
# 4) ضبط الصلاحيات على شجرة smartfrind وقواعد البيانات
# --------------------------------------------------
log
log "4) Fixing ownership for smartfrind tree and DB paths"

if id smartfrind &>/dev/null; then
    chown -R smartfrind:smartfrind "$SF_SMARTFRIND" || log " - WARNING: chown failed on ${SF_SMARTFRIND}"
    if [ -d /var/lib/smartfrind ]; then
        chown -R smartfrind:smartfrind /var/lib/smartfrind || log " - WARNING: chown failed on /var/lib/smartfrind"
    fi
    if [ -d /var/log/smartfrind ]; then
        chown -R smartfrind:smartfrind /var/log/smartfrind || log " - WARNING: chown failed on /var/log/smartfrind"
    fi
else
    log " - WARNING: user 'smartfrind' does not exist; skipped chown"
fi

# --------------------------------------------------
# 5) إزالة /opt/smartfrind القديم نهائياً بعد النسخ الاحتياطي
# --------------------------------------------------
log
log "5) Removing legacy /opt/smartfrind after backup (no second installation)"

if [ -d /opt/smartfrind ]; then
    rm -rf /opt/smartfrind
    log " - /opt/smartfrind removed. Only SmartFriend-Suite tree remains."
else
    log " - /opt/smartfrind already absent."
fi

# --------------------------------------------------
# 6) Reload systemd وبدء حزمة الخدمات الأساسية
# --------------------------------------------------
log
log "6) Reloading systemd daemon"
systemctl daemon-reload

log
log "7) Starting core SmartFrind stack (qa + core + api) – best-effort"
for s in "${CORE_STACK[@]}"; do
    if systemctl list-unit-files "${s}.service" &>/dev/null; then
        log " - systemctl start ${s}.service"
        systemctl start "${s}.service" 2>>"$REPORT" || log "   ! Failed to start ${s}.service (check later)"
    fi
done

log
log "8) Capturing final status for core units into log"
for s in "${CORE_STACK[@]}"; do
    if systemctl list-units "${s}.service" &>/dev/null; then
        {
            echo "--------------------------------------------------"
            echo "STATUS: ${s}.service"
            systemctl --no-pager --full status "${s}.service" || true
        } >>"$REPORT" 2>&1
    fi
done

log
log "=== Stage3 completed. Log file: ${REPORT} ==="
