#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

log "=== 1) مزامنة TELEGRAM_BOT_TOKEN مع BOT_SMARTFRIND_TOKEN ==="

# استخراج التوكن القديم والجديد من ملفات البيئة
OLD_TOKEN="$(grep -E '^TELEGRAM_BOT_TOKEN=' /etc/smartfriend/secrets.env 2>/dev/null | head -n1 | cut -d= -f2- || true)"
NEW_TOKEN="$(grep -E '^BOT_SMARTFRIND_TOKEN=' /etc/smartfriend/train_secrets.env 2>/dev/null | head -n1 | cut -d= -f2- || true)"

if [[ -z "$NEW_TOKEN" ]]; then
  log "ERROR: لم يتم العثور على BOT_SMARTFRIND_TOKEN في /etc/smartfriend/train_secrets.env"
  exit 1
fi

BACKUP_DIR="/opt/smartfriend-suite/backups/token_env_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

log "أخذ نسخة احتياطية من /etc/smartfriend/secrets.env إلى: $BACKUP_DIR"
/bin/cp -a /etc/smartfriend/secrets.env "$BACKUP_DIR"/ 2>/dev/null || true

if [[ -n "$OLD_TOKEN" && "$OLD_TOKEN" != "$NEW_TOKEN" ]]; then
  log "تحديث TELEGRAM_BOT_TOKEN في /etc/smartfriend/secrets.env ليطابق BOT_SMARTFRIND_TOKEN"
  perl -pi -e 's/\Q'"$OLD_TOKEN"'\E/'"$NEW_TOKEN"'/g' /etc/smartfriend/secrets.env
elif [[ -z "$OLD_TOKEN" ]]; then
  log "إضافة TELEGRAM_BOT_TOKEN جديد إلى /etc/smartfriend/secrets.env"
  echo "TELEGRAM_BOT_TOKEN=$NEW_TOKEN" >> /etc/smartfriend/secrets.env
else
  log "TELEGRAM_BOT_TOKEN بالفعل يطابق BOT_SMARTFRIND_TOKEN – لا حاجة للتعديل"
fi

log "إعادة تحميل systemd وإعادة تشغيل sf-bot.service"
systemctl daemon-reload
systemctl restart sf-bot.service || true

log "=== حالة sf-bot.service (بعد تحديث التوكن) ==="
systemctl status sf-bot.service --no-pager -n 8 || true

log ""
log "=== 2) إصلاح smartfrind-learner ليعمل oneshot من خلال الـ timer فقط ==="

# إنشاء drop-in نهائي يضبط نوع الخدمة وسياسة إعادة التشغيل
cat > /etc/systemd/system/smartfrind-learner.service.d/60-oneshot-fix.conf <<'EOC'
[Service]
Type=oneshot
Restart=no
ExecStart=
ExecStart=/opt/smartfriend-suite/smartfrind/venv/bin/python /opt/smartfriend-suite/bots/learner/net_learner.py
Environment=PATH=/opt/smartfriend-suite/smartfrind/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONPATH=/opt/smartfriend-suite:/opt/smartfriend-suite/smartfrind
WorkingDirectory=/opt/smartfriend-suite
EOC

log "إعادة تحميل systemd وإعادة تعيين حدود إعادة التشغيل لـ smartfrind-learner"
systemctl daemon-reload
systemctl reset-failed smartfrind-learner.service || true

log "تشغيل smartfrind-learner مرة واحدة يدويًا للاختبار"
systemctl start smartfrind-learner.service || true

sleep 3
log "=== حالة smartfrind-learner.service بعد التعديل ==="
systemctl status smartfrind-learner.service --no-pager -n 8 || true

log ""
log "اكتمل السكربت. تحقق من سجلات sf-bot إذا استمر أي خطأ مرتبط بالـ token."
