#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
error(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

SFDIR="/opt/smartfriend-suite/smartfriend"
APPDIR="$SFDIR/app"
DB_PATH="/opt/smartfriend-suite/data/smartfriend_unified.db"

log "== Stage3: توحيد بيئة جميع خدمات SmartFriend Suite داخل نفس السويت =="

# 1) تحقق من المسارات الأساسية
if [ ! -d "$SFDIR" ]; then
  error "SFDIR $SFDIR غير موجود – السويت غير مثبت في المسار المتوقع."
  exit 1
fi

if [ ! -d "$APPDIR" ]; then
  error "APPDIR $APPDIR غير موجود – تحقق من هيكل السويت."
  exit 1
fi

if [ ! -f "$DB_PATH" ]; then
  warn "قاعدة البيانات $DB_PATH غير موجودة – سيتم إنشاؤها فارغة."
  mkdir -p "$(dirname "$DB_PATH")"
  : > "$DB_PATH"
fi

chown root:root "$DB_PATH"
chmod 640 "$DB_PATH"

log "   → APPDIR = $APPDIR"
log "   → DB_PATH = $DB_PATH"

# 2) تعريف مجموعات الخدمات (SmartFriend / SmartFrind فقط)
CORE_UNITS=(
  sf-core.service
  sf-smartfrind.service
  sf-smartfactory.service
  sf-telegram.service
  sf-telegram-audit.service
  sf-health.service
  sf-memory.service
  sf-unified.service
  sf-web.service
  smartfrind-api.service
  smartfrind-ask.service
  smartfrind-core.service
  smartfrind-monitor.service
  smartfrind-envwatch.service
)

OPTIONAL_UNITS=(
  # SmartFrind – Gateways / APIs إضافية
  smartfrind-qa.service
  smartfrind-advanced.service
  smartfrind-ai-gateway.service
  smartfrind-local.service
  smartfrind-final.service
  smartfrind-unified.service
  smartfrind-guardian.service
  smartfrind-guard.service

  # SmartFrind – Learning / Runner / Jobs
  smartfrind-learning.service
  smartfrind-runner.service
  smartfrind-trainer.service
  smartfrind-learner.service
  smartfrind-harvest.service
  smartfrind-ingest.service
  smartfrind-autolearn.service
  smartfrind-backup.service
  smartfrind-raw-clean.service
  smartfrind-reflector.service

  # SmartFriend – واجهات رسمية إضافية
  smartfriend-smartcore.service
  smartfriend-api.service
  smartfriend-unified.service
  smartfriend-hybrid.service

  # طبقة sf-* Bots & Jobs
  sf-bot.service
  sf-bot-assistant.service
  sf-bot-behavior.service
  sf-bot-programmer.service
  sf-audit-bot.service
  sf-smartfriend.service

  sf-db-backup.service
  sf-db-maintenance.service
  sf-backup.service
  sf-fts-maint.service
  sf-kb-build.service
  sf-learn.service
  sf-learning.service
  sf-download.service
  sf-smoke.service
  sf-factory.service
)

ALL_UNITS=("${CORE_UNITS[@]}" "${OPTIONAL_UNITS[@]}")

# 3) وظيفة لتطبيق Drop-in موحد على خدمة واحدة
apply_dropin() {
  local unit="$1"

  # تجاهل أي شيء له علاقة بـ ffactory / factory احتياطيًا (رغم إن الأسماء محددة يدويًا)
  if [[ "$unit" == ff-* ]] || [[ "$unit" == ffactory* ]] || [[ "$unit" == factory-* ]]; then
    return 0
  fi

  # تأكد أن الوحدة معروفة لـ systemd
  if ! systemctl list-unit-files "$unit" >/dev/null 2>&1; then
    warn "تخطي $unit – غير موجودة في systemd."
    return 0
  fi

  local dropdir="/etc/systemd/system/$unit.d"
  local dropfile="$dropdir/20-smartfriend-env.conf"

  mkdir -p "$dropdir"

  cat > "$dropfile" <<DROP_EOF
[Service]
WorkingDirectory=$APPDIR

# قاعدة البيانات الموحدة
Environment=SMARTFRIND_DB=$DB_PATH
Environment=SMARTFRIEND_DB=$DB_PATH

# ملفات البيئة العامة للسويت (إن وجدت)
EnvironmentFile=-/etc/smartfriend/llm.env
EnvironmentFile=-/etc/smartfriend/keys.env
EnvironmentFile=-/etc/smartfriend/config.env
EnvironmentFile=-/etc/smartfriend/secrets.env
DROP_EOF

  chmod 640 "$dropfile"
  log "   ✔ تم توحيد بيئة الخدمة: $unit"
}

log "3) تطبيق Drop-in موحد على جميع خدمات السويت..."

for u in "${ALL_UNITS[@]}"; do
  apply_dropin "$u"
done

log "4) إعادة تحميل systemd..."
systemctl daemon-reload

log "5) تشغيل طبقة الكور والبوابات والتليجرام..."

for u in "${CORE_UNITS[@]}"; do
  if systemctl list-unit-files "$u" >/dev/null 2>&1; then
    log "   → تفعيل وتشغيل $u"
    systemctl enable "$u" >/dev/null 2>&1 || true
    systemctl start  "$u" >/dev/null 2>&1 || true
  fi
done

log "6) ملخص سريع لحالة أهم الخدمات:"
systemctl status \
  sf-core.service \
  sf-smartfrind.service \
  sf-smartfactory.service \
  sf-telegram.service \
  sf-telegram-audit.service \
  smartfrind-api.service \
  smartfrind-ask.service \
  smartfrind-core.service \
  smartfrind-monitor.service \
  smartfrind-envwatch.service \
  --no-pager -l || true

log "== انتهى Stage3: تم توحيد بيئة خدمات السويت داخل SmartFriend Suite دون لمس ffactory =="
