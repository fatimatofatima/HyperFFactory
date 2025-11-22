#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"
BASE="/root/sf_reports"
OUT="${BASE}/sf_migrate_${TS}"
LOG="${OUT}/sf_migrate.log"

mkdir -p "$OUT"
: > "$LOG"

teeout(){ tee -a "$LOG" >/dev/null; }
sec(){ echo -e "\n========== $1 ==========" | teeout; }

sec "معلومات عامة عن النظام"
{
  echo "Timestamp: $TS"
  echo "Hostname: $(hostname)"
  echo "Kernel: $(uname -a)"
  echo
  echo "----- Uptime -----"
  uptime || true
  echo
  echo "----- Disk (/) -----"
  df -h / || true
  echo
  echo "----- Memory -----"
  free -h || true
  echo
  echo "----- IP -----"
  ip addr show || true
} | teeout

sec "مسارات ومجلدات smartfrind / smartfriend-suite"
{
  CANDIDATES=(
    "/opt/smartfrind"
    "/opt/smartfriend-suite"
    "/opt-projects/smartfriend-suite"
    "/opt-projects/smartfriend-suite-backup"
    "/opt-projects/smartfriend-suite-backup-2025"
    "/opt-projects/smartfriend-suite-backup-20251109-025421"
    "/opt/smartfriend-complete-system"
    "/opt/smartfriend-complete-system/apps"
    "/opt/smartfriend-complete-system/scripts"
  )

  for d in "${CANDIDATES[@]}"; do
    if [ -e "$d" ]; then
      echo "--- موجود: $d"
      ls -ld "$d" || true
      du -sh "$d" 2>/dev/null || true
      echo
    else
      echo "--- غير موجود: $d"
    fi
  done

  echo
  echo "بحث عام عن أي مجلدات باسم smartfrind/smartfriend تحت /opt و /opt-projects (عمق 5):"
  find /opt /opt-projects -maxdepth 5 -type d \( -iname '*smartfrind*' -o -iname '*smartfriend*' \) 2>/dev/null || true
} | teeout

sec "وحدات systemd المرتبطة بـ smartfrind / smartfriend-suite / sf-*"
{
  echo "----- list-unit-files (تعريف الخدمات) -----"
  if command -v systemctl >/dev/null 2>&1; then
    echo
    echo "[smartfrind-related]:"
    while read -r line; do
      case "$line" in
        *smartfrind*|*SmartFrind*|*SMARTFRIND*) echo "$line";;
      esac
    done < <(systemctl list-unit-files --type=service --no-pager 2>/dev/null)

    echo
    echo "[smartfriend-suite / sf-suite / sf-*]:"
    while read -r line; do
      case "$line" in
        *smartfriend-suite*|*sf-suite*|*sf-* ) echo "$line";;
      esac
    done < <(systemctl list-unit-files --type=service --no-pager 2>/dev/null)

    echo
    echo "----- list-units (الحالة الحالية) -----"
    echo
    echo "[smartfrind-related]:"
    while read -r line; do
      case "$line" in
        *smartfrind*|*SmartFrind*|*SMARTFRIND*) echo "$line";;
      esac
    done < <(systemctl list-units --type=service --all --no-pager 2>/dev/null)

    echo
    echo "[smartfriend-suite / sf-suite / sf-*]:"
    while read -r line; do
      case "$line" in
        *smartfriend-suite*|*sf-suite*|*sf-* ) echo "$line";;
      esac
    done < <(systemctl list-units --type=service --all --no-pager 2>/dev/null)
  else
    echo "systemctl غير متوفر على هذا النظام."
  fi
} | teeout

sec "أوضاع الخدمات الحرجة (إن وُجدت)"
{
  CAND_SERVICES=(
    "smartfrind-core.service"
    "smartfrind-gateway.service"
    "smartfrind-spider.service"
    "smartfrind-health.service"
    "sf-health.service"
    "sf-gateway.service"
    "sf-core.service"
    "sf-board.service"
    "smartfriend-suite.service"
  )

  if command -v systemctl >/dev/null 2>&1; then
    for s in "${CAND_SERVICES[@]}"; do
      echo "----- $s -----"
      if systemctl list-unit-files "$s" >/dev/null 2>&1; then
        systemctl status "$s" --no-pager || true
      else
        echo "لا توجد خدمة بهذا الاسم (غير معرفة)."
      fi
      echo
    done
  else
    echo "systemctl غير متوفر."
  fi
} | teeout

sec "العمليات الجارية المرتبطة بالمشروعين"
{
  echo "ps aux | smartfrind / smartfriend-suite / sf-"
  ps aux 2>/dev/null | awk '
    /[sS]martfrind/ || /[sS]martfriend-suite/ || /sf-/ {
      print
    }
  ' || true
} | teeout

sec "البورتات المهمة (8000, 8210, 8213, 8220, 5052)"
{
  PORTS_RE=":8000|:8210|:8213|:8220|:5052"
  if command -v ss >/dev/null 2>&1; then
    echo "ss -tulpn (مع تصفية البورتات المهمة):"
    ss -tulpn 2>/dev/null | awk '
      /:8000 / || /:8210 / || /:8213 / || /:8220 / || /:5052 / { print }
    ' || true
  elif command -v netstat >/dev/null 2>&1; then
    echo "netstat -tulpn (مع تصفية البورتات المهمة):"
    netstat -tulpn 2>/dev/null | awk '
      /:8000 / || /:8210 / || /:8213 / || /:8220 / || /:5052 / { print }
    ' || true
  else
    echo "لا ss ولا netstat متوفرين؛ تخطي فحص البورتات."
  fi
} | teeout

sec "كشف المراجع المتبقية لمسار /opt/smartfrind في الإعدادات"
{
  echo "بحث حتى 200 نتيجة عن /opt/smartfrind داخل /etc و /opt و /srv (قد يأخذ بعض الوقت)..."
  if grep -R -n -m 200 "/opt/smartfrind" /etc /opt /srv 2>/dev/null >>"$LOG"; then
    echo "تم العثور على مراجع لمسار /opt/smartfrind (راجع التفاصيل في ملف اللوج)." | teeout
  else
    echo "لا توجد مراجع واضحة لمسار /opt/smartfrind في /etc أو /opt أو /srv (في حدود 200 نتيجة)." | teeout
  fi
} | teeout

sec "ملخص نهائي"
{
  echo "مجلد التقرير الكامل:"
  echo "  $OUT"
  echo
  echo "ملف اللوج الرئيسي:"
  echo "  $LOG"
  echo
  echo "استخدم مثلاً:"
  echo "  less \"$LOG\""
  echo "لمراجعة الفحص بالتفصيل قبل تنفيذ أي خطوة نقل/دمج/حذف."
} | teeout

echo
echo "=== انتهى فحص الهجرة (smartfrind -> smartfriend-suite) عند: $(date) ===" | teeout
