#!/usr/bin/env bash
# HyperFFactory – Fix sf-core/sf-health/sf-memory/sf-web WD & PYTHONPATH

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
WEB_DIR="$ROOT/collected_scripts_from_opt"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_fix_sf_services_root_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

create_dropin() {
  local unit="$1"
  local content="$2"
  local dir="/etc/systemd/system/${unit}.service.d"
  mkdir -p "$dir"
  local file="${dir}/60-hf-root.conf"
  printf '%s\n' "$content" > "$file"
  log "✅ كتبنا $file"
}

log "====================================================="
log "HyperFFactory – Fix sf-core/sf-health/sf-memory/sf-web WD & PYTHONPATH"
log "ROOT : $ROOT"
log "TIME : $TS"
log "====================================================="

# sf-core / sf-health / sf-memory → ROOT
for unit in sf-core sf-health sf-memory; do
  if [ -f "/etc/systemd/system/${unit}.service" ]; then
    create_dropin "$unit" "[Service]
WorkingDirectory=${ROOT}
Environment=PYTHONPATH=${ROOT}"
  else
    log "ℹ️ ${unit}.service غير موجود (تخطي)"
  fi
done

# sf-web → WEB_DIR (لو موجود) وإلا ROOT
if [ -f "/etc/systemd/system/sf-web.service" ]; then
  if [ -d "$WEB_DIR" ]; then
    WD="$WEB_DIR"
  else
    WD="$ROOT"
  fi
  create_dropin "sf-web" "[Service]
WorkingDirectory=${WD}
Environment=PYTHONPATH=${WD}:${ROOT}"
else
  log "ℹ️ sf-web.service غير موجود (تخطي)"
fi

log "▶️ systemctl daemon-reload"
systemctl daemon-reload

for unit in sf-core sf-health sf-memory sf-web; do
  if systemctl list-unit-files | grep -q "^${unit}.service"; then
    log "▶️ إعادة تشغيل ${unit}.service"
    if systemctl restart "${unit}.service"; then
      log "✅ ${unit}.service تم إعادة تشغيله"
    else
      log "⚠️ فشل في إعادة تشغيل ${unit}.service – راجع journalctl -u ${unit}.service"
    fi
  fi
done

log "====================================================="
log "✅ انتهى سكربت hf_fix_sf_services_root"
log "📄 تقرير التنفيذ في: $LOG"
log "====================================================="
