#!/usr/bin/env bash
# HyperFFactory – Smart check & fix for sf-* (focus: sf-web + cleanup)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
BACKUP_DIR="$ROOT/backup_systemd_dropins"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_smart_web_fix_${TS}.log"

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
log "HyperFFactory – Smart check & fix for sf-core/sf-health/sf-memory/sf-web"
log "ROOT       : $ROOT"
log "SUITE_ROOT : $SUITE_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

if [ ! -d "$SUITE_ROOT" ]; then
  log "❌ SUITE_ROOT غير موجود: $SUITE_ROOT"
  exit 1
fi

###############################################################################
# 1) Snapshot قبل الإصلاح
###############################################################################
header "1) Pre-status snapshot (sf-core/sf-health/sf-memory/sf-web)"

systemctl --no-pager -l status sf-core sf-health sf-memory sf-web 2>&1 \
  | sed -n '1,200p' | tee -a "$LOG" || true

###############################################################################
# 2) تنظيف drop-ins المعطوبة 70-hf-autopath.conf (مع أرشفة)
###############################################################################
header "2) Cleanup invalid 70-hf-autopath.conf drop-ins (archive, no delete)"

for unit in sf-core sf-health sf-memory sf-web; do
  d="/etc/systemd/system/${unit}.service.d"
  f="$d/70-hf-autopath.conf"
  if [ -f "$f" ]; then
    backup_target="$BACKUP_DIR/${unit}_70-hf-autopath.conf_${TS}"
    mv "$f" "$backup_target"
    log "✓ نقلنا $f → $backup_target (إزالة التحذير Loaded: bad عن هذا الملف)"
  else
    log "ℹ️ لا يوجد 70-hf-autopath.conf للوحدة $unit – تخطي"
  fi
done

###############################################################################
# 3) ضمان وجود run_web.py تحت /opt/smartfriend-suite/web
###############################################################################
header "3) Ensure /opt/smartfriend-suite/web/run_web.py exists"

WEB_DIR="$SUITE_ROOT/web"
WEB_FILE="$WEB_DIR/run_web.py"
SRC_WEB="/root/HyperFFactory/collected_scripts_from_opt/run_web.py"

mkdir -p "$WEB_DIR"

if [ ! -f "$WEB_FILE" ]; then
  if [ -f "$SRC_WEB" ]; then
    cp "$SRC_WEB" "$WEB_FILE"
    log "✓ نسخنا run_web.py من $SRC_WEB إلى $WEB_FILE"
  else
    log "⚠️ لا يوجد $WEB_FILE ولا $SRC_WEB – sf-web قد يظل متوقفاً لعدم وجود سكربت الويب"
  fi
else
  log "ℹ️ run_web.py موجود بالفعل في $WEB_FILE – لن نعدّله"
fi

# ملكية web/ إن وجد المستخدم
if id smartfriend-suite >/dev/null 2>&1; then
  chown -R smartfriend-suite:smartfriend-suite "$WEB_DIR"
  log "✓ عدّلنا ملكية $WEB_DIR إلى smartfriend-suite:smartfriend-suite"
else
  log "ℹ️ مستخدم smartfriend-suite غير موجود – تخطي chown لـ web"
fi

###############################################################################
# 4) كتابة Drop-in نهائي لـ sf-web يفرض المسار الصحيح
###############################################################################
header "4) Write 80-hf-web-final.conf for sf-web (WorkingDirectory + ExecStart)"

SF_WEB_DIR="/etc/systemd/system/sf-web.service.d"
mkdir -p "$SF_WEB_DIR"

cat > "$SF_WEB_DIR/80-hf-web-final.conf" <<'CONF'
[Service]
# إجبار Web UI على العمل من داخل /opt/smartfriend-suite/web
WorkingDirectory=/opt/smartfriend-suite/web

# تنظيف أي ExecStart سابق واستبداله بأمر واحد واضح
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF

log "✓ كتبنا $SF_WEB_DIR/80-hf-web-final.conf (أعلى أولوية للويب)"

###############################################################################
# 5) daemon-reload + restart للخدمات الأساسية
###############################################################################
header "5) systemd daemon-reload + restart sf-core/sf-health/sf-memory/sf-web"

log "▶️ systemctl daemon-reload"
systemctl daemon-reload

for s in sf-core sf-health sf-memory sf-web; do
  if systemctl list-unit-files | awk '{print $1}' | grep -q "^${s}.service$"; then
    log "▶️ إعادة تشغيل ${s}.service"
    if systemctl restart "${s}.service"; then
      log "✓ ${s}.service أعيد تشغيله بنجاح"
    else
      log "⚠️ فشل في إعادة تشغيل ${s}.service – راجع status في الخطوة التالية"
    fi
  else
    log "ℹ️ ${s}.service غير موجود – تخطي"
  fi
done

###############################################################################
# 6) Snapshot بعد الإصلاح
###############################################################################
header "6) Post-status snapshot (sf-core/sf-health/sf-memory/sf-web)"

systemctl --no-pager -l status sf-core sf-health sf-memory sf-web 2>&1 \
  | sed -n '1,220p' | tee -a "$LOG" || true

###############################################################################
# 7) Health checks على /health
###############################################################################
header "7) Health checks via curl"

log "---- curl 8211 (core) ----"
curl -s http://127.0.0.1:8211/health || echo "❌ Core API غير متاح" | tee -a "$LOG"

log "---- curl 8210 (health gate) ----"
curl -s http://127.0.0.1:8210/health || echo "❌ Health Gate غير متاح" | tee -a "$LOG"

log "---- curl 8214 (memory) ----"
curl -s http://127.0.0.1:8214/health || echo "❌ Memory API غير متاح" | tee -a "$LOG"

log "---- curl 8390 (web) ----"
curl -s http://127.0.0.1:8390/health || echo "❌ Web UI غير متاح" | tee -a "$LOG"

log "====================================================="
log "DONE – hf_sf_smart_web_fix finished"
log "Report: $LOG"
log "====================================================="

