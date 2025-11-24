#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }
info()  { echo -e "${BLUE}[ℹ] $*${NC}"; }

echo "================================================================"
echo "   🤖 SmartFrind - تفعيل نظام التعلم المستمر"
echo "================================================================"
echo

SMARTFRIND_ROOT="/opt/smartfrind"
REPO_URL="https://github.com/fatimatofatima/smartfrind.git"
REPO_DIR="/opt/smartfrind-repo"

# 1. استنساخ الريبو الرسمي
log "استنساخ الريبو الرسمي لـ SmartFrind..."
if [ ! -d "$REPO_DIR" ]; then
    git clone "$REPO_URL" "$REPO_DIR"
else
    cd "$REPO_DIR" && git pull
fi

# 2. نسخ السكربتات الأساسية إذا لم تكن موجودة
log "تحديث سكربتات SmartFrind..."
SCRIPTS=(
    "daily_spider.sh"
    "continuous_learning.sh" 
    "setup_cron.sh"
    "smart_deploy.sh"
    "fix_and_setup.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$REPO_DIR/$script" ]; then
        cp "$REPO_DIR/$script" "$SMARTFRIND_ROOT/"
        chmod +x "$SMARTFRIND_ROOT/$script"
        log "✅ تم تحديث: $script"
    else
        warn "⚠️  السكربت $script غير موجود في الريبو"
    fi
done

# 3. إنشاء systemd service للتعلم المستمر
log "إنشاء خدمة systemd للتعلم المستمر..."
cat > /etc/systemd/system/smartfrind-learning.service <<'SERVICE'
[Unit]
Description=SmartFrind Continuous Learning System
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfrind
ExecStart=/opt/smartfrind/continuous_learning.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# 4. إعداد cron للسبايدر اليومي
log "إعداد مهام cron للسبايدر اليومي..."
if [ -f "$SMARTFRIND_ROOT/setup_cron.sh" ]; then
    chmod +x "$SMARTFRIND_ROOT/setup_cron.sh"
    "$SMARTFRIND_ROOT/setup_cron.sh"
else
    # إعداد cron يدوي
    (crontab -l 2>/dev/null | grep -v "smartfrind"; echo -e "# SmartFrind Daily Spider\n0 2 * * * /opt/smartfrind/daily_spider.sh >> /var/log/smartfrind_spider.log 2>&1\n# SmartFrind Learning Check\n*/30 * * * * /opt/smartfrind/continuous_learning.sh >> /var/log/smartfrind_learning.log 2>&1") | crontab -
    log "✅ تم إعداد cron يدوياً"
fi

# 5. تشغيل الخدمات
log "تشغيل خدمة التعلم المستمر..."
systemctl daemon-reload
systemctl enable smartfrind-learning.service
systemctl start smartfrind-learning.service

# 6. فحص النتيجة
sleep 3
log "فحص حالة SmartFrind..."
if systemctl is-active smartfrind-learning.service >/dev/null; then
    log "✅ خدمة التعلم المستمر نشطة"
else
    error "❌ خدمة التعلم المستمر غير نشطة"
fi

if pgrep -f "smartfrind" >/dev/null; then
    log "✅ SmartFrind نشط (PID: $(pgrep -f 'smartfrind'))"
else
    warn "⚠️  SmartFrind غير نشط - قد يحتاج تشغيل يدوي"
fi

echo
echo "================================================================"
echo "   ✅ تم تفعيل SmartFrind بنجاح!"
echo "================================================================"
echo "📊 الخدمات النشطة:"
echo "   • smartfrind-learning.service - التعلم المستمر"
echo "   • SmartFrind Legacy - التطبيق الأساسي"
echo
echo "📅 مهام Cron:"
echo "   • 2:00 ص - السبايدر اليومي"
echo "   • كل 30 دقيقة - فحص التعلم"
echo
echo "📁 المسارات:"
echo "   • Runtime: /opt/smartfrind"
echo "   • Code Repo: /opt/smartfrind-repo"
echo "================================================================"
