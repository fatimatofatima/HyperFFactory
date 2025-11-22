#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }
error(){ echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

SFDIR="/opt/smartfriend-suite/smartfriend"
APP_SERVICE="smartfrind-api.service"

if [ ! -d "$SFDIR" ]; then
  error "SFDIR $SFDIR غير موجود – تأكد من مسار السويت."
  exit 1
fi

log "1) اكتشاف مستخدم خدمات SmartFrind"
APP_USER=$(systemctl show -p User --value "$APP_SERVICE" 2>/dev/null || true)
APP_USER=${APP_USER:-smartfrind}
log "   → APP_USER=${APP_USER}"

log "2) إصلاح صلاحيات المسار بحيث يقدر ${APP_USER} يشغل venv"
VENV_DIR="$SFDIR/venv"
if [ -d "$VENV_DIR" ]; then
  chown -R "$APP_USER":"$APP_USER" "$VENV_DIR"
  find "$VENV_DIR" -type d -exec chmod 750 {} \;
  find "$VENV_DIR" -type f -name 'python*' -exec chmod 750 {} \; || true
else
  warn "لا يوجد venv في $VENV_DIR – نتخطى هذه الخطوة."
fi

# نضمن على الأقل إن APP_USER يقدر يدخل على المسار الجذري للسويت
chown "$APP_USER":"$APP_USER" "$SFDIR" || true
chmod 750 "$SFDIR" || true

log "3) اكتشاف مسار قاعدة بيانات SmartFrind (DB) من smartfrind.db وإنشاء المجلد"
DB_PATH=""
DB_MODULE_DIR="$SFDIR/app"

if [ -d "$DB_MODULE_DIR" ] && [ -x "$VENV_DIR/bin/python" ]; then
  DB_PATH="$(
    cd "$DB_MODULE_DIR"
    "$VENV_DIR/bin/python" - <<'PY' 2>/dev/null || exit 0
from smartfrind.db import DB
print(DB)
PY
  )"
fi

if [ -n "$DB_PATH" ]; then
  DB_PATH=$(echo "$DB_PATH" | head -n1 | tr -d '\r')
  log "   → DB_PATH = $DB_PATH"
  DB_DIR=$(dirname "$DB_PATH")
  if [ ! -d "$DB_DIR" ]; then
    log "   إنشاء مجلد قاعدة البيانات: $DB_DIR"
    mkdir -p "$DB_DIR"
    chown -R "$APP_USER":"$APP_USER" "$DB_DIR"
    chmod 750 "$DB_DIR"
  fi
  if [ ! -f "$DB_PATH" ]; then
    log "   إنشاء ملف قاعدة البيانات (فارغ مبدئيًا)"
    touch "$DB_PATH"
  fi
  chown "$APP_USER":"$APP_USER" "$DB_PATH" || true
  chmod 660 "$DB_PATH" || true
else
  warn "لم أستطع استخراج DB_PATH من smartfrind.db – قد تبقى مشكلة smartfrind-reflector."
fi

log "4) إصلاح EnvironmentFile لـ smartfrind-runner / smartfrind-trainer إذا كانت ناقصة"

fix_env_for_service(){
  local svc="$1"
  log "   → فحص الخدمة: $svc"
  local env_files
  env_files=$(systemctl show -p EnvironmentFile --value "$svc" 2>/dev/null || true)
  [ -z "$env_files" ] && { warn "      لا يوجد EnvironmentFile معرفة لـ $svc"; return; }
  for f in $env_files; do
    f=${f#-}  # systemd قد يسبق المسار بـ -
    [ -z "$f" ] && continue
    if [ ! -f "$f" ]; then
      log "      إنشاء ملف env مفقود: $f"
      mkdir -p "$(dirname "$f")"
      cat > "$f" <<EOF_ENV
# auto-created by sf_suite_stage2_fix_20251115
SMARTFRIND_ENV=production
# TODO: أضف المفاتيح/التوكنات المطلوبة يدويًا هنا (API keys, Telegram tokens, إلخ)
EOF_ENV
      chown root:root "$f" || true
      chmod 600 "$f" || true
    fi
  done
}

fix_env_for_service "smartfrind-runner.service"
fix_env_for_service "smartfrind-trainer.service"

log "5) منع تضارب البورت 8210 (الإبقاء على smartfrind-api كـ API رسمي)"
if systemctl list-unit-files | grep -q '^smartfrind-simple.service'; then
  log "   تعطيل smartfrind-simple.service (تجريبي)"
  systemctl disable --now smartfrind-simple.service 2>/dev/null || warn "فشل تعطيل smartfrind-simple"
fi
if systemctl list-unit-files | grep -q '^smartfrind-ultra.service'; then
  log "   تعطيل smartfrind-ultra.service (تجريبي)"
  systemctl disable --now smartfrind-ultra.service 2>/dev/null || warn "فشل تعطيل smartfrind-ultra"
fi

log "6) إعادة تحميل systemd وإعادة محاولة تشغيل الوحدات الأساسية"
systemctl daemon-reload

for svc in \
  smartfrind-api.service \
  sf-core.service \
  smartfrind-unified.service \
  smartfrind-reflector.service \
  smartfrind-runner.service \
  smartfrind-trainer.service \
; do
  if systemctl list-unit-files | grep -q "^$svc"; then
    log "   إعادة تشغيل: $svc"
    systemctl restart "$svc" 2>/dev/null || warn "فشل restart لـ $svc"
  fi
done

log "7) تقرير سريع بعد الإصلاح"
systemctl status \
  smartfrind-api.service \
  smartfrind-unified.service \
  smartfrind-reflector.service \
  smartfrind-runner.service \
  smartfrind-trainer.service \
  smartfrind-simple.service \
  smartfrind-ultra.service \
  --no-pager -l || true

log "انتهى sf_suite_stage2_fix_20251115."
