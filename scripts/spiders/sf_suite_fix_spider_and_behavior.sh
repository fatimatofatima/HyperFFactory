#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
section(){
  printf '\n%s\n' "======================================================================"
  log "$*"
  echo "======================================================================"
}

BASE_DIR="/opt/smartfriend-suite"
SPIDER_SCRIPT="$BASE_DIR/scripts/sf_spider_run.sh"
SPIDER_UNIT="/etc/systemd/system/sf-spider.service"
PROG_UNIT="/etc/systemd/system/sf-bot-programmer.service"
BEHAV_UNIT="/etc/systemd/system/sf-bot-behavior.service"

section "بدء إصلاح SmartFriend Spider + Behavior Bot"

###############################################################################
# 1) إعادة بناء سكربت السبايدر sf_spider_run.sh
###############################################################################
section "إعادة بناء سكربت السبايدر: $SPIDER_SCRIPT"

mkdir -p "$(dirname "$SPIDER_SCRIPT")"

cat > "$SPIDER_SCRIPT" <<'SPIDER_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE_DIR="/opt/smartfriend-suite"
VENV_DIR="$BASE_DIR/venv"
PYTHON="$VENV_DIR/bin/python"

log(){ echo "[$(date '+%F %T')] [SPIDER] $*"; }

log "بدء تشغيل SmartFriend Spider..."

# 1) التحقق من وجود venv
if [[ ! -x "$PYTHON" ]]; then
  log "❌ venv غير موجود أو python غير قابل للتنفيذ عند: $PYTHON"
  exit 1
fi

# 2) اختيار ملف الإعداد الأفضل المتوفر
CONFIG=""
for c in \
  "$BASE_DIR/ops/spider_config_complete.yaml" \
  "$BASE_DIR/ops/spider_config_optimized.yaml" \
  "$BASE_DIR/ops/spider_config.yaml"
do
  if [[ -f "$c" ]]; then
    CONFIG="$c"
    break
  fi
done

if [[ -z "$CONFIG" ]]; then
  log "❌ لم يتم العثور على أي ملف إعداد spider_config*.yaml تحت $BASE_DIR/ops"
  exit 1
fi

log "استخدام ملف الإعداد: $CONFIG"

# 3) الانتقال لجذر السويت
cd "$BASE_DIR"

# 4) تشغيل العنكبوت الفعلي
exec "$PYTHON" "$BASE_DIR/services/harvester/spider/spider_main.py" --config "$CONFIG"
SPIDER_EOF

chmod +x "$SPIDER_SCRIPT"
log "تم إنشاء وتفعيل سكربت السبايدر: $SPIDER_SCRIPT"

###############################################################################
# 2) إنشاء/تحديث وحدة systemd للسبايدر sf-spider.service
###############################################################################
section "إنشاء/تحديث خدمة النظام: $SPIDER_UNIT"

cat > "$SPIDER_UNIT" <<'UNIT_EOF'
[Unit]
Description=SmartFriend Spider (Web Harvester)
After=network.target smartfrind-api.service smartfrind-gateway.service
Wants=smartfrind-api.service smartfrind-gateway.service

[Service]
Type=simple
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_spider_run.sh
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT_EOF

log "تم إنشاء/تحديث: $SPIDER_UNIT"

###############################################################################
# 3) إنشاء/تحديث sf-bot-behavior.service بناءً على sf-bot-programmer.service
###############################################################################
section "تجهيز خدمة Behavior Bot بناءً على Programmer Bot"

if [[ ! -f "$PROG_UNIT" ]]; then
  log "تحذير: لم يتم العثور على $PROG_UNIT - سيتم تخطي إنشاء sf-bot-behavior.service"
else
  log "نسخ $PROG_UNIT إلى $BEHAV_UNIT وتعديل الوصف والدور..."
  # نسخة مؤقتة
  tmp_file="${BEHAV_UNIT}.tmp"
  cp -a "$PROG_UNIT" "$tmp_file"

  # تعديل الوصف والدور
  sed -i \
    -e 's/Programmer Bot/Behavior Bot/g' \
    -e 's/--role programmer/--role behavior/g' \
    "$tmp_file"

  mv "$tmp_file" "$BEHAV_UNIT"
  log "تم إنشاء/تحديث: $BEHAV_UNIT"
fi

###############################################################################
# 4) daemon-reload + enable/start للخدمات
###############################################################################
section "تحديث systemd وتشغيل الخدمات"

systemctl daemon-reload

log "تم استدعاء systemctl daemon-reload"

# تفعيل وتشغيل السبايدر
if systemctl list-unit-files | awk '{print $1}' | grep -qx "sf-spider.service"; then
  log "تفعيل وتشغيل sf-spider.service..."
  systemctl enable --now sf-spider.service || log "تحذير: فشل تشغيل sf-spider.service"
else
  log "تحذير: sf-spider.service غير مسجّل في systemd list-unit-files لسبب ما."
fi

# تفعيل وتشغيل Behavior Bot إذا تم إنشاؤه
if [[ -f "$BEHAV_UNIT" ]]; then
  if systemctl list-unit-files | awk '{print $1}' | grep -qx "sf-bot-behavior.service"; then
    log "تفعيل وتشغيل sf-bot-behavior.service..."
    systemctl enable --now sf-bot-behavior.service || log "تحذير: فشل تشغيل sf-bot-behavior.service"
  else
    log "تحذير: sf-bot-behavior.service غير ظاهر في list-unit-files بعد الإنشاء."
  fi
else
  log "تم تجاوز تشغيل sf-bot-behavior.service لأنه لم يتم إنشاء الوحدة."
fi

###############################################################################
# 5) طباعة لقطة الحالة بعد الإصلاح
###############################################################################
section "لقطة حالة السويت بعد الإصلاح"

if [[ -x /root/sf_suite_status_now.sh ]]; then
  /root/sf_suite_status_now.sh || log "تحذير: sf_suite_status_now.sh أعاد خطأ"
else
  log "ملاحظة: /root/sf_suite_status_now.sh غير موجود أو غير قابل للتنفيذ - سيتم عرض حالة أساسية."
  systemctl status smartfrind-gateway.service smartfrind-api.service sf-bot-programmer.service sf-spider.service sf-bot-behavior.service --no-pager -l || true
fi

section "انتهى سكربت الإصلاح."
