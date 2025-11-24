#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

SERVICE_UNIT="/etc/systemd/system/ff-doctor.service"
TIMER_UNIT="/etc/systemd/system/ff-doctor.timer"
EXEC_SCRIPT="/opt/ffactory/scripts/ff_doctor_enhanced.sh"
SERVICE_USER="ffactory"
SERVICE_GROUP="ffactory"

log "إصلاح تعريف ff-doctor.service + ff-doctor.timer (طبقة ffactory فقط)..."

# إيقاف أي تشغيل حالي
systemctl stop ff-doctor.service 2>/dev/null || true
systemctl stop ff-doctor.timer 2>/dev/null || true

# فحص وجود سكربت التنفيذ
if [ ! -f "$EXEC_SCRIPT" ]; then
  log "تحذير: سكربت التنفيذ غير موجود: $EXEC_SCRIPT"
  log "لن تفشل العملية، لكن ff-doctor سيفشل عند التشغيل حتى تضيف السكربت."
fi

log "كتابة ff-doctor.service إلى $SERVICE_UNIT ..."
cat > "$SERVICE_UNIT" <<'UNIT'
[Unit]
Description=FFactory Doctor - Self-healing watchdog
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=ffactory
Group=ffactory
ExecStart=/opt/ffactory/scripts/ff_doctor_enhanced.sh
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

# حماية أساسية
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
UNIT

log "كتابة ff-doctor.timer إلى $TIMER_UNIT ..."
cat > "$TIMER_UNIT" <<'UNIT'
[Unit]
Description=FFactory Doctor Timer (every 60 seconds)

[Timer]
OnBootSec=5min
OnUnitActiveSec=60s
AccuracySec=15s
Unit=ff-doctor.service
Persistent=true

[Install]
WantedBy=timers.target
UNIT

log "إعادة تحميل systemd..."
systemctl daemon-reload

log "تفعيل الخدمة والمؤقت على الإقلاع..."
systemctl enable ff-doctor.service >/dev/null 2>&1 || true
systemctl enable ff-doctor.timer >/dev/null 2>&1 || true

log "تشغيل المؤقت الآن..."
systemctl start ff-doctor.timer

log "حالة ff-doctor الحالية:"
systemctl status ff-doctor.service ff-doctor.timer --no-pager || true

log "اكتمل ff_doctor_fix_units: تم تثبيت تعريف واحد رسمي في /etc/systemd/system/."
