#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"
OUT="/root/sf_suite_core_debug2_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$OUT"; }

log "=== SF SUITE CORE DEBUG #2 START ==="

log ""
log "1) systemctl status (مختصر) للخدمات الأساسية ..."
{
  systemctl --no-pager --plain status sf-memory sf-web sf-health sf-spider || true
} >>"$OUT" 2>&1

log ""
log "2) آخر 60 سطر من journalctl لكل خدمة ..."
for SVC in sf-memory.service sf-web.service sf-health.service sf-spider.service; do
  log ""
  log "------ journalctl -u ${SVC} -n 60 ------"
  journalctl -u "$SVC" -n 60 --no-pager >>"$OUT" 2>&1 || true
done

log ""
log "3) محتوى سكربتات الخدمة (ExecStart wrappers) ..."
for F in \
  /opt/smartfriend-suite/bin/sf-service-memory \
  /opt/smartfriend-suite/bin/sf-service-web \
  /opt/smartfriend-suite/bin/sf-service-health \
  /opt/smartfriend-suite/scripts/sf_spider_run.sh \
  /opt/smartfriend-suite/ops/sf_spider_run.sh \
  /opt/smartfriend-suite/bin/sf_spider_run.sh
do
  if [ -f "$F" ]; then
    log ""
    log "------ contents of $F ------"
    sed -n '1,200p' "$F" >>"$OUT" 2>&1 || true
  fi
done

log ""
log "4) هيكل مجلدات apps (جذر السيوت + داخل smartfriend) ..."
for D in \
  /opt/smartfriend-suite/apps \
  /opt/smartfriend-suite/smartfriend/apps
do
  if [ -d "$D" ]; then
    log ""
    log "------ tree of $D ------"
    (cd "$D" && find . -maxdepth 4 -type f | sort) >>"$OUT" 2>&1 || true
  else
    log ""
    log "------ $D غير موجود ------"
  fi
done

log ""
log "5) venvs المتاحة للسيوت (لـ health / spider / memory / web) ..."
for V in \
  /opt/smartfriend-suite/venv \
  /opt/smartfriend-suite/smartfriend/venv
do
  if [ -d "$V" ]; then
    log ""
    log "------ python -m pip show smartfriend_spider في $V ------"
    "$V/bin/python" -m pip show smartfriend_spider >>"$OUT" 2>&1 || log "smartfriend_spider غير مثبت في $V"
  else
    log ""
    log "------ $V غير موجود ------"
  fi
done

log ""
log "=== SF SUITE CORE DEBUG #2 END ==="
log "تم حفظ التقرير في: $OUT"
