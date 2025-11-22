#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }
err()   { echo -e "${RED}[$(date '+%F %T')] [ERR]${NC} $*" >&2; }

REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/sf_suite_fix_and_align_$(date +%Y%m%d_%H%M%S).log"

teeout(){ tee -a "$REPORT"; }

log "=== SmartFriend Suite – توحيد وتشغيل السيوت وتنظيم الطبقات ===" | teeout
echo | teeout

log "اكتشاف المجموعات (sf-*, smartfriend-*, smartfrind-*) ..." | teeout

# طبقة السيوت الرسمية
mapfile -t SUITE_SF < <(systemctl list-unit-files 'sf-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)
mapfile -t SUITE_SMARTFRIEND < <(systemctl list-unit-files 'smartfriend-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)

# طبقة SmartFrind القديمة (Legacy)
mapfile -t LEGACY_SMARTFRIND < <(systemctl list-unit-files 'smartfrind-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)

log "=== ملخص المجموعات المكتشفة ===" | teeout
echo "  • sf-*              : ${#SUITE_SF[@]} خدمة"     | teeout
echo "  • smartfriend-*     : ${#SUITE_SMARTFRIEND[@]} خدمة" | teeout
echo "  • smartfrind-* (Legacy): ${#LEGACY_SMARTFRIND[@]} خدمة" | teeout
echo | teeout

###############################################################################
# 1) عزل طبقة SmartFrind legacy (smartfrind-*)
###############################################################################
log "الخطوة 1: عزل طبقة SmartFrind legacy (smartfrind-*) بدون حذفها ..." | teeout

if ((${#LEGACY_SMARTFRIND[@]} == 0)); then
  warn "لا توجد خدمات smartfrind-*. لا حاجة لعزل legacy." | teeout
else
  for unit in "${LEGACY_SMARTFRIND[@]}"; do
    echo "------------------------------------------------------------" | teeout
    log "معالجة (إيقاف + disable) $unit ..." | teeout
    if systemctl is-active --quiet "$unit"; then
      if systemctl stop "$unit"; then
        ok "تم إيقاف $unit" | teeout
      else
        warn "فشل إيقاف $unit (تجاهل واستمر)" | teeout
      fi
    else
      warn "$unit غير نشط أصلاً (inactive)" | teeout
    fi

    # disable فقط إذا لم يكن Static
    if systemctl show -p UnitFileState "$unit" | grep -q 'UnitFileState=static'; then
      warn "$unit من نوع static – سيتم تركه بدون disable" | teeout
    else
      if systemctl disable "$unit" >/dev/null 2>&1; then
        ok "تم disable لـ $unit (لن يقلع تلقائياً)" | teeout
      else
        warn "فشل disable لـ $unit (قد يكون template أو static)" | teeout
      fi
    fi
  done
fi

echo | teeout

###############################################################################
# 2) تشغيل وتمكين طبقة السيوت الرسمية sf-* + smartfriend-*
###############################################################################
log "الخطوة 2: تشغيل وتمكين طبقة السيوت الرسمية (sf-* + smartfriend-*) ..." | teeout

SUCCESS_LIST=()
FAILED_LIST=()
SKIPPED_LIST=()

handle_unit(){
  local unit="$1"

  # استثناءات template / سكربتات خاصة
  case "$unit" in
    sf-service-template@.service)
      SKIPPED_LIST+=("$unit (template)")
      warn "تخطي $unit لأنه Template" | teeout
      return 0
      ;;
    smartfrind-delta.sh.service|smartfrind-setup.sh.service)
      SKIPPED_LIST+=("$unit (legacy helper)")
      warn "تخطي $unit لأنه Helper/Legacy" | teeout
      return 0
      ;;
  esac

  echo "------------------------------------------------------------" | teeout
  log "معالجة $unit ..." | teeout

  # لا نلمس ffactory أو ff-
  if [[ "$unit" == ff-* || "$unit" == ffactory-* || "$unit" == factory-gw.service ]]; then
    SKIPPED_LIST+=("$unit (ffactory)")
    warn "تخطي $unit (تابع لـ ffactory)" | teeout
    return 0
  fi

  # enable إذا لم يكن static
  if systemctl show -p UnitFileState "$unit" 2>/dev/null | grep -q 'UnitFileState=static'; then
    warn "$unit من نوع static – لن يتم enable، فقط restart إن أمكن" | teeout
  else
    if systemctl enable "$unit" >/dev/null 2>&1; then
      ok "enable $unit" | teeout
    else
      warn "فشل enable لـ $unit (قد يكون template أو static)" | teeout
    fi
  fi

  # restart
  if systemctl restart "$unit" >/dev/null 2>&1; then
    ok "restart $unit" | teeout
    SUCCESS_LIST+=("$unit")
  else
    err "فشل restart لـ $unit – راجع: journalctl -u $unit -n 50 --no-pager" | teeout
    FAILED_LIST+=("$unit")
  fi
}

# معالجة sf-*
for unit in "${SUITE_SF[@]}"; do
  handle_unit "$unit"
done

# معالجة smartfriend-*
for unit in "${SUITE_SMARTFRIEND[@]}"; do
  handle_unit "$unit"
done

echo | teeout
log "الخطوة 3: ملخص نهائي" | teeout

echo "[OK] الخدمات التي اعتُبرت ناجحة:" | teeout
if ((${#SUCCESS_LIST[@]} == 0)); then
  echo "  (لا شيء)" | teeout
else
  for u in "${SUCCESS_LIST[@]}"; do
    echo "  + $u" | teeout
  done
fi

echo | teeout
echo "[WARN] الخدمات التي فشل restart لها وتحتاج مراجعة يدوية:" | teeout
if ((${#FAILED_LIST[@]} == 0)); then
  echo "  (لا شيء)" | teeout
else
  for u in "${FAILED_LIST[@]}"; do
    echo "  - $u" | teeout
  done
fi

echo | teeout
echo "[INFO] الخدمات التي تم تخطيها عمداً (template/static/ffactory):" | teeout
if ((${#SKIPPED_LIST[@]} == 0)); then
  echo "  (لا شيء)" | teeout
else
  for u in "${SKIPPED_LIST[@]}"; do
    echo "  * $u" | teeout
  done
fi

echo | teeout
log "انتهى السكربت. تقرير التنفيذ في: $REPORT" | teeout
