#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
err(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

log "=== Stage4: تشغيل باقي خدمات SmartFriend / SmartFrind من داخل السويت فقط ==="

# 1) جمع كل وحدات السويت (بدون ffactory)
log "1) جمع قائمة الوحدات sf-*, smartfrind-*, smartfriend-* من systemd..."
UNITS=$(systemctl list-unit-files \
           'sf-*.service' \
           'smartfrind-*.service' \
           'smartfriend-*.service' \
           --no-legend 2>/dev/null | awk '{print $1}')

if [ -z "$UNITS" ]; then
  err "لا توجد وحدات sf-*/smartfrind-*/smartfriend-* معرّفة."
  exit 1
fi

# 2) محاولة تشغيل / إعادة تشغيل الوحدات غير النشطة فقط
log "2) تشغيل كل الوحدات غير النشطة (inactive/failed) وترك active كما هي..."
for u in $UNITS; do
  state=$(systemctl is-active "$u" 2>/dev/null || echo "unknown")

  # نتجاهل ff-* احتياطيًا (رغم أن النمط لا يشملها)
  if [[ "$u" == ff-* ]] || [[ "$u" == ffactory* ]] || [[ "$u" == factory-* ]]; then
    continue
  fi

  case "$state" in
    active)
      log "   → $u بالفعل active – لا تغيير."
      ;;
    failed|inactive|activating|deactivating)
      log "   → محاولة restart للوحدة: $u (كانت: $state)"
      if systemctl restart "$u" >/dev/null 2>&1; then
        sleep 1
        new_state=$(systemctl is-active "$u" 2>/dev/null || echo "unknown")
        log "      نتيجة $u الآن: $new_state"
      else
        warn "      فشل restart لـ $u – غالبًا خطأ كود أو إعداد داخلي."
      fi
      ;;
    *)
      warn "   → حالة $u غير معروفة ($state) – تخطي."
      ;;
  esac
done

# 3) ملخص سريع للحالات بعد التشغيل
log "3) ملخص بعد Stage4 (نشِطة مقابل فاشلة):"

echo
echo "=== Active (sf-*, smartfrind-*, smartfriend-*) ==="
systemctl list-units \
  'sf-*.service' \
  'smartfrind-*.service' \
  'smartfriend-*.service' \
  --state=active --no-pager 2>/dev/null || true

echo
echo "=== Failed (sf-*, smartfrind-*, smartfriend-*) ==="
systemctl list-units \
  'sf-*.service' \
  'smartfrind-*.service' \
  'smartfriend-*.service' \
  --state=failed --no-pager 2>/dev/null || true

log "=== انتهى Stage4: تم تشغيل كل ما يمكن تشغيله من خدمات السويت بدون لمس ffactory/ff-* ==="
