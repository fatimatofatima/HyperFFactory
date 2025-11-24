#!/usr/bin/env bash
# HyperFFactory – Fix SmartFriend core/health ports to match unified design
# - sf-core   → 8383
# - sf-health → 8215
#
# لا يلمس HyperFFactory نفسه؛ فقط يضيف drop-ins لـ systemd تحت /etc/systemd/system.

set -Eeuo pipefail

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

SECTION() {
    echo
    echo "============================================================"
    echo "== $*"
    echo "============================================================"
}

SECTION "1) معلومات سريعة قبل التعديل"

log "فحص حالة خدمات sf-* الحالية..."
systemctl --no-pager -l status sf-core.service sf-health.service sf-memory.service sf-web.service | sed -n '1,80p' || true

echo
log "فحص البورتات المفتوحة على 8210/8211/8214/8215/8383/8390 ..."
ss -tulpn | grep -E ':(8210|8211|8214|8215|8383|8390)\b' || log "لا توجد منافذ مطابقة (قد يحتاج ss إلى sudo)"

SECTION "2) إنشاء drop-in جديد لـ sf-core (port 8383)"

CORE_DROPIN_DIR="/etc/systemd/system/sf-core.service.d"
CORE_FIX_FILE="$CORE_DROPIN_DIR/70-hf-port-fix.conf"

mkdir -p "$CORE_DROPIN_DIR"

log "كتابة $CORE_FIX_FILE ..."
cat > "$CORE_FIX_FILE" <<'CORECONF'
[Service]
# نلغي أي ExecStart سابق ثم نحدد ExecStart النهائي على 8383
ExecStart=
ExecStart=/usr/bin/python3 -m uvicorn services.ffactory.simple_api:app --host 127.0.0.1 --port 8383 --workers 1
CORECONF

log "drop-in لـ sf-core جاهز: $CORE_FIX_FILE"

SECTION "3) إنشاء drop-in جديد لـ sf-health (port 8215)"

HEALTH_DROPIN_DIR="/etc/systemd/system/sf-health.service.d"
HEALTH_FIX_FILE="$HEALTH_DROPIN_DIR/70-hf-port-fix.conf"

mkdir -p "$HEALTH_DROPIN_DIR"

log "كتابة $HEALTH_FIX_FILE ..."
cat > "$HEALTH_FIX_FILE" <<'HEALTHCONF'
[Service]
# نلغي أي ExecStart سابق ثم نحدد ExecStart النهائي على 8215
ExecStart=
ExecStart=/usr/bin/python3 -m uvicorn ops.health_gate:app --host 127.0.0.1 --port 8215 --workers 1 --timeout-keep-alive 30
HEALTHCONF

log "drop-in لـ sf-health جاهز: $HEALTH_FIX_FILE"

SECTION "4) إعادة تحميل systemd وإعادة تشغيل الخدمات"

log "systemctl daemon-reload"
systemctl daemon-reload

log "إعادة تشغيل sf-core.service ..."
systemctl restart sf-core.service

log "إعادة تشغيل sf-health.service ..."
systemctl restart sf-health.service

log "حالة الخدمات بعد إعادة التشغيل:"
systemctl --no-pager -l status sf-core.service sf-health.service | sed -n '1,80p' || true

SECTION "5) فحص /health بعد الإصلاح"

log "اختبار sf-core → http://127.0.0.1:8383/health"
CORE_RES="$(curl -s -o /tmp/sf_core_health.out -w '%{http_code}' http://127.0.0.1:8383/health || echo '000')"
if [ "$CORE_RES" = "200" ]; then
    log "✅ sf-core /health HTTP 200"
else
    log "❌ sf-core /health فشل (كود: $CORE_RES)"
    log "   محتوى الرد (إن وجد): $(cat /tmp/sf_core_health.out 2>/dev/null || echo '<no-body>')"
fi

log "اختبار sf-health → http://127.0.0.1:8215/health"
HEALTH_RES="$(curl -s -o /tmp/sf_health_health.out -w '%{http_code}' http://127.0.0.1:8215/health || echo '000')"
if [ "$HEALTH_RES" = "200" ]; then
    log "✅ sf-health /health HTTP 200"
else
    log "❌ sf-health /health فشل (كود: $HEALTH_RES)"
    log "   محتوى الرد (إن وجد): $(cat /tmp/sf_health_health.out 2>/dev/null || echo '<no-body>')"
fi

log "اختبار sf-memory → http://127.0.0.1:8214/health (للتأكد أنه ما زال سليمًا)"
MEM_RES="$(curl -s -o /tmp/sf_memory_health.out -w '%{http_code}' http://127.0.0.1:8214/health || echo '000')"
if [ "$MEM_RES" = "200" ]; then
    log "✅ sf-memory /health HTTP 200"
else
    log "❌ sf-memory /health فشل (كود: $MEM_RES)"
fi

SECTION "6) ملخص بعد الإصلاح"

echo "الـ Ports المستهدفة الآن:"
echo "- sf-core   => 8383"
echo "- sf-health => 8215"
echo "- sf-memory => 8214 (بدون تغيير)"
echo "- sf-web    => 8390 (بدون تغيير)"

log "يمكنك الآن تشغيل:"
log "  curl -s http://127.0.0.1:8383/health || echo '❌ core'"
log "  curl -s http://127.0.0.1:8215/health || echo '❌ health'"
log "  curl -s http://127.0.0.1:8214/health || echo '❌ memory'"
log "  curl -s http://127.0.0.1:8390/health || echo '❌ web'"

echo
log "انتهى hf_fix_sf_core_health_ports.sh"
