#!/usr/bin/env bash
set -Eeuo pipefail

REPORT_DIR="/root/sf_audit_reports"
mkdir -p "$REPORT_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/full_audit_${TS}.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
section() { 
  echo
  echo "========================================================================"
  echo "== $*"
  echo "========================================================================"
}

# توجيه المخرجات للتقرير + الشاشة
exec > >(tee -a "$REPORT") 2>&1

section "SYSTEM SNAPSHOT"
hostnamectl || true
echo
date
echo
uptime || true
echo
df -h / || true
echo
free -h || true

section "/opt PROJECTS OVERVIEW"
if [ -d /opt ]; then
  for d in /opt/*; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    case "$base" in
      *smartfriend*|*smartfrind*|*ffactory*|*BRAIN*|*Brain*|*MyFriend*|*myfriend*)
        echo "[CORE]  $d"
        ;;
      *)
        echo "[OTHER] $d"
        ;;
    esac
  done
else
  echo "/opt غير موجودة على هذا السيرفر."
fi

section "SYSTEMD SERVICES (smart/ffactory/brain/myfriend)"

SERVICE_FILES=$( (ls /etc/systemd/system/*.service 2>/dev/null || true; \
                  ls /lib/systemd/system/*.service 2>/dev/null || true) \
                | grep -Ei 'smart|friend|ffactory|brain|myfriend' || true)

if [ -z "${SERVICE_FILES:-}" ]; then
  echo "لا توجد خدمات متطابقة مع الأنماط المطلوبة."
else
  echo "$SERVICE_FILES" | sort -u | while read -r svc; do
    [ -f "$svc" ] || continue
    name="$(basename "$svc")"
    echo
    echo "----- SERVICE: $name -----"
    grep -E '^(Description|ExecStart)=' "$svc" || true

    exec_line="$(grep -E '^ExecStart=' "$svc" | head -n1 | sed 's/^ExecStart=//')"
    if [ -n "${exec_line:-}" ]; then
      bin_path="$(echo "$exec_line" | awk '{print $1}' | sed 's/^"//;s/"$//')"
      if [ -n "${bin_path:-}" ]; then
        if [ -e "$bin_path" ]; then
          echo "ExecStart target exists: $bin_path"
        else
          echo "!!! BROKEN ExecStart target NOT FOUND: $bin_path"
        fi
      fi
    fi

    if command -v systemctl >/dev/null 2>&1; then
      echo
      echo "systemctl is-enabled $name:"
      systemctl is-enabled "$name" 2>&1 || true
      echo "systemctl is-active  $name:"
      systemctl is-active "$name" 2>&1 || true
    fi
  done
fi

section "DOCKER COMPOSE / STACK FILES UNDER /opt"
if [ -d /opt ]; then
  find /opt -maxdepth 4 -type f \( \
      -name 'docker-compose.yml' -o \
      -name 'docker-compose.*.yml' -o \
      -name '*compose*.yml' \
    \) -print 2>/dev/null | while read -r f; do
      echo
      echo "File: $f"
      grep -E '^\s*services:' -n "$f" || true
    done
else
  echo "/opt غير موجودة."
fi

section "REFERENCES TO BRAIN_CORE / MyFriend UNDER /opt"
if [ -d /opt ]; then
  echo "نماذج أولية (أول 200 نتيجة كحد أقصى):"
  grep -R --include='*.py' --include='*.sh' --include='*.service' \
       -nE 'BRAIN_CORE|BrainCore|MyFriend|MY_FRIEND' /opt 2>/dev/null \
       | head -n 200 || echo "لا توجد مراجع أو أقل من 200 سطر."
else
  echo "/opt غير موجودة."
fi

section "SUMMARY / NEXT STEPS (MANUAL)"
cat <<SUMMARY_EOF
- راجع قسم SYSTEMD SERVICES:
  * أي خدمة عليها !!! BROKEN ExecStart ⇒ تحتاج إما:
    - إصلاح المسار (إن كان المشروع ما زال مطلوبًا).
    - أو تعطيل/حذف الخدمة بعد التأكد من عدم احتياجها.
- راجع مخرجات REFERENCES لمعرفة أين يتم استدعاء BRAIN_CORE و MyFriend.
- استخدم تقارير الفحص المتخصصة (BRAIN_CORE و MyFriend) قبل أي قرار حذف.

تم حفظ هذا التقرير في:
  $REPORT
SUMMARY_EOF

