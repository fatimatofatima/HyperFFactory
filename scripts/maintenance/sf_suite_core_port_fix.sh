#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

extract_pids_on_8211() {
    ss -tulpn 2>/dev/null | awk '$5 ~ /:8211$/ {print $NF}' \
      | sed 's/users:(//' | tr ',' '\n' \
      | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' \
      | sort -u
}

log "[*] إيقاف sf-core.service مؤقتًا..."
systemctl stop sf-core.service || true

log "[*] فحص أي process ماسكة البورت 8211..."
PIDS="$(extract_pids_on_8211 || true)"

if [ -n "${PIDS:-}" ]; then
    log "[*] البروسيس الحالية على 8211: $PIDS"
    ps -p $PIDS -o pid,user,cmd --no-headers || true

    log "[*] إرسال SIGTERM للبروسيس على 8211..."
    kill -TERM $PIDS || true
    sleep 2

    PIDS2="$(extract_pids_on_8211 || true)"
    if [ -n "${PIDS2:-}" ]; then
        log "[!] لا زالت بعض البروسيس على 8211 بعد SIGTERM: $PIDS2"
        log "[*] إرسال SIGKILL للباقي..."
        kill -KILL $PIDS2 || true
        sleep 1
    fi
else
    log "[*] لا يوجد أي process حالياً على 8211."
fi

log "[*] التحقق النهائي للبورت 8211..."
ss -tulpn 2>/dev/null | awk '$5 ~ /:8211$/ {print $0}' || echo "لا يوجد listener على 8211 الآن."

log "[*] تشغيل sf-core.service مرة أخرى..."
systemctl start sf-core.service || true

log "[*] حالة sf-core.service (مختصرة):"
systemctl --no-pager --full status sf-core.service | sed -n '1,18p' || true

log "[*] فحص المستمعين على 8211 بعد التشغيل:"
ss -tulpn 2>/dev/null | awk '$5 ~ /:8211$/ {print $0}' || echo "لا يوجد process ظاهر على 8211 (تحقق يدويًا لو لزم)."

log "[*] انتهى إصلاح بورت 8211."
