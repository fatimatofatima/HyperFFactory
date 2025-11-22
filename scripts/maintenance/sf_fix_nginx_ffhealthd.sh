#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

CONF="/etc/nginx/conf.d/ff-healthd.conf"

log()   { echo "[sf_fix_nginx_ffhealthd] $*"; }
error() { echo "[sf_fix_nginx_ffhealthd][ERROR] $*" >&2; exit 1; }

log "=== تعطيل ff-healthd.conf المعطّب في Nginx ==="

if [ ! -f "$CONF" ]; then
    log "لا يوجد ملف $CONF – لا شيء لتعطيله."
else
    TS="$(date +%Y%m%d_%H%M%S)"
    BAK="${CONF}.${TS}.bak"
    DISABLED="${CONF}.${TS}.disabled"

    log "أرشفة الملف الأصلي إلى: $BAK"
    cp -a "$CONF" "$BAK"

    log "نقل الملف خارج نطاق التحميل إلى: $DISABLED"
    mv "$CONF" "$DISABLED"
fi

log "اختبار إعدادات Nginx..."
if nginx -t; then
    log "✅ إعدادات Nginx صحيحة – عمل reload..."
    systemctl reload nginx || log "تحذير: تعذَّر عمل reload لـ Nginx، راجع systemctl status nginx."
    log "✅ تم إصلاح مشكلة ff-healthd.conf (معطّل الآن، لم يُحذف)."
else
    error "❌ ما زال هناك خطأ في إعدادات Nginx – راجع مخرجات nginx -t يدويًا."
fi
