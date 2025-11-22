#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT="/root/sf_suite_core_diag_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*"; }

{
  echo "============================================================"
  echo " SmartFriend Suite – CORE DIAG"
  echo " Timestamp : $(date '+%F %T')"
  echo " Hostname  : $(hostname)"
  echo "============================================================"
  echo

  echo "### 1) أساسيات المسارات والملفات"
  echo
  ls -ld /opt/smartfriend-suite || echo "MISSING: /opt/smartfriend-suite"
  ls -ld /opt/smartfriend-suite/var /opt/smartfriend-suite/var/db 2>/dev/null || true
  echo
  echo ">> قواعد البيانات المتاحة:"
  find /opt/smartfriend-suite -maxdepth 4 -type f -name '*smartfriend*_*.db' -o -name 'smartfriend_unified.db' 2>/dev/null | sed 's/^/  - /' || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 2) محتوى ملف البيئة sf_suite.env (أول 200 سطر)"
  echo
  if [ -f /etc/smartfriend/sf_suite.env ]; then
    sed -n '1,200p' /etc/smartfriend/sf_suite.env
  else
    echo "MISSING: /etc/smartfriend/sf_suite.env"
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 3) حالة الخدمات الأساسية sf-* (status مختصر)"
  echo
  systemctl --no-pager --plain status \
    sf-unified.service \
    sf-memory.service  \
    sf-web.service     \
    sf-health.service  \
    sf-spider.service  \
    sf-learning.service || true
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 4) آخر 80 سطر من logs لكل خدمة أساسية"
  echo

  for u in sf-unified.service sf-memory.service sf-web.service sf-health.service sf-spider.service sf-learning.service; do
    echo "-----------------------------"
    echo ">> journalctl -u $u -n 80"
    echo "-----------------------------"
    journalctl -u "$u" -n 80 --no-pager 2>&1 || echo "no logs for $u"
    echo
  done
  echo "------------------------------------------------------------"
  echo

  echo "### 5) البورتات الحرجة المفتوحة"
  echo
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn 2>/dev/null | grep -E ':(8210|8211|8214|8220|8390)\b' || echo "لا توجد بورتات مطابقة حالياً."
  else
    echo "أداة ss غير موجودة."
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 6) اختبار Nginx /ffactory/ /unified/ /memory/"
  echo
  if command -v curl >/dev/null 2>&1; then
    for path in / /ffactory/ /unified/ /memory/ ; do
      echo ">>> curl -I http://127.0.0.1${path}"
      curl -I "http://127.0.0.1${path}" 2>&1 || echo "فشل الاتصال بـ ${path}"
      echo
    done
  else
    echo "أداة curl غير موجودة."
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "### 7) نسخة سريعة من smartfriend.conf بعد التبديل"
  echo
  if [ -f /etc/nginx/sites-enabled/smartfriend.conf ]; then
    sed -n '1,220p' /etc/nginx/sites-enabled/smartfriend.conf
  else
    echo "MISSING: /etc/nginx/sites-enabled/smartfriend.conf"
  fi
  echo
  echo "------------------------------------------------------------"
  echo

  echo "End of CORE DIAG"
  echo "============================================================"
} | tee "$OUT"

log "تم حفظ تقرير التشخيص في: $OUT"
