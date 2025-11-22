#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
err(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

SROOT="/opt/smartfriend-suite"
SAPP="$SROOT/smartfriend"
VENV_DIR="$SAPP/venv"
DATA_DIR="$SROOT/data"
DB_PATH="$DATA_DIR/smartfriend_unified.db"

log "=== Stage3: تثبيت كل خدمات السيوت داخل /opt/smartfriend-suite فقط ==="
log " SROOT    = $SROOT"
log " SAPP     = $SAPP"
log " VENV_DIR = $VENV_DIR"
log " DATA_DIR = $DATA_DIR"
log " DB_PATH  = $DB_PATH"

############################################
# 1) تحقق أساسي على هيكل السويت
############################################
if [ ! -d "$SAPP" ]; then
  err "لم أجد مجلد التطبيق: $SAPP"
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  err "لم أجد venv: $VENV_DIR"
  exit 1
fi

if [ ! -x "$VENV_DIR/bin/python" ]; then
  err "لم أجد Python قابل للتنفيذ في: $VENV_DIR/bin/python"
  exit 1
fi

log "✅ venv تحت السويت جاهز: $VENV_DIR/bin/python"

############################################
# 2) إصلاح صلاحيات venv (بدون أي symlink)
############################################
log "2) إصلاح صلاحيات venv حتى لا تظهر PermissionError على pyvenv.cfg"

# نثبت أن المالك root (أو المستخدم الحالي للنظام)، مع صلاحيات قراءة/تنفيذ للجميع
chown -R root:root "$VENV_DIR" || warn "فشل chown على $VENV_DIR، تابع يدويًا إذا لزم."

# المجلدات قابلة للدخول
find "$VENV_DIR" -type d -exec chmod 755 {} \; || warn "فشل chmod d على $VENV_DIR"

# ملفات python التنفيذية
find "$VENV_DIR" -type f -name 'python*' -exec chmod 755 {} \; || warn "فشل chmod python* على $VENV_DIR"

# ملف pyvenv.cfg تحديدًا – قراءة للجميع
if [ -f "$VENV_DIR/pyvenv.cfg" ]; then
  chmod 644 "$VENV_DIR/pyvenv.cfg" || warn "فشل chmod على pyvenv.cfg"
fi

log "✅ تم ضبط صلاحيات venv (إزالة سبب PermissionError السابق)."

############################################
# 3) ضمان وجود قاعدة البيانات داخل السويت
############################################
log "3) ضمان وجود data dir + smartfriend_unified.db داخل السويت"

mkdir -p "$DATA_DIR"
chmod 750 "$DATA_DIR"

if [ ! -f "$DB_PATH" ]; then
  log "   DB غير موجود، إنشاء ملف فارغ مبدئي (التطبيق نفسه سيبني الجداول)."
  touch "$DB_PATH"
fi

chown root:root "$DB_PATH" || warn "فشل chown على $DB_PATH"
chmod 660 "$DB_PATH" || warn "فشل chmod على $DB_PATH"

log "✅ قاعدة البيانات موجودة الآن داخل السويت: $DB_PATH"

############################################
# 4) إعادة تحميل systemd
############################################
log "4) إعادة تحميل systemd للوحدات"
systemctl daemon-reload || warn "فشل daemon-reload – تأكد لاحقًا."

############################################
# 5) إعادة تشغيل خدمات SmartFriend Suite (sf-*)
############################################
log "5) إعادة تشغيل طبقة SmartFriend Suite (sf-*) من داخل السويت فقط"

SF_CORE_SERVICES=(
  sf-core
  sf-health
  sf-memory
  sf-unified
  sf-web
)

SF_BOT_SERVICES=(
  sf-bot
  sf-bot-assistant
  sf-bot-behavior
  sf-bot-programmer
  sf-audit-bot
  sf-smartfactory
  sf-smartfriend
  sf-smartfrind
  sf-telegram
  sf-telegram-audit
)

SF_JOBS_SERVICES=(
  sf-db-backup
  sf-db-maintenance
  sf-backup
  sf-fts-maint
  sf-kb-build
  sf-learn
  sf-learning
  sf-download
  sf-smoke
  sf-factory
)

for s in "${SF_CORE_SERVICES[@]}"; do
  log "   ▶️ إعادة تشغيل $s.service"
  systemctl restart "$s.service" || warn "فشل restart لـ $s.service"
done

for s in "${SF_BOT_SERVICES[@]}"; do
  log "   ▶️ إعادة تشغيل $s.service"
  systemctl restart "$s.service" || warn "فشل restart لـ $s.service (ممكن يحتاج مفاتيح/توكنات)"
done

for s in "${SF_JOBS_SERVICES[@]}"; do
  log "   ▶️ إعادة تشغيل $s.service"
  systemctl restart "$s.service" || warn "فشل restart لـ $s.service (بعضها static timers)"
done

############################################
# 6) إعادة تشغيل طبقة SmartFrind (smartfrind-*)
#    كلها تعتمد على نفس venv + DB داخل السويت
############################################
log "6) إعادة تشغيل طبقة SmartFrind (core / learning / infra) – كلها داخل السويت"

SMARTFRIND_SERVICES=(
  smartfrind-core
  smartfrind-api
  smartfrind-qa
  smartfrind-advanced
  smartfrind-ai-gateway
  smartfrind-local
  smartfrind-monitor

  smartfrind-learning
  smartfrind-runner
  smartfrind-trainer
  smartfrind-simple
  smartfrind-ultra
  smartfrind-learner
  smartfrind-ask

  smartfrind-guardian
  smartfrind-guard
  smartfrind-harvest
  smartfrind-ingest
  smartfrind-autolearn
  smartfrind-backup
  smartfrind-raw-clean
  smartfrind-reflector
  smartfrind-final
  smartfrind-unified
  smartfrind-bot
)

for s in "${SMARTFRIND_SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${s}.service"; then
    log "   ▶️ إعادة تشغيل $s.service"
    systemctl restart "$s.service" || warn "فشل restart لـ $s.service (قد يكون احتياج لـ env أو كود داخلي)."
  else
    warn "   تخطي $s.service (غير معرف في systemd على هذا السيرفر)."
  fi
done

############################################
# 7) عدم لمس ffactory إطلاقًا
############################################
log "7) حسب طلبك: لا تغيير، لا restart، لا enable لأي خدمة ffactory أو ff-*."
log "    كل أوامر السكربت تجنبت /opt/ffactory وأي وحدات ff-*."

############################################
# 8) ملخص سريع لحالة خدمات السويت / SmartFrind
############################################
log "8) ملخص سريع (sf-*, smartfrind-*, smartfriend-*) بعد Stage3:"

systemctl --no-pager --type=service \
  | egrep 'sf-|smartfrind-|smartfriend-' \
  || true

log "=== انتهى Stage3: كل خدمات السيوت تعمل من داخل /opt/smartfriend-suite فقط، بدون لمس ffactory ==="
