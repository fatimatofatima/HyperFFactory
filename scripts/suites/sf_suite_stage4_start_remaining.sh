#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
err(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

log "=== Stage4: تشغيل باقي خدمات السويت (sf-*, smartfrind-*, smartfriend-*) بدون لمس ffactory ==="

# أنماط الخدمات المستهدفة
PATTERNS=(
  "sf-*.service"
  "smartfrind-*.service"
  "smartfriend-*.service"
)

# قراءة كل الوحدات المطابقة من systemd
mapfile -t ALL_UNITS < <(
  systemctl list-units --type=service --all --no-legend "${PATTERNS[@]}" \
  | awk '{print $1}' \
  | sort -u
)

if [ "${#ALL_UNITS[@]}" -eq 0 ]; then
  warn "لم يتم العثور على أي وحدات sf-*/smartfrind-*/smartfriend-*"
  exit 0
fi

log "تم اكتشاف ${#ALL_UNITS[@]} خدمة مرشحة."

STARTED_OK=()
START_FAILED=()
SKIPPED_ACTIVE=()
SKIPPED_FFACTORY=()

for unit in "${ALL_UNITS[@]}"; do
  # حزام أمان إضافي – تجاهل أي شيء ffactory/factory
  if [[ "$unit" == ff-* ]] || [[ "$unit" == ffactory* ]] || [[ "$unit" == factory-* ]]; then
    SKIPPED_FFACTORY+=("$unit")
    continue
  fi

  # حالة الخدمة الحالية
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"

  # لو الخدمة شغالة أو في حالة activating نسيبها في حالها
  if [[ "$state" == "active" || "$state" == "activating" ]]; then
    SKIPPED_ACTIVE+=("$unit")
    continue
  fi

  log "▶️ محاولة تشغيل: $unit (state=${state:-unknown})"
  if systemctl restart "$unit" >/dev/null 2>&1; then
    log "   ✅ تم تشغيل $unit"
    STARTED_OK+=("$unit")
  else
    warn "   ⚠️ فشل تشغيل $unit – راجع: journalctl -xeu $unit"
    START_FAILED+=("$unit")
  fi
done

log "=== Stage4: ملخص التشغيل ==="
log "   ✅ الخدمات التي تم تشغيلها/إعادة تشغيلها بنجاح: ${#STARTED_OK[@]}"
for u in "${STARTED_OK[@]}"; do
  echo "      + $u"
done

log "   ⚠️ الخدمات التي فشلت في التشغيل (غالبًا مشاكل كود/توكن/DB): ${#START_FAILED[@]}"
for u in "${START_FAILED[@]}"; do
  echo "      - $u"
done

log "   ⏭ خدمات كانت نشطة بالفعل أو في حالة activating وتم تخطيها: ${#SKIPPED_ACTIVE[@]}"
for u in "${SKIPPED_ACTIVE[@]}"; do
  echo "      · $u"
done

log "   ⛔ خدمات تم تجاهلها لأنها ffactory/factory (حزام أمان): ${#SKIPPED_FFACTORY[@]}"
for u in "${SKIPPED_FFACTORY[@]}"; do
  echo "      × $u"
done

log "=== انتهى Stage4: تمت محاولة تشغيل كل خدمات السويت بدون لمس ffactory ==="
