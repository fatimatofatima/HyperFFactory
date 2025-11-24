#!/usr/bin/env bash
# HyperFFactory – Fix sf-web CHDIR by moving SmartFriend Suite out of /root

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_LINK="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
BACKUP_DIR="$ROOT/backup_smartfriend_suite"
DROPIN_DIR="/etc/systemd/system/sf-web.service.d"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR" "$DROPIN_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_outroot_fix_${TS}.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

header() {
  echo ""       | tee -a "$LOG"
  echo "=====================================================" | tee -a "$LOG"
  echo "$*"     | tee -a "$LOG"
  echo "=====================================================" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – SmartFriend Suite out-of-/root fix (sf-web CHDIR)"
log "ROOT        : $ROOT"
log "SUITE_LINK  : $SUITE_LINK"
log "REPORT_DIR  : $REPORT_DIR"
log "BACKUP_DIR  : $BACKUP_DIR"
log "TIME        : $TS"
log "LOG         : $LOG"
log "====================================================="

###############################################################################
# 1) معلومات أولية عن /opt/smartfriend-suite
###############################################################################
header "1) Inspect /opt/smartfriend-suite (symlink vs real dir)"

if [ -L "$SUITE_LINK" ]; then
  TARGET="$(readlink -f "$SUITE_LINK" || true)"
  log "ℹ️ /opt/smartfriend-suite هو symlink → $TARGET"
else
  if [ -d "$SUITE_LINK" ]; then
    log "ℹ️ /opt/smartfriend-suite هو مجلد عادي (ليس symlink)"
  else
    log "⚠️ /opt/smartfriend-suite غير موجود – سيتم إنشاؤه كمجلد عادي"
  fi
fi

ls -ld /opt "$SUITE_LINK" 2>&1 | tee -a "$LOG" || true

###############################################################################
# 2) إذا كان symlink يشير إلى مسار تحت /root → ننقل المحتوى إلى /opt حقيقي
###############################################################################
header "2) If symlink under /root → materialize real /opt/smartfriend-suite"

if [ -L "$SUITE_LINK" ]; then
  TARGET="$(readlink -f "$SUITE_LINK" || true)"
  if [ -z "$TARGET" ]; then
    log "❌ readlink فشل – لا يمكن متابعة الإصلاح"
    exit 1
  fi

  log "ℹ️ Target للـ symlink هو: $TARGET"

  case "$TARGET" in
    /root/*)
      log "⚠️ Target داخل /root → هذا هو السبب في CHDIR (مستخدم smartfriend-suite لا يمكنه المرور عبر /root)"

      # 2.1) أخذ نسخة احتياطية من الهدف
      if [ -d "$TARGET" ]; then
        TAR_BKP="$BACKUP_DIR/smartfriend_suite_under_root_${TS}.tar.gz"
        log "▶️ أخذ نسخة احتياطية من $TARGET إلى $TAR_BKP"
        tar -czf "$TAR_BKP" -C "$TARGET" . || log "⚠️ فشل tar (قد يكون تافهًا إذا الحجم كبير، نكمل بحذر)"
      else
        log "⚠️ TARGET ليس مجلدًا موجودًا: $TARGET"
      fi

      # 2.2) إزالة symlink نفسه (بدون حذف الهدف)
      SYM_BKP="$BACKUP_DIR/smartfriend-suite.symlink_${TS}"
      log "▶️ نقل symlink /opt/smartfriend-suite إلى $SYM_BKP"
      mv "$SUITE_LINK" "$SYM_BKP"

      # 2.3) إنشاء مجلد حقيقي تحت /opt
      log "▶️ إنشاء مجلد فعلي /opt/smartfriend-suite"
      mkdir -p "$SUITE_LINK"

      # 2.4) نسخ المحتوى من TARGET إلى /opt/smartfriend-suite
      if [ -d "$TARGET" ]; then
        if command -v rsync >/dev/null 2>&1; then
          log "▶️ rsync -a $TARGET/ → $SUITE_LINK/"
          rsync -a "$TARGET"/ "$SUITE_LINK"/
        else
          log "▶️ rsync غير موجود – نستخدم cp -a"
          cp -a "$TARGET"/. "$SUITE_LINK"/
        fi
      fi

    ;;
    *)
      log "ℹ️ Target لا يقع تحت /root، لن ننقل شيئًا."
    ;;
  esac
else
  log "ℹ️ /opt/smartfriend-suite ليس symlink – لا حاجة لنقل الهدف من /root."
fi

###############################################################################
# 3) ضبط المالك والصلاحيات تحت /opt/smartfriend-suite
###############################################################################
header "3) Fix ownership & perms under /opt/smartfriend-suite"

if [ -d "$SUITE_LINK" ]; then
  if id smartfriend-suite >/dev/null 2>&1; then
    log "▶️ chown -R smartfriend-suite:smartfriend-suite $SUITE_LINK"
    chown -R smartfriend-suite:smartfriend-suite "$SUITE_LINK"
  else
    log "ℹ️ مستخدم smartfriend-suite غير موجود – تخطي chown"
  fi

  log "▶️ ضبط صلاحيات المرور على /opt و /opt/smartfriend-suite"
  chmod 755 /opt || true
  chmod 755 "$SUITE_LINK" || true

  log "✔️ حالة المسارات الآن:"
  ls -ld /opt "$SUITE_LINK" "$SUITE_LINK/web" 2>&1 | tee -a "$LOG" || true
else
  log "❌ ما زال /opt/smartfriend-suite غير موجود كمسار فعلي – إلغاء بقية الخطوات"
  exit 1
fi

###############################################################################
# 4) التأكد من وجود web/run_web.py تحت /opt/smartfriend-suite
###############################################################################
header "4) Ensure web/run_web.py under /opt/smartfriend-suite"

WEB_DIR="$SUITE_LINK/web"
WEB_FILE="$WEB_DIR/run_web.py"

mkdir -p "$WEB_DIR"

if [ -f "$WEB_FILE" ]; then
  log "ℹ️ موجود بالفعل: $WEB_FILE"
else
  # إذا لم يوجد، نحاول استخدام النسخة الموجودة سابقًا في HyperFFactory كمرجع
  SRC_WEB="$ROOT/collected_scripts_from_opt/run_web.py"
  if [ -f "$SRC_WEB" ]; then
    log "▶️ نسخ run_web.py من $SRC_WEB إلى $WEB_FILE"
    cp "$SRC_WEB" "$WEB_FILE"
  else
    log "⚠️ لم نجد $WEB_FILE ولا $SRC_WEB – sf-web لن يعمل بدون سكربت ويب"
  fi
fi

if id smartfriend-suite >/dev/null 2>&1; then
  chown -R smartfriend-suite:smartfriend-suite "$WEB_DIR"
fi

###############################################################################
# 5) توحيد Drop-ins الخاصة بـ sf-web (العمل من /opt وليس /root)
###############################################################################
header "5) Normalize sf-web drop-ins (WorkingDirectory + ExecStart)"

# نأخذ نسخة احتياطية من مجلد drop-ins كامل
if [ -d "$DROPIN_DIR" ]; then
  DROPIN_BKP="$BACKUP_DIR/sf-web.service.d_${TS}.tar.gz"
  log "▶️ أخذ نسخة احتياطية من $DROPIN_DIR إلى $DROPIN_BKP"
  tar -czf "$DROPIN_BKP" -C "$DROPIN_DIR" . || log "⚠️ فشل tar (نكمل)"
fi

# نحذف أي conf قديم خاص بـ chdir/autopath حتى لا تتعارض
for f in 50-autofix-exec.conf 60-hf-root.conf 70-hf-autopath.conf 80-hf-web-final.conf 90-hf-web-chdir.conf; do
  if [ -f "$DROPIN_DIR/$f" ]; then
    mv "$DROPIN_DIR/$f" "$BACKUP_DIR/${f}_${TS}.bak"
    log "ℹ️ نقلنا $DROPIN_DIR/$f → $BACKUP_DIR/${f}_${TS}.bak"
  fi
done

# نكتب override.conf نظيف يفرض المسار الصحيح
cat > "$DROPIN_DIR/override.conf" <<'CONF'
[Service]
# نجبر الخدمة أن تعمل من داخل /opt/smartfriend-suite/web
WorkingDirectory=/opt/smartfriend-suite/web

# تنظيف أي ExecStart سابق واستبداله بأمر واحد واضح
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF

log "✔️ كتبنا $DROPIN_DIR/override.conf بالقيم النهائية"

###############################################################################
# 6) daemon-reload + restart sf-web
###############################################################################
header "6) systemd daemon-reload + restart sf-web"

log "▶️ systemctl daemon-reload"
systemctl daemon-reload

log "▶️ systemctl restart sf-web.service"
if systemctl restart sf-web.service; then
  log "✔️ sf-web.service تم إعادة تشغيله (systemctl restart)"
else
  log "⚠️ فشل في restart sf-web.service – راجع status بالخطوة التالية"
fi

###############################################################################
# 7) Snapshot + Health check
###############################################################################
header "7) Post-status snapshot + /health"

systemctl --no-pager -l status sf-web.service 2>&1 | sed -n '1,80p' | tee -a "$LOG" || true

log "---- curl 8390 /health ----"
curl -s http://127.0.0.1:8390/health || echo "❌ Web UI /health غير متاح" | tee -a "$LOG"

log "---- curl 8390 / ----"
curl -s http://127.0.0.1:8390/ || echo "❌ Web UI / غير متاح" | tee -a "$LOG"

log "====================================================="
log "DONE – hf_sf_web_outroot_fix finished"
log "Report: $LOG"
log "====================================================="

