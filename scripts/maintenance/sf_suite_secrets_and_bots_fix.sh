#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان بسيطة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

log "=== SmartFriend Suite – تحديث المفاتيح + إصلاح بوتات تيليجرام والنسخ الاحتياطي ==="
echo

#############################################
# 0) تعريف المفاتيح (كما أعطيتها أنت – تجريبية)
#############################################


# Bots mapping (حسب الأسماء اللي أرسلتها)
# 1) Psmart training @Threenext_bot  -> نربطه بالـ sf-telegram (بوت التدريب الرئيسي)
TELEGRAM_TOKEN_PSMART_TRAINING="8493429114:AAGQrZ42tFGo4UvaOjbr2cu5qfS59TZE70g"

# 2) Winnwonet_bot @Winnwonet_bot (يتم حفظه في ملف extra)
TELEGRAM_TOKEN_WINNWONET="8236695795:AAG6VT6KIo4XjTtHVYz92d8MKzzaTJOEUQ0"

# 3) SmartFactorybot @TestNextsmart_bot -> نربطه بالـ sf-smartfactory
TELEGRAM_TOKEN_SMARTFACTORY="8241529778:AAHEJRnUC1ZkFXDLvJrsVrPBs2YTXNPsU6w"

# 4) SmartFrind @SmartFrindbot -> نربطه ببوت smartfrind-bot.service
TELEGRAM_TOKEN_SMARTFRIND="7985788141:AAGEWK4Qs-NTamwaN3F10q6qC3CVq3d_QA8"

# 5) Psmartp_bot @Psmartp_bot (extra)
TELEGRAM_TOKEN_PSMARTP="8338003920:AAH7jN2cIOg_hz2AlR_k5B0L5G8ObJgzO7s"

# 6) Nextwin @Smartnext_bot (extra)
TELEGRAM_TOKEN_NEXTWIN="8228013890:AAF7qv4-ShMV1z9FDskjvyQ1b3Ook7B1ekw"

# 7) Myservtiydatatesr @Myservtiydatatesr_bot (extra)
TELEGRAM_TOKEN_MYSERVTIY="7979966842:AAF6TQORUPJZ0ZBqYSwnvKNOAQL3ymUDtpw"

# مالك البوت (للاستخدام المستقبلي – لا نربطه بخدمة معيّنة الآن)
TELEGRAM_OWNER_ID="795444729"
TELEGRAM_OWNER_USERNAME="@usamasobh"
TELEGRAM_OWNER_NAME="Abu Hazem"
TELEGRAM_OWNER_LANG="ar"

#############################################
# 1) إنشاء/تحديث ملفات الـ ENV الخاصة بالبوتات
#############################################

mkdir -p /etc/smartfriend /etc/smartfrind

# sf-telegram.env  -> بوت التدريب الرئيسي (Psmart training)
cat >/etc/smartfriend/sf-telegram.env <<EOF_SFTELE
# Main training bot (Psmart training – @Threenext_bot)
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_PSMART_TRAINING}
# Owner (meta – optional)
TELEGRAM_OWNER_ID=${TELEGRAM_OWNER_ID}
TELEGRAM_OWNER_USERNAME=${TELEGRAM_OWNER_USERNAME}
TELEGRAM_OWNER_NAME=${TELEGRAM_OWNER_NAME}
TELEGRAM_OWNER_LANG=${TELEGRAM_OWNER_LANG}
EOF_SFTELE

chmod 600 /etc/smartfriend/sf-telegram.env
chown root:root /etc/smartfriend/sf-telegram.env
success "   /etc/smartfriend/sf-telegram.env تم تحديثه."

# sf-smartfactory.env -> بوت SmartFactorybot
cat >/etc/smartfriend/sf-smartfactory.env <<EOF_SFFACT
# SmartFactory bot – @TestNextsmart_bot
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_SMARTFACTORY}
EOF_SFFACT

chmod 600 /etc/smartfriend/sf-smartfactory.env
chown root:root /etc/smartfriend/sf-smartfactory.env
success "   /etc/smartfriend/sf-smartfactory.env تم تحديثه."

# /etc/smartfrind/bot.env -> بوت SmartFrindbot
cat >/etc/smartfrind/bot.env <<EOF_SFBR
# SmartFrind main bot – @SmartFrindbot
TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_SMARTFRIND}
EOF_SFBR

chmod 600 /etc/smartfrind/bot.env
chown root:root /etc/smartfrind/bot.env
success "   /etc/smartfrind/bot.env تم تحديثه."

# ملف إضافي لتجميع باقي البوتات (مرجع فقط حالياً)
cat >/etc/smartfriend/sf-bots-extra.env <<EOF_EXTRA
# Extra bots tokens (للاستخدام المستقبلي – ليست مربوطة بخدمات مباشرة الآن)

# Winnwonet_bot @Winnwonet_bot
TELEGRAM_TOKEN_WINNWONET=${TELEGRAM_TOKEN_WINNWONET}

# Psmartp_bot @Psmartp_bot
TELEGRAM_TOKEN_PSMARTP=${TELEGRAM_TOKEN_PSMARTP}

# Nextwin @Smartnext_bot
TELEGRAM_TOKEN_NEXTWIN=${TELEGRAM_TOKEN_NEXTWIN}

# Myservtiydatatesr_bot @Myservtiydatatesr_bot
TELEGRAM_TOKEN_MYSERVTIY=${TELEGRAM_TOKEN_MYSERVTIY}
EOF_EXTRA

chmod 600 /etc/smartfriend/sf-bots-extra.env
chown root:root /etc/smartfriend/sf-bots-extra.env
success "   /etc/smartfriend/sf-bots-extra.env تم حفظ باقي التوكنات فيه (مرجع)."

echo

#############################################
# 2) إصلاح واضح لنسخ الاحتياطي (مجلد backups)
#############################################
log "2) تجهيز مسار النسخ الاحتياطي لمنع أخطاء No such file or directory..."

BACKUP_DIR="/opt/smartfriend-suite/data/archive/backups"
mkdir -p "$BACKUP_DIR"
chmod 750 "$BACKUP_DIR" || true
success "   تم التأكد من وجود المجلد: $BACKUP_DIR"

echo

#############################################
# 3) إعادة تحميل systemd وتشغيل الخدمات الأساسية
#############################################
log "3) إعادة تحميل systemd وتشغيل الخدمات الأساسية للسيوت + البنية التحتية..."

systemctl daemon-reload || true

CORE_SERVICES=(
  sf-core.service
  smartfrind-api.service
  smartfrind-qa.service
  smartfrind-gateway.service
  smartfrind-runner.service
  smartfrind-envwatch.service
  sf-web.service
)

INFRA_SERVICES=(
  deepseek-api.service
  factory-gw.service
  ff-healthd.service
)

TELEGRAM_SERVICES=(
  sf-bot.service
  sf-telegram.service
  sf-telegram-audit.service
  sf-smartfactory.service
  smartfrind-bot.service
)

start_or_restart_service() {
  local svc="$1"
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    return 0
  fi
  local enabled_state
  enabled_state="$(systemctl is-enabled "$svc" 2>/dev/null || echo unknown)"
  log "   ▸ معالجة $svc (enabled=$enabled_state)..."
  if [ "$enabled_state" = "enabled" ] || [ "$enabled_state" = "static" ]; then
    if systemctl restart "$svc" 2>/dev/null; then
      success "      $svc restarted."
    else
      warn "      فشل restart لـ $svc"
    fi
  else
    if systemctl start "$svc" 2>/dev/null; then
      success "      $svc started."
    else
      warn "      فشل start لـ $svc"
    fi
  fi
}

log "   ▸ الخدمات الأساسية:"
for svc in "${CORE_SERVICES[@]}"; do
  start_or_restart_service "$svc"
done

log "   ▸ خدمات البنية التحتية:"
for svc in "${INFRA_SERVICES[@]}"; do
  start_or_restart_service "$svc"
done

log "   ▸ بوتات تيليجرام (باستخدام المفاتيح الجديدة):"
for svc in "${TELEGRAM_SERVICES[@]}"; do
  start_or_restart_service "$svc"
done

echo

#############################################
# 4) فحص سريع للحالة بعد الإصلاح
#############################################
log "4) فحص حالة الخدمات الأساسية والبوتات بعد التشغيل..."

check_services=(
  sf-core.service
  smartfrind-api.service
  smartfrind-qa.service
  smartfrind-gateway.service
  smartfrind-runner.service
  sf-web.service
  sf-telegram.service
  sf-telegram-audit.service
  sf-smartfactory.service
  smartfrind-bot.service
  sf-bot.service
)

for svc in "${check_services[@]}"; do
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    continue
  fi
  state="$(systemctl is-active "$svc" 2>/dev/null || echo unknown)"
  if [ "$state" = "active" ]; then
    success "   $svc :: active"
  else
    warn "   $svc :: state=$state (يحتاج مراجعة لو استمر كده)"
  fi
done

echo

#############################################
# 5) فحص البورتات الأساسية
#############################################
log "5) فحص البورتات (8000 / 8170 / 8220 / 8383)..."

for port in 8000 8170 8220 8383; do
  if ss -tulpn 2>/dev/null | grep -q ":$port "; then
    success "   البورت $port مفتوح."
  else
    warn "   البورت $port غير مفتوح أو الخدمة المرتبطة مش شغالة."
  fi
done

echo
success "=== انتهى سكربت تحديث المفاتيح + إصلاح وتشغيل الخدمات الأساسية والبوتات ==="
echo "لو حبيت تغيّر أي توكن لاحقًا، عدّل مباشرة ملفات:"
echo "  - /etc/smartfriend/sf-telegram.env"
echo "  - /etc/smartfriend/sf-smartfactory.env"
echo "  - /etc/smartfrind/bot.env"
echo "ثم نفّذ: systemctl restart <الخدمة_المطلوبة>"
