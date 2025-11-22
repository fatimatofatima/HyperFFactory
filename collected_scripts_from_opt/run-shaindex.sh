#!/usr/bin/env bash
set -Eeuo pipefail
LOG="/var/log/osmart-shaindex.log"
touch "$LOG"
chmod 640 "$LOG"

# حمّل الإعدادات
set -a
[ -f /etc/osmart-shaindex.env ] && . /etc/osmart-shaindex.env
set +a

: "${DB_NAME:=Ossmart}"
: "${DB_USER:=osmart}"
: "${DB_PASS:?DB_PASS مطلوب}"
: "${PHOTOS_DIR:?PHOTOS_DIR مطلوب}"
: "${LIMIT:=0}"

export DB_NAME DB_USER DB_PASS TABLE="${TABLE:-photos_index}"

exec /root/OSsmart/shaFile/shaefix.sh --dir "$PHOTOS_DIR" ${LIMIT:+--limit "$LIMIT"} >>"$LOG" 2>&1
