#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
section(){
  printf '\n%s\n' "======================================================================"
  log "$*"
  echo "======================================================================"
}

HOSTNAME="$(hostname)"
NOW="$(date '+%F %T %z')"

###############################################################################
# 0) نظرة عامة على السيرفر
###############################################################################
section "لقطة عامة على السيرفر"

echo "Hostname: $HOSTNAME"
echo "وقت السيرفر: $NOW"
echo

echo "---- UPTIME / LOAD ----"
uptime || true
echo

echo "---- DISK (/) ----"
df -h / || true
echo

echo "---- MEMORY ----"
free -h || true
echo

echo "---- TOP 5 PROCESSES BY CPU ----"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6 || true
echo

###############################################################################
# 1) ملخص حالة الخدمات
###############################################################################
section "ملخص حالة خدمات systemd"

echo "---- تلخيص حسب الحالة (running / failed / غيرها) ----"
systemctl list-units --type=service --all --no-pager --no-legend \
  | awk '{print $4}' \
  | sort \
  | uniq -c \
  | sed 's/^/  /' || true

echo
echo "---- قائمة الخدمات الفاشلة (failed) إن وجدت ----"
systemctl --failed --type=service --no-pager --no-legend 2>/dev/null || true

###############################################################################
# 2) فحص وإصلاح الخدمات الفاشلة
###############################################################################
section "فحص وإصلاح الخدمات في حالة FAILED"

FAILED_SERVICES="$(systemctl --failed --type=service --no-legend 2>/dev/null | awk '{print $1}')"

if [[ -z "$FAILED_SERVICES" ]]; then
  log "لا توجد خدمات في حالة FAILED حاليًا."
else
  for svc in $FAILED_SERVICES; do
    section "تفاصيل الخدمة الفاشلة قبل الإصلاح: $svc"

    echo "---- systemctl status $svc (قبل) ----"
    systemctl status "$svc" --no-pager -l || true
    echo

    echo "---- آخر 20 سطر من journalctl -u $svc (قبل) ----"
    journalctl -u "$svc" -n 20 --no-pager || true
    echo

    log "محاولة إعادة تشغيل الخدمة: $svc"
    if systemctl restart "$svc"; then
      log "إعادة تشغيل $svc نجحت - إعادة فحص الحالة..."
    else
      log "تحذير: فشل إعادة تشغيل $svc"
    fi

    echo
    echo "---- systemctl status $svc (بعد) ----"
    systemctl status "$svc" --no-pager -l || true

    echo
    echo "---- آخر 20 سطر من journalctl -u $svc (بعد) ----"
    journalctl -u "$svc" -n 20 --no-pager || true
  done
fi

###############################################################################
# 3) تقرير مختصر عن الخدمات المتوقفة لكنها ليست FAILED
###############################################################################
section "الخدمات المتوقفة (inactive/dead) ولكن ليست FAILED"

echo "---- أمثلة (حتى 20 خدمة فقط) ----"
systemctl list-units --type=service --state=inactive,dead --no-pager --no-legend \
  | head -n 20 \
  | sed 's/^/  /' || true

echo
log "ملاحظة: لم يتم تشغيل أي خدمة متوقفة تلقائيًا، فقط تم عرضها للمراجعة اليدوية."

###############################################################################
# 4) دمج تقرير SmartFriend Suite (لو السكربت موجود)
###############################################################################
section "تقرير SmartFriend Suite (sf_suite_status_now.sh) - إن وجد"

if [[ -x /root/sf_suite_status_now.sh ]]; then
  /root/sf_suite_status_now.sh || log "تحذير: sf_suite_status_now.sh أعاد خطأ"
else
  log "sf_suite_status_now.sh غير موجود أو غير قابل للتنفيذ - تخطي هذه الخطوة."
fi

section "انتهى فحص خدمات السيرفر وإصلاح الفاشل منها."
