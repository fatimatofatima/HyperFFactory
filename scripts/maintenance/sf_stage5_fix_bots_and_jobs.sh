#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
err(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

log "=== Stage5: تشخيص وإصلاح أولي للبوتات والـ jobs (بدون لمس ffactory) ==="

############################################
# 1) تلخيص الوحدات الفاشلة حاليًا
############################################
FAILED_UNITS=$(systemctl list-units \
  'sf-*.service' 'smartfrind-*.service' 'smartfriend-*.service' \
  --state=failed --no-legend 2>/dev/null | awk '{print $1}' || true)

if [ -n "$FAILED_UNITS" ]; then
  log "الوحدات الفاشلة الحالية ضمن sf-*/smartfrind-*/smartfriend-*:"
  echo "$FAILED_UNITS" | sed 's/^/  - /'
else
  log "لا توجد وحدات فاشلة حاليًا ضمن sf-*/smartfrind-*/smartfriend-*."
fi

############################################
# 2) معالجة بوتات تليجرام (InvalidToken)
############################################
BOT_SERVICES=(
  sf-bot
  sf-bot-assistant
  sf-bot-behavior
  sf-bot-programmer
  sf-audit-bot
  sf-smartfriend
  sf-smartfactory
  sf-telegram
  sf-telegram-audit
  smartfrind-bot
)

log "2) فحص بوتات تليجرام لأخطاء InvalidToken وتعطيلها مؤقتًا لو التوكن غلط..."

for name in "${BOT_SERVICES[@]}"; do
  svc="${name}.service"

  if ! systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
    continue
  fi

  state=$(systemctl is-active "$svc" 2>/dev/null || true)
  # لو الخدمة موجودة بغض النظر عن حالتها، نراجع اللوج
  last_log=$(journalctl -u "$svc" -n 30 --no-pager 2>/dev/null || true)

  if echo "$last_log" | grep -q 'InvalidToken'; then
    warn "  → $svc عنده InvalidToken – سيتم إيقافه وتعطيله لحد ما تتحدّث التوكنات."
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    log  "     تم: stop + disable لـ $svc (حدّث TELEGRAM_TOKEN في /etc/smartfriend/secrets.env أو ملف الأسرار المكافئ ثم re-enable يدويًا)."
  fi
done

############################################
# 3) فحص خدمات النسخ الاحتياطي والصيانة
############################################
JOB_SERVICES=(
  sf-db-backup
  sf-db-maintenance
  sf-backup
  smartfrind-backup
)

log "3) فحص خدمات النسخ الاحتياطي والصيانة للتأكد أن مسار ExecStart صالح..."

for name in "${JOB_SERVICES[@]}"; do
  svc="${name}.service"

  if ! systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
    continue
  fi

  exec_line=$(systemctl show -p ExecStart --value "$svc" 2>/dev/null || true)
  [ -z "$exec_line" ] && continue

  # استخراج أول مسار تنفيذي من ExecStart
  bin_path=$(echo "$exec_line" | sed -E 's/.* ([^ ]+)( .*)?;/\1/' || true)

  if [ -n "$bin_path" ] && [[ "$bin_path" == /* ]]; then
    if [ ! -e "$bin_path" ]; then
      warn "  → $svc يشير إلى ملف غير موجود: $bin_path – سيتم إيقافه وتعطيله لتفادي فشل متكرر."
      systemctl stop "$svc" 2>/dev/null || true
      systemctl disable "$svc" 2>/dev/null || true
    fi
  fi
done

############################################
# 4) فحص حزمة smartfrind learning/harvest/ingest/...
############################################
LEARN_SERVICES=(
  smartfrind-harvest
  smartfrind-ingest
  smartfrind-autolearn
  smartfrind-learner
  smartfrind-learning
  smartfrind-learning-agent
  smartfrind-raw-clean
  smartfrind-reflector
)

log "4) فحص حزمة smartfrind-* (harvest/ingest/autolearn/learner/...) لمسارات ExecStart والأخطاء التطبيقية..."

for name in "${LEARN_SERVICES[@]}"; do
  svc="${name}.service"

  if ! systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
    continue
  fi

  exec_line=$(systemctl show -p ExecStart --value "$svc" 2>/dev/null || true)
  bin_path=$(echo "$exec_line" | sed -E 's/.* ([^ ]+)( .*)?;/\1/' || true)

  # 4-أ) لو المسار الرئيسي غير موجود → نوقف الخدمة ونعطّلها
  if [ -n "$bin_path" ] && [[ "$bin_path" == /* ]] && [ ! -e "$bin_path" ]; then
    warn "  → $svc: ملف التنفيذ غير موجود: $bin_path – سيتم إيقافه وتعطيله."
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    continue
  fi

  # 4-ب) لو المسار موجود لكن الخدمة فاشلة → نطبع آخر 20 سطر للمراجعة اليدوية
  state=$(systemctl is-active "$svc" 2>/dev/null || true)
  if [[ "$state" == "failed" ]]; then
    warn "  → $svc ما زال failed رغم صحة المسار – غالبًا خطأ Python داخل التطبيق. تلخيص آخر لوج:"
    journalctl -u "$svc" -n 20 --no-pager || true
    echo "------------------------------------------------------------"
  fi
done

############################################
# 5) ملخص نهائي للحالة بعد Stage5
############################################
log "5) ملخص بعد Stage5 (sf-*/smartfrind-*/smartfriend-*)"

echo
echo "=== Active ==="
systemctl list-units "sf-*.service" "smartfrind-*.service" "smartfriend-*.service" \
  --state=active --no-pager || true

echo
echo "=== Failed ==="
systemctl list-units "sf-*.service" "smartfrind-*.service" "smartfriend-*.service" \
  --state=failed --no-pager || true

log "=== انتهى Stage5: تم تعطيل البوتات ذات التوكنات الخاطئة والخدمات التي تشير لمسارات مفقودة، مع إبقاء باقي الأخطاء للتصحيح في الكود نفسه. ==="
