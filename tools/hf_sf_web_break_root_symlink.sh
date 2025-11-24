#!/usr/bin/env bash
# HyperFFactory – فك ارتباط sf-web عن /root وتصحيح CHDIR

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_break_root_symlink_${TS}.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "====================================================="
log "HyperFFactory – Fix sf-web CHDIR by breaking /root symlink"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

SRC_LINK="/opt/smartfriend-suite"
# تحقق من أن /opt/smartfriend-suite فعلاً symlink
if [ -L "$SRC_LINK" ]; then
  TARGET="$(readlink -f "$SRC_LINK" || true)"
  log "✓ /opt/smartfriend-suite هو symlink → $TARGET"
else
  log "ℹ️ /opt/smartfriend-suite ليس symlink، إيقاف السكربت (لا نلعب في البنية)."
  exit 0
fi

# تأكد أن الهدف داخل /root/HyperFFactory (حتى لا ننسخ شيء خارجي بالخطأ)
case "$TARGET" in
  /root/HyperFFactory/*)
    log "✓ الهدف داخل /root/HyperFFactory: $TARGET"
    ;;
  *)
    log "⚠️ الهدف $TARGET ليس داخل /root/HyperFFactory – إيقاف لحماية باقي الأنظمة."
    exit 1
    ;;
esac

log "1) عرض الوضع الحالي لـ /opt/smartfriend-suite"
ls -ld /opt /opt/smartfriend-suite | tee -a "$LOG" || true

log "2) إزالة symlink فقط (لا نمسّ محتوى $TARGET)"
rm "$SRC_LINK"
log "✓ أزلنا الرابط الرمزي /opt/smartfriend-suite (المجلد الفعلي تحت $TARGET ما زال موجوداً)"

log "3) إنشاء مجلد فعلي جديد /opt/smartfriend-suite ونسخ محتوى السيوت إليه"
mkdir -p /opt/smartfriend-suite

if command -v rsync >/dev/null 2>&1; then
  log "→ استخدام rsync -a لنسخ $TARGET/ → /opt/smartfriend-suite/"
  rsync -a "$TARGET"/ /opt/smartfriend-suite/
else
  log "→ rsync غير متاح، استخدام cp -a"
  cp -a "$TARGET"/. /opt/smartfriend-suite/
fi

log "✓ تم نسخ المحتوى إلى /opt/smartfriend-suite"

# ضبط الملكية والصلاحيات
if id smartfriend-suite >/dev/null 2>&1; then
  chown -R smartfriend-suite:smartfriend-suite /opt/smartfriend-suite || true
  log "✓ عدّلنا ملكية /opt/smartfriend-suite بالكامل إلى smartfriend-suite:smartfriend-suite"
else
  log "ℹ️ مستخدم smartfriend-suite غير موجود – تخطّي تعديل الملكية"
fi

chmod 755 /opt || true
chmod 755 /opt/smartfriend-suite || true
log "✓ عدّلنا صلاحيات /opt و /opt/smartfriend-suite إلى 755"

log "4) تأكيد وجود مجلد الويب الجديد تحت /opt"
ls -ld /opt/smartfriend-suite/web || true
ls -l  /opt/smartfriend-suite/web | head -n 20 || true

# تأكيد محتوى override.conf بحيث يستخدم /opt مباشرة (وليس root)
DROPIN_DIR="/etc/systemd/system/sf-web.service.d"
mkdir -p "$DROPIN_DIR"

cat > "$DROPIN_DIR/override.conf" <<CONF
[Service]
WorkingDirectory=/opt/smartfriend-suite/web
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF

log "✓ كتبنا /etc/systemd/system/sf-web.service.d/override.conf بمسار /opt فعلي"

log "5) daemon-reload + restart sf-web"
systemctl daemon-reload

if systemctl restart sf-web.service; then
  log "✓ sf-web.service تم إعادة تشغيله بنجاح"
else
  log "⚠️ فشل في إعادة تشغيل sf-web.service – راجع status بالأسفل"
fi

log "6) systemctl status sf-web (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

log "7) Health check على 8390"
curl -s http://127.0.0.1:8390/health || echo '❌ Web UI /health غير متاح' | tee -a "$LOG"

log "====================================================="
log "DONE – hf_sf_web_break_root_symlink"
log "Report: $LOG"
log "====================================================="
