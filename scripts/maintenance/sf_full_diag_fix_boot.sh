#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS=$(date '+%Y%m%d_%H%M%S')
LOG="/root/sf_full_diag_fix_boot_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "============================================================"
log " SmartFriend / FFactory - فحص + إصلاح + تشغيل شامل دائم"
log "  LOG: ${LOG}"
log "============================================================"

# دالة مساعدة لتفادي خروج السكربت عند فشل systemctl
safe_systemctl() {
  local CMD="systemctl $*"
  $CMD >>"$LOG" 2>&1 || log "⚠️ فشل أمر: ${CMD} (متابعة التنفيذ)"
}

# -------------------------------------------------------------
# 1) تشغيل المسح الشامل الموجود (إن وُجد)
# -------------------------------------------------------------
if [ -x /root/sf_comprehensive_project_scan.sh ]; then
  log "تشغيل سكربت المسح الشامل /root/sf_comprehensive_project_scan.sh ..."
  /root/sf_comprehensive_project_scan.sh >>"$LOG" 2>&1 || log "⚠️ سكربت المسح أعاد كود خطأ (متابعة)."
else
  log "⚠️ سكربت المسح /root/sf_comprehensive_project_scan.sh غير موجود أو غير قابل للتنفيذ – تخطي."
fi

# -------------------------------------------------------------
# 2) ضمان وجود Users / Groups و Permissions رئيسية
# -------------------------------------------------------------

log "ضمان وجود مستخدم smartfriend-suite..."
if ! getent group smartfriend-suite >/dev/null 2>&1; then
  groupadd --system smartfriend-suite >>"$LOG" 2>&1 || log "⚠️ تعذر إنشاء group smartfriend-suite (ربما موجودة)."
else
  log "المجموعة smartfriend-suite موجودة."
fi

if ! id smartfriend-suite >/dev/null 2>&1; then
  useradd --system \
    --home-dir /opt/smartfriend-suite \
    --shell /usr/sbin/nologin \
    --gid smartfriend-suite \
    smartfriend-suite >>"$LOG" 2>&1 || log "⚠️ تعذر إنشاء user smartfriend-suite (ربما موجود)."
else
  log "المستخدم smartfriend-suite موجود."
fi

log "تثبيت صلاحيات دلائل SmartFriend Suite الأساسية..."
chown -R smartfriend-suite:smartfriend-suite \
  /opt/smartfriend-suite/var \
  /opt/smartfriend-suite/logs \
  /opt/smartfriend-suite/data >>"$LOG" 2>&1 || log "⚠️ مشكلة أثناء chown على دلائل السيوت (متابعة)."

log "ضمان وجود مستخدم ffactory..."
if ! getent group ffactory >/dev/null 2>&1; then
  groupadd --system ffactory >>"$LOG" 2>&1 || log "⚠️ تعذر إنشاء group ffactory (ربما موجودة)."
else
  log "المجموعة ffactory موجودة."
fi

if ! id ffactory >/dev/null 2>&1; then
  useradd --system \
    --home-dir /opt/ffactory \
    --shell /usr/sbin/nologin \
    --gid ffactory \
    ffactory >>"$LOG" 2>&1 || log "⚠️ تعذر إنشاء user ffactory (ربما موجود)."
else
  log "المستخدم ffactory موجود."
fi

if [ -d /opt/ffactory ]; then
  log "تثبيت صلاحيات /opt/ffactory للمستخدم ffactory..."
  chown -R ffactory:ffactory /opt/ffactory >>"$LOG" 2>&1 || log "⚠️ مشكلة أثناء chown /opt/ffactory (متابعة)."
else
  log "⚠️ المسار /opt/ffactory غير موجود – سيتم تخطي بعض إصلاحات ffactory."
fi

# -------------------------------------------------------------
# 3) تفعيل/ربط طبقة Brain في السيوت
# -------------------------------------------------------------

log "ربط وتشغيل طبقة Brain في SmartFriend Suite..."

if [ -x /root/sf_suite_brain_fix.sh ]; then
  log "تشغيل /root/sf_suite_brain_fix.sh ..."
  /root/sf_suite_brain_fix.sh >>"$LOG" 2>&1 || log "⚠️ سكربت sf_suite_brain_fix.sh أعاد كود خطأ (متابعة)."
else
  log "⚠️ سكربت sf_suite_brain_fix.sh غير موجود – سيتم ضبط الحد الأدنى يدويًا."
  # حد أدنى: ضمان صلاحية سكربتات Brain إن وجدت
  for s in sf_brain_ingest.sh sf_brain_learn.sh sf_brain_learning_loop.sh sf_kb_build.sh sf_fts_maint.sh; do
    if [ -f "/opt/smartfriend-suite/scripts/${s}" ]; then
      chmod +x "/opt/smartfriend-suite/scripts/${s}" >>"$LOG" 2>&1 || true
    fi
  done
fi

# إعادة تحميل وحدات systemd بعد أي تعديل
log "إعادة تحميل systemd للوحدات..."
safe_systemctl daemon-reload

# محاولة تفعيل وتشغيل وحدات Brain الأساسية
for UNIT in sf-ingest.service sf-learn.service sf-learning.service sf-kb-build.service sf-fts-maint.service; do
  log "تفعيل ${UNIT} على مستوى الإقلاع (إن وجد)..."
  safe_systemctl enable "$UNIT"
  log "تشغيل ${UNIT} الآن..."
  safe_systemctl restart "$UNIT"
done

# -------------------------------------------------------------
# 4) إصلاح ff-doctor وربطه بالمستخدم ffactory
# -------------------------------------------------------------
log "إصلاح ff-doctor.service وربطه بـ ffactory..."

if [ -d /opt/ffactory ]; then
  mkdir -p /opt/ffactory/scripts /opt/ffactory/logs

  # سكربت ff_doctor_enhanced.sh (حارس بسيط، يمكن توسيعه لاحقًا)
  cat > /opt/ffactory/scripts/ff_doctor_enhanced.sh <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="/opt/ffactory/logs"
mkdir -p "$LOG_DIR"
LOG="${LOG_DIR}/ff_doctor_enhanced.log"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "==============================================="
log " FFactory Doctor Enhanced - start"
log "==============================================="

# Placeholder: يمكن لاحقًا إضافة فحص Docker, healthd, board ...إلخ
while true; do
  log "tick: ff-doctor watchdog قيد التشغيل"
  sleep 60
done
EOS

  chmod +x /opt/ffactory/scripts/ff_doctor_enhanced.sh

  # إعادة تعريف وحدة ff-doctor.service لتستخدم ffactory + السكربت الجديد
  cat > /etc/systemd/system/ff-doctor.service <<'EOS'
[Unit]
Description=FFactory Doctor - Self-healing watchdog
After=network.target

[Service]
Type=simple
User=ffactory
Group=ffactory
WorkingDirectory=/opt/ffactory
ExecStart=/opt/ffactory/scripts/ff_doctor_enhanced.sh
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOS

  log "إعادة تحميل systemd بعد تعديل ff-doctor.service..."
  safe_systemctl daemon-reload

  log "تفعيل ff-doctor.service و ff-doctor.timer..."
  safe_systemctl enable ff-doctor.service
  safe_systemctl enable ff-doctor.timer

  log "إعادة تشغيل ff-doctor.timer..."
  safe_systemctl restart ff-doctor.timer
else
  log "⚠️ /opt/ffactory غير موجود – تخطي إعداد ff-doctor."
fi

# -------------------------------------------------------------
# 5) تشغيل الخدمات الأساسية في SmartFriend Suite و SmartFrind
# -------------------------------------------------------------

log "تفعيل وتشغيل خدمات SmartFriend Suite الأساسية..."

CORE_UNITS=(
  sf-core.service
  sf-unified.service
  sf-web.service
  sf-health.service
  sf-memory.service
  sf-smartfriend.service
  sf-smartfrind.service
  sf-bot.service
  sf-telegram.service
  sf-smartfactory.service
)

for UNIT in "${CORE_UNITS[@]}"; do
  log "تفعيل ${UNIT} (إن وجد)..."
  safe_systemctl enable "$UNIT"
  log "تشغيل ${UNIT}..."
  safe_systemctl restart "$UNIT"
done

log "تفعيل Timers الخاصة بالسيوت..."

SF_TIMERS=(
  sf-smoke.timer
  sf-spider.timer
  sf-backup.timer
  sf-db-backup.timer
  sf-db-maintenance.timer
  sf-download.timer
  sf-fts-maint.timer
  sf-kb-build.timer
  sf-keys-rotate.timer
  sf-learn.timer
)

for T in "${SF_TIMERS[@]}"; do
  log "تفعيل ${T}..."
  safe_systemctl enable "$T"
  safe_systemctl restart "$T"
done

# SmartFrind stack
log "تفعيل وتشغيل SmartFrind stack..."

SMARTFRIND_UNITS=(
  smartfrind-core.service
  smartfrind-gateway.service
  smartfrind-qa.service
  smartfrind-guardian.service
  smartfrind-envwatch.service
)

for UNIT in "${SMARTFRIND_UNITS[@]}"; do
  log "تفعيل ${UNIT}..."
  safe_systemctl enable "$UNIT"
  log "تشغيل ${UNIT}..."
  safe_systemctl restart "$UNIT"
done

# -------------------------------------------------------------
# 6) ملخص حالة الوحدات الحرجة
# -------------------------------------------------------------
log "استخراج ملخص حالة الوحدات الحرجة..."

{
  echo
  echo "===== STATUS SUMMARY: SF Brain Stack ====="
  systemctl status sf-ingest.service sf-learn.service sf-learning.service sf-kb-build.service sf-fts-maint.service --no-pager || true
  echo
  echo "===== STATUS SUMMARY: SF core/unified/web ====="
  systemctl status sf-core.service sf-unified.service sf-web.service sf-health.service sf-memory.service --no-pager || true
  echo
  echo "===== STATUS SUMMARY: SmartFrind core/gateway ====="
  systemctl status smartfrind-core.service smartfrind-gateway.service smartfrind-qa.service smartfrind-guardian.service --no-pager || true
  echo
  echo "===== STATUS SUMMARY: FFactory Doctor ====="
  systemctl status ff-doctor.service ff-doctor.timer --no-pager || true
} >>"$LOG" 2>&1 || true

log "اكتمل sf_full_diag_fix_boot. راجع اللوج: ${LOG}"
