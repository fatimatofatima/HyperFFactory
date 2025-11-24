#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

FF_USER="ffactory"
FF_GROUP="ffactory"
FF_HOME="/opt/ffactory"
FF_SCRIPTS="$FF_HOME/scripts"
WRAPPER="$FF_SCRIPTS/ff_doctor_enhanced.sh"

# 1) إنشاء مستخدم/مجموعة ffactory إذا غير موجودين
log "التحقق من وجود مستخدم/مجموعة ${FF_USER}..."

if ! getent group "$FF_GROUP" >/dev/null 2>&1; then
  log "إنشاء المجموعة ${FF_GROUP}..."
  groupadd --system "$FF_GROUP"
else
  log "المجموعة ${FF_GROUP} موجودة بالفعل."
fi

if ! id "$FF_USER" >/dev/null 2>&1; then
  log "إنشاء المستخدم ${FF_USER} (system, no-login)..."
  useradd --system \
          --home-dir "$FF_HOME" \
          --shell /usr/sbin/nologin \
          --gid "$FF_GROUP" \
          "$FF_USER"
else
  log "المستخدم ${FF_USER} موجود بالفعل."
fi

# 2) تحضير شجرة /opt/ffactory/scripts
log "تحضير مجلدات ffactory في ${FF_HOME}..."
mkdir -p "$FF_SCRIPTS"
chown -R "$FF_USER:$FF_GROUP" "$FF_HOME"

# 3) إنشاء/تحديث wrapper لـ ff_doctor_enhanced.sh
log "إنشاء/تحديث ملف التنفيذ ${WRAPPER}..."

cat > "$WRAPPER" <<'WRAP'
#!/usr/bin/env bash
set -Eeuo pipefail

# هذا ملف ربط لـ ff-doctor داخل /opt/ffactory.
# إذا كان لديك نسخة حقيقية من ff_doctor_enhanced.sh داخل السيوت،
# عدّل المتغير REAL_SCRIPT أدناه لمسارها الحقيقي.

REAL_SCRIPT="/opt/smartfriend-suite/factory/scripts/ff_doctor_enhanced.sh"

if [ -x "$REAL_SCRIPT" ]; then
  exec "$REAL_SCRIPT" "$@"
else
  # Stub مؤقت حتى لا تفشل الخدمة
  TS="$(date '+%Y-%m-%d %H:%M:%S')"
  LOG_DIR="/opt/ffactory/logs"
  mkdir -p "$LOG_DIR"
  echo "$TS ff_doctor_stub: REAL_SCRIPT غير موجود أو غير قابل للتنفيذ: $REAL_SCRIPT" >> "$LOG_DIR/ff_doctor_stub.log"
  exit 0
fi
WRAP

chmod 750 "$WRAPPER"
chown "$FF_USER:$FF_GROUP" "$WRAPPER"

# 4) إعادة تحميل systemd وتشغيل المؤقت
log "إعادة تحميل systemd..."
systemctl daemon-reload

log "إعادة تشغيل المؤقت ff-doctor.timer..."
systemctl restart ff-doctor.timer

log "عرض حالة ff-doctor:"
systemctl status ff-doctor.service ff-doctor.timer --no-pager || true

log "اكتمل ffactory_user_and_ff_doctor_bind.sh."
