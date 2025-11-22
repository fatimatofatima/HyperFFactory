#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log() { echo "[$(date '+%F %T')] $*"; }

log "SmartFriend Suite - CORE Autorun (sf-* فقط، بدون لمس ffactory)..."

# قائمة خدمات الـ Core / APIs داخل السيوت فقط
CORE_SERVICES=(
  sf-health.service
  sf-memory.service
  sf-unified.service
  sf-web.service
  sf-core.service
  sf-smartfriend.service
  sf-smartfrind.service
)

log "إعادة تحميل تعريفات systemd..."
systemctl daemon-reload

for svc in "${CORE_SERVICES[@]}"; do
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    log "تفعيل وتشغيل الخدمة: $svc"
    if ! systemctl enable "$svc"; then
      log "تحذير: فشل تمكين الخدمة عند الإقلاع: $svc"
    fi

    # نحاول restart، لو فشل نجرب start
    if ! systemctl restart "$svc"; then
      if ! systemctl start "$svc"; then
        log "تحذير: فشل تشغيل الخدمة: $svc"
      fi
    fi
  else
    log "تخطي: الوحدة غير موجودة في systemd: $svc"
  fi
done

log "ملخص حالة خدمات الـ Core في السيوت (sf-* فقط):"
systemctl --no-pager --full status "${CORE_SERVICES[@]}" 2>/dev/null || true

log "انتهى sf_suite_core_autorun: تم ضبط وتشغيل طبقة CORE للسيوت بدون لمس أي خدمات ff-*."
