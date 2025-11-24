#!/usr/bin/env bash
# HyperFFactory – Fix sf-web import path (apps.web) by adjusting WorkingDirectory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
UNIT="/etc/systemd/system/sf-web.service"
DROPIN_DIR="/etc/systemd/system/sf-web.service.d"
REPORT_DIR="$ROOT/reports"
BACKUP_DIR="$ROOT/backup_sf_web_unit"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_import_fix_${TS}.log"

exec > >(tee -a "$LOG") 2>&1

log() { echo "[$(date '+%F %T')] $*"; }

log "====================================================="
log "HyperFFactory – sf-web import fix (apps.web)"
log "SUITE_ROOT : $SUITE_ROOT"
log "UNIT       : $UNIT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

### 1) تأكيد هيكل السيوت (وجود apps/web/app.py تقريباً)
if [ -d "$SUITE_ROOT/apps/web" ]; then
    log "✓ تم العثور على مجلد التطبيقات: $SUITE_ROOT/apps/web"
    if [ -f "$SUITE_ROOT/apps/web/app.py" ]; then
        log "✓ تم العثور على ملف app.py داخل apps/web (كما يتوقعه import apps.web.app)"
    else
        log "⚠️ تحذير: لم نجد $SUITE_ROOT/apps/web/app.py – راجع الهيكل لكن سنكمل تعديل الخدمة"
    fi
else
    log "⚠️ تحذير: لم نجد المسار $SUITE_ROOT/apps/web – قد يكون الهيكل مختلفاً"
fi

### 2) نسخ احتياطي لملف الخدمة والـ drop-ins
if [ -f "$UNIT" ]; then
    cp -a "$UNIT" "$BACKUP_DIR/sf-web.service_${TS}.bak"
    log "✓ backup لـ sf-web.service إلى $BACKUP_DIR/sf-web.service_${TS}.bak"
else
    log "ℹ️ ملف الخدمة sf-web.service غير موجود – سيتم إنشاؤه من الصفر"
fi

if [ -d "$DROPIN_DIR" ]; then
    tar czf "$BACKUP_DIR/sf-web.service.d_${TS}.tar.gz" -C /etc/systemd/system sf-web.service.d
    log "✓ backup لـ $DROPIN_DIR إلى $BACKUP_DIR/sf-web.service.d_${TS}.tar.gz"
else
    log "ℹ️ لا يوجد مجلد drop-in لـ sf-web.service (عادي)"
fi

### 3) إعادة بناء sf-web.service بحيث يكون WorkingDirectory = /opt/smartfriend-suite
log "✓ كتابة ملف خدمة جديد /etc/systemd/system/sf-web.service بالقيم الصحيحة"

cat > "$UNIT" <<'UNITEOF'
[Unit]
Description=SmartFriend Web UI (8390)
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
# مهم: الجذر هنا هو السيوت بالكامل حتى يعمل import apps.web
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
Restart=on-failure
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
UNITEOF

chmod 644 "$UNIT"

### 4) ضبط صلاحيات المرور على المسارات
log "✓ ضبط صلاحيات المرور على /opt و $SUITE_ROOT"
chmod 755 /opt || true
chmod 755 "$SUITE_ROOT" || true
[ -d "$SUITE_ROOT/web" ] && chmod 755 "$SUITE_ROOT/web" || true

if id smartfriend-suite >/dev/null 2>&1; then
    log "✓ ضبط الملكية إلى smartfriend-suite:smartfriend-suite على $SUITE_ROOT"
    chown -R smartfriend-suite:smartfriend-suite "$SUITE_ROOT"
else
    log "⚠️ المستخدم smartfriend-suite غير موجود – تأكد من إنشائه قبل التشغيل"
fi

### 5) daemon-reload + restart + status + health
log "✓ systemctl daemon-reload"
systemctl daemon-reload

log "▶️ إعادة تشغيل sf-web.service"
if ! systemctl restart sf-web.service; then
    log "⚠️ فشل في restart – راجع status في الأسطر التالية"
fi

sleep 2
log "=== systemctl status sf-web (أول 40 سطر) ==="
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' || true

log "=== Health check على 8390 ==="
curl -s http://127.0.0.1:8390/health || echo "❌ Web UI /health غير متاح"
curl -s http://127.0.0.1:8390/       || echo "❌ Web UI / غير متاح"

log "====================================================="
log "DONE – hf_sf_web_import_fix finished"
log "Report: $LOG"
log "====================================================="
