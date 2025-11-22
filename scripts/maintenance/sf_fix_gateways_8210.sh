#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log() { echo "[$(date '+%F %T')] $*"; }

log "=== SmartFrind – توحيد بوابات 8210 وتهدئة الـ Watchdogs (بدون لمس ffactory/sf/smartfriend) ==="

# 1) بوابات smartfrind التي نعتبرها "مسموح تشغيلها" (يمكن تعديلها لاحقًا)
KEEP_UNITS=(
  smartfrind-api.service      # ASGI gateway (يمكن تغييره لاحقًا)
  smartfrind-local.service    # بوابة محلية بدون مفتاح
  smartfrind-gateway.service  # Unified Gateway (لو حابب تبقيه شغال)
)

# 2) بوابات smartfrind على 8210 نريد إيقافها وتعطيلها لتفادي التصادم
STOP_DISABLE_UNITS=(
  smartfrind-ask.service
  smartfrind-simple.service
  smartfrind-ultra.service
  smartfrind-final.service
)

# 3) الـ Watchdogs التي تضغط على smartfrind-gateway / core
WATCHDOG_UNITS=(
  smartfrind-watchdog.service
  smartfrind-core-watchdog.service
)

log "--- [1] إيقاف وتعطيل بوابات smartfrind الثانوية على 8210 ---"
for u in "${STOP_DISABLE_UNITS[@]}"; do
  if systemctl list-unit-files "$u" --no-legend >/dev/null 2>&1; then
    log "إيقاف وتعطيل $u ..."
    systemctl stop "$u" 2>/dev/null || true
    systemctl disable "$u" 2>/dev/null || true
  fi
done

log "--- [2] تهدئة الـ Watchdogs الخاصة بـ smartfrind ---"
for u in "${WATCHDOG_UNITS[@]}"; do
  if systemctl list-unit-files "$u" --no-legend >/dev/null 2>&1; then
    log "إيقاف وتعطيل $u ..."
    systemctl stop "$u" 2>/dev/null || true
    systemctl disable "$u" 2>/dev/null || true
  fi
done

log "--- [3] تفعيل وتشغيل البوابات التي نريد الاحتفاظ بها (smartfrind-api/local/gateway) ---"
for u in "${KEEP_UNITS[@]}"; do
  if systemctl list-unit-files "$u" --no-legend >/dev/null 2>&1; then
    log "تفعيل وتشغيل $u ..."
    systemctl enable "$u" 2>/dev/null || true
    systemctl restart "$u" 2>/dev/null || true
  fi
done

log "--- [4] ملخص حالة وحدات smartfrind المختارة بعد الإصلاح ---"
systemctl status \
  smartfrind-api.service \
  smartfrind-local.service \
  smartfrind-gateway.service \
  smartfrind-ask.service \
  smartfrind-simple.service \
  smartfrind-ultra.service \
  smartfrind-final.service \
  smartfrind-watchdog.service \
  smartfrind-core-watchdog.service \
  --no-pager || true

log "--- [5] فحص المنافذ 8210 و 8211 بعد التعديل ---"
if command -v ss >/dev/null 2>&1; then
  ss -ltnp | grep -E '(:8210 |:8211 )' || echo "لا يوجد استماع على 8210/8211 حاليًا"
else
  netstat -ltnp 2>/dev/null | grep -E '(:8210|:8211)' || echo "لا يوجد استماع على 8210/8211 حاليًا"
fi

log "=== انتهى sf_fix_gateways_8210.sh – بدون لمس ffactory / sf-* / smartfriend-* ==="
