#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
err(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

SROOT="/opt/smartfriend-suite"
SAPP="$SROOT/smartfriend"
VENV_PY="$SAPP/venv/bin/python"
LOG_DIR="$SROOT/logs"
mkdir -p "$LOG_DIR"

SUMMARY_OK=()
SUMMARY_WARN=()
SUMMARY_TOKEN=()
SUMMARY_SKIP=()

log "=== SmartFriend Bots & Ask/Core Doctor – فحص + إصلاح + تشغيل ==="
log " SROOT = $SROOT"
log " SAPP  = $SAPP"

############################################
# 1) فحص بيئة Python / venv
############################################
if [ ! -x "$VENV_PY" ]; then
  err "venv غير موجود أو غير قابل للتنفيذ: $VENV_PY"
  err "تحقّق من تثبيت السويت داخل /opt/smartfriend-suite/smartfriend"
  exit 1
fi
log "✅ venv جاهز: $VENV_PY"

############################################
# 2) قائمة الخدمات المستهدفة
############################################
CRITICAL_SERVICES=(
  smartfrind-api.service
  smartfrind-ask.service
  smartfrind-core.service
)

TELEGRAM_SERVICES=(
  sf-smartfrind.service
  sf-smartfriend.service
  sf-smartfactory.service
  sf-telegram.service
  sf-telegram-audit.service
  smartfrind-bot.service
)

JOB_FAIL_SERVICES=(
  sf-bot.service
  sf-backup.service
  sf-db-backup.service
  smartfrind-autolearn.service
  smartfrind-backup.service
  smartfrind-harvest.service
  smartfrind-ingest.service
  smartfrind-learner.service
  smartfrind-learning-agent.service
  smartfrind-raw-clean.service
  smartfrind-reflector.service
)

############################################
# 3) دالة فحص وتشغيل خدمة واحدة
############################################
check_and_fix_service() {
  local svc="$1"
  local label="$2"

  # تأكيد وجود الوحدة
  if ! systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
    warn "الخدمة $svc ($label) غير معرّفة في systemd – تخطي."
    SUMMARY_SKIP+=("$svc [$label] (unit missing)")
    return 0
  fi

  log "────────────────────────────────────────────"
  log "🔍 فحص الخدمة: $svc ($label)"

  # حالة أولية
  local state
  state="$(systemctl is-active "$svc" 2>/dev/null || true)"
  log "   الحالة الحالية: ${state:-unknown}"

  # أخذ آخر 80 سطر من الـ journal
  local safe svc_log tmp
  safe="$(echo "$svc" | tr '/.-' '_')"
  tmp="/tmp/sf_diag_${safe}.log"
  svc_log="$LOG_DIR/${safe}_$(date +%Y%m%d_%H%M%S).log"

  log "   قراءة آخر 80 سطر من journalctl -xeu $svc ..."
  if journalctl -xeu "$svc" --no-pager 2>/dev/null | tail -n 80 >"$tmp"; then
    cat "$tmp" | sed 's/^/       │ /'
    cp "$tmp" "$svc_log" || true
    log "   تم حفظ اللوج في: $svc_log"
  else
    warn "   لا يوجد لوج متاح أو فشل journalctl لهذه الخدمة."
  fi

  # كشف InvalidToken في البوتات
  if grep -q "InvalidToken" "$tmp" 2>/dev/null; then
    warn "   تم اكتشاف telegram.error.InvalidToken في لوج $svc"
    warn "   هذا يعني أن التوكن غير صالح – يجب تحديث التوكن في secrets/env يدوياً."
    SUMMARY_TOKEN+=("$svc [$label] (InvalidToken)")
    # نوقف الخدمة مؤقتًا لتفادي الـ restart loop
    systemctl stop "$svc" 2>/dev/null || true
    rm -f "$tmp"
    return 0
  fi

  # لو الخدمة active نكتفي بالفحص
  if [[ "$state" == "active" || "$state" == "activating" ]]; then
    log "   الخدمة $svc في حالة $state – لن أعمل restart الآن."
    SUMMARY_SKIP+=("$svc [$label] (already $state)")
    rm -f "$tmp"
    return 0
  fi

  # محاولة restart للخدمة
  log "   ▶️ محاولة restart للخدمة: $svc ..."
  if systemctl restart "$svc"; then
    sleep 2
    local new_state
    new_state="$(systemctl is-active "$svc" 2>/dev/null || true)"
    log "   بعد restart: $svc حالة = ${new_state:-unknown}"
    if [[ "$new_state" == "active" || "$new_state" == "activating" ]]; then
      SUMMARY_OK+=("$svc [$label]")
    else
      SUMMARY_WARN+=("$svc [$label] (state=$new_state)")
    fi
  else
    warn "   فشل systemctl restart لـ $svc"
    SUMMARY_WARN+=("$svc [$label] (restart failed)")
  fi

  rm -f "$tmp"
}

############################################
# 4) فحص وتشغيل CRITICAL + TELEGRAM
############################################
log "=== فحص وتشغيل الخدمات الحرجة (Gateways / Core / Ask) ==="
for svc in "${CRITICAL_SERVICES[@]}"; do
  check_and_fix_service "$svc" "core/gateway"
done

log "=== فحص وتشغيل خدمات Telegram Bots ==="
for svc in "${TELEGRAM_SERVICES[@]}"; do
  check_and_fix_service "$svc" "telegram-bot"
done

############################################
# 5) عرض حالة الـ jobs الفاشلة فقط (قراءة، بدون إصلاح تلقائي)
############################################
log "=== قراءة حالة Jobs/Tasks الفاشلة (بدون إصلاح تلقائي) ==="
for svc in "${JOB_FAIL_SERVICES[@]}"; do
  if systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
    local s; s="$(systemctl is-active "$svc" 2>/dev/null || true)"
    if [[ "$s" == "failed" ]]; then
      warn "   job فاشل: $svc (state=$s) – يحتاج مراجعة كود/DB لاحقاً."
    fi
  fi
done

############################################
# 6) ملخص نهائي
############################################
log "────────────────────────────────────────────"
log "=== ملخص Doctor – Bots & Ask/Core ==="

log "✅ نجحت إعادة التشغيل / التشغيل للخدمات:"
if [ "${#SUMMARY_OK[@]}" -eq 0 ]; then
  echo "   (لا شيء)"
else
  for x in "${SUMMARY_OK[@]}"; do
    echo "   + $x"
  done
fi

log "⚠️ خدمات لم تستقر بعد (تحتاج مراجعة كود/بيئة/DB):"
if [ "${#SUMMARY_WARN[@]}" -eq 0 ]; then
  echo "   (لا شيء)"
else
  for x in "${SUMMARY_WARN[@]}"; do
    echo "   - $x"
  done
fi

log "⛔ خدمات تم اكتشاف InvalidToken لها (توكن تيليجرام غير صالح – يلزم تعديل يدوي):"
if [ "${#SUMMARY_TOKEN[@]}" -eq 0 ]; then
  echo "   (لا شيء)"
else
  for x in "${SUMMARY_TOKEN[@]}"; do
    echo "   × $x"
  done
fi

log "⏭ خدمات تم الاكتفاء بفحصها أو تخطيها (نشِطة أو الوحدة غير موجودة):"
if [ "${#SUMMARY_SKIP[@]}" -eq 0 ]; then
  echo "   (لا شيء)"
else
  for x in "${SUMMARY_SKIP[@]}"; do
    echo "   · $x"
  done
fi

log "=== انتهى SmartFriend Bots & Ask/Core Doctor ==="
