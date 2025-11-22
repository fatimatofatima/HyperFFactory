#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
ok()   { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }

unit_exists() {
    local u="$1"
    systemctl list-unit-files "$u" --no-legend 2>/dev/null | grep -q .
}

enable_and_restart() {
    local u="$1"
    if ! unit_exists "$u"; then
        warn "تخطي (الوحدة غير موجودة على هذا السيرفر): $u"
        return
    fi
    log "تمكين + إعادة تشغيل: $u"
    if systemctl enable "$u" >/dev/null 2>&1; then
        ok "enable: $u"
    else
        warn "فشل enable (قد تكون مفعّلة بالفعل): $u"
    fi

    if systemctl restart "$u"; then
        ok "restart: $u"
    else
        warn "فشل restart: $u (تحقّق من logs الوحدة)"
    fi
}

disable_and_stop() {
    local u="$1"
    if ! unit_exists "$u"; then
        warn "تخطي (الوحدة غير موجودة على هذا السيرفر): $u"
        return
    fi
    log "إيقاف + تعطيل: $u"
    if systemctl disable "$u" >/dev/null 2>&1; then
        ok "disable: $u"
    else
        warn "فشل disable (قد تكون معطّلة بالفعل): $u"
    fi

    if systemctl stop "$u" >/dev/null 2>&1; then
        ok "stop: $u"
    else
        warn "فشل stop (قد تكون متوقفة بالفعل): $u"
    fi
}

log "=== SmartFriend Suite – قفل بروفايل التشغيل (الحد الأدنى المستقر) ==="
echo

# ----------------------------------------------------------------------
# 1) طبقة SmartFriend Suite الرسمية (Core + Web + Bots)
# ----------------------------------------------------------------------
ESSENTIAL_SUITE=(
    sf-core.service
    sf-unified.service
    sf-memory.service
    sf-health.service
    sf-web.service

    sf-bot.service
    sf-bot-assistant.service
    sf-smartfriend.service
    sf-telegram.service
)

log "--- [1] تمكين وتشغيل طبقة SmartFriend Suite الرسمية ---"
for u in "${ESSENTIAL_SUITE[@]}"; do
    enable_and_restart "$u"
done
echo

# ----------------------------------------------------------------------
# 2) واجهات SmartFriend الرسمية (smartfriend-*)
# ----------------------------------------------------------------------
OFFICIAL_SMARTFRIEND_API=(
    smartfriend-api.service
    smartfriend-smartcore.service
    smartfriend-hybrid.service
    smartfriend-unified.service
)

log "--- [2] تمكين وتشغيل واجهات SmartFriend الرسمية (smartfriend-*) ---"
for u in "${OFFICIAL_SMARTFRIEND_API[@]}"; do
    enable_and_restart "$u"
done
echo

# ----------------------------------------------------------------------
# 3) طبقة SmartFrind Legacy كـ Engines داخل السيوت
# ----------------------------------------------------------------------
LEGACY_ENGINES=(
    smartfrind-core.service
    smartfrind-unified.service
    smartfrind-final.service

    smartfrind-runner.service

    smartfrind-learning.service
    smartfrind-trainer.service
    smartfrind-learner.service

    smartfrind-guardian.service
    smartfrind-envwatch.service
)

log "--- [3] تمكين وتشغيل طبقة SmartFrind Legacy كـ محركات داخلية ---"
for u in "${LEGACY_ENGINES[@]}"; do
    enable_and_restart "$u"
done
echo

# ----------------------------------------------------------------------
# 4) تعطيل بوابات SmartFrind القديمة + الـ Watchdogs المرتبطة
#     (لا تُستخدم كواجهات رسمية – تبقى مغلقة افتراضيًا)
# ----------------------------------------------------------------------
LEGACY_GATEWAYS_DISABLE=(
    smartfrind-api.service
    smartfrind-gateway.service
    smartfrind-local.service
    smartfrind-qa.service
    smartfrind-monitor.service
    smartfrind-advanced.service
    smartfrind-ask.service
    smartfrind-simple.service
    smartfrind-ultra.service
)

LEGACY_WATCHDOGS_DISABLE=(
    smartfrind-watchdog.service
    smartfrind-core-watchdog.service
)

log "--- [4] تعطيل بوابات SmartFrind القديمة (Gateways) ---"
for u in "${LEGACY_GATEWAYS_DISABLE[@]}"; do
    disable_and_stop "$u"
done
echo

log "--- [5] تعطيل الـ Watchdogs الخاصة بـ SmartFrind (لمنع الضغط على البوابات) ---"
for u in "${LEGACY_WATCHDOGS_DISABLE[@]}"; do
    disable_and_stop "$u"
done
echo

# ----------------------------------------------------------------------
# 5) ملاحظة مهمة: عدم لمس أي ff-* / ffactory-* / factory-gw
# ----------------------------------------------------------------------
log "[Info] لم يتم لمس أي وحدات ff-* أو ffactory-* أو factory-gw ضمن هذا البروفايل."
echo

# ----------------------------------------------------------------------
# 6) عرض الحالة بعد تطبيق البروفايل إن كان سكربت الحالة موجود
# ----------------------------------------------------------------------
if [ -x /root/sf_complete_status.sh ]; then
    log "تشغيل /root/sf_complete_status.sh لعرض الصورة الكاملة بعد قفل البروفايل..."
    echo
    bash /root/sf_complete_status.sh
else
    warn "/root/sf_complete_status.sh غير موجود أو غير تنفيذي – يمكنك تشغيل systemctl list-units يدويًا للمراجعة."
fi

echo
ok "اكتمل تطبيق بروفايل التشغيل (الحد الأدنى المستقر) لـ SmartFriend Suite + Legacy."
