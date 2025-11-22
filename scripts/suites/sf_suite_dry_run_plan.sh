#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
PLAN_FILE="$REPORT_DIR/sf_suite_dry_run_plan_${TS}.txt"

mkdir -p "$REPORT_DIR"

log(){ echo "[$(date '+%F %T')] $*"; }

section(){
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

summary_family() {
  local fam="$1"
  echo "• عائلة ${fam}-*"
  local unit_files loaded active failed
  unit_files=$(systemctl list-unit-files "${fam}-*" --no-legend 2>/dev/null | wc -l | awk '{print $1}')
  loaded=$(systemctl list-units "${fam}-*" --no-legend 2>/dev/null | wc -l | awk '{print $1}')
  active=$(systemctl list-units "${fam}-*" --state=active --no-legend 2>/dev/null | wc -l | awk '{print $1}')
  failed=$(systemctl list-units "${fam}-*" --state=failed --no-legend 2>/dev/null | wc -l | awk '{print $1}')
  echo "  - عدد unit files : ${unit_files}"
  echo "  - عدد الوحدات المحمّلة : ${loaded}"
  echo "    * active : ${active}"
  echo "    * failed : ${failed}"
}

list_units_simple() {
  local pattern="$1"
  systemctl list-unit-files "${pattern}" --no-legend 2>/dev/null | awk '{print $1}'
}

log "بدء إنشاء خطة DRY-RUN لتوحيد SmartFriend Suite"
{
  echo "============================================================"
  echo " SmartFriend Suite – DRY RUN Consolidation Plan"
  echo " Timestamp : $(date '+%F %T')"
  echo " Hostname  : $(hostname)"
  echo "============================================================"

  section "1) ملخص العائلات (G1 – فجوة البراند والخدمات)"
  summary_family "sf"
  summary_family "smartfriend"
  summary_family "smartfrind"

  section "2) Legacy smartfrind-* المرشّحة للتجميد (G1, G10)"
  legacy_units=$(list_units_simple "smartfrind-*")
  if [ -z "$legacy_units" ]; then
    echo "لا توجد وحدات smartfrind-* مُعرّفة."
  else
    while read -r unit; do
      [ -z "$unit" ] && continue
      enabled_state=$(systemctl list-unit-files "$unit" --no-legend 2>/dev/null | awk '{print $2}')
      active_state=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")
      echo
      echo "[$unit]"
      echo "  - enabled : ${enabled_state}"
      echo "  - active  : ${active_state}"
      echo "  - الخطة (DRY-RUN):"
      echo "      • systemctl stop ${unit}          # إيقاف تشغيل legacy"
      echo "      • systemctl disable ${unit}       # تعطيل من الإقلاع"
      echo "      • نقل ملف unit إلى: /opt/smartfriend-suite/legacy_units/ (أرشفة بدون حذف كود أو DB)"
    done <<< "$legacy_units"
  fi

  section "3) خدمات السيوت الأساسية المراد ترقيتها (G2, G3, G4, G5, G6, G8)"
  core_candidates=("sf-unified.service" "sf-core.service" "sf-memory.service" "sf-web.service" "sf-health.service" "sf-spider.service" "sf-learning.service")
  for unit in "${core_candidates[@]}"; do
    if systemctl list-unit-files "$unit" --no-legend &>/dev/null; then
      enabled_state=$(systemctl list-unit-files "$unit" --no-legend 2>/dev/null | awk '{print $2}')
      active_state=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")
      echo
      echo "[$unit]"
      echo "  - enabled : ${enabled_state}"
      echo "  - active  : ${active_state}"
      echo "  - الدور المستهدف (Target Role) – DRY-RUN:"
      case "$unit" in
        sf-unified.service)
          echo "      • Gateway / Unified API رسمي (G2)"
          echo "      • الخطة: ربطه ببورت 8210 عبر Nginx ليكون /unified/ و /ffactory/ لو مناسب."
          ;;
        sf-core.service)
          echo "      • Core API داخلي (G2)"
          echo "      • الخطة: تشغيله على 8211 (بدلاً من smartfriend-api) مع توحيد المنطق."
          ;;
        sf-memory.service)
          echo "      • Memory API (G3)"
          echo "      • الخطة: تشغيله على 8214 واستخدامه لمسار /memory/ من Nginx."
          ;;
        sf-web.service)
          echo "      • Web UI / Dashboard (G4)"
          echo "      • الخطة: تشغيل لوحة السيوت على 8390 وربطها من /dashboard/ في Nginx."
          ;;
        sf-health.service)
          echo "      • Health / Guard رسمي (G8)"
          echo "      • الخطة: دمج منطق المراقبة القديم smartfrind-guardian في هذه الخدمة فقط."
          ;;
        sf-spider.service)
          echo "      • Spider / Harvester رسمي (G6)"
          echo "      • الخطة: نقل أفضل ما في smartfrind-harvest/ingest إليه."
          ;;
        sf-learning.service)
          echo "      • Continuous Learning / Brain Loop (G5)"
          echo "      • الخطة: إصلاح loop وإعادة استخدام خبرة smartfrind-learning تحت هذا الاسم فقط."
          ;;
      esac
    fi
  done

  section "4) البوتات – توحيد الأدوار (G7)"
  echo "هدف التصميم:"
  echo "  • Bot رئيسي للمستخدم (Main Assistant Bot)"
  echo "  • Bot للمبرمج (Programmer Bot)"
  echo "  • Bot للمراجعة والتدقيق (Audit Bot)"
  echo "  • باقي البوتات: إمّا تُدمج أو تُجمّد حسب الحاجة."
  echo
  echo "Bots من عائلة sf-*:"
  sf_bots=$(systemctl list-unit-files "sf-bot*.service" --no-legend 2>/dev/null | awk '{print $1}')
  if [ -z "$sf_bots" ]; then
    echo "  • لا توجد sf-bot*.service مُعرّفة."
  else
    while read -r unit; do
      [ -z "$unit" ] && continue
      active_state=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")
      echo "  - $unit (active=${active_state})"
    done <<< "$sf_bots"
  fi

  echo
  echo "Bots من عائلة smartfrind-* (Legacy):"
  legacy_bots=$(systemctl list-unit-files "smartfrind-*bot*.service" --no-legend 2>/dev/null | awk '{print $1}')
  if [ -z "$legacy_bots" ]; then
    echo "  • لا توجد smartfrind-* bot services."
  else
    while read -r unit; do
      [ -z "$unit" ] && continue
      active_state=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")
      echo "  - $unit (active=${active_state})"
      echo "    • الخطة (DRY-RUN): systemctl stop/disable + أرشفة الـ unit بعد نقل المنطق للبوتات sf-*."
    done <<< "$legacy_bots"
  fi

  section "5) منافذ الشبكة الحرجة (G2, G3, G4)"
  if command -v ss >/dev/null 2>&1; then
    echo "ss -tulpn | grep -E '(:80|:8210|:8211|:8220|:8214|:8390)'"
    ss -tulpn 2>/dev/null | grep -E '(:80|:8210|:8211|:8220|:8214|:8390)' || echo "لا توجد منافذ مطابقة حالياً."
    echo
    echo "الخطة (DRY-RUN):"
    echo "  • ضمان أن المنافذ التالية مملوكة لـ sf-* فقط بعد التوحيد:"
    echo "      - 8210 : sf-unified (Gateway Ask)"
    echo "      - 8211 : sf-core (Core API / internal)"
    echo "      - 8220 : واجهة مساعدة موحدة (إن استخدمت)"
    echo "      - 8214 : sf-memory (Memory API)"
    echo "      - 8390 : sf-web (Dashboard)"
  else
    echo "الأمر ss غير متوفر – تخطّي فحص المنافذ."
  fi

  section "6) ملخص G1..G10 كخطة أعمال (بدون تنفيذ)"
  echo "G1 – البراند والخدمات: smartfrind-* ⇒ تجميد تدريجي، sf-* ⇒ المنصة الرسمية."
  echo "G2 – البورتات: نقل الملكية من smartfrind-gateway / smartfriend-api إلى sf-unified / sf-core."
  echo "G3 – Memory API: تشغيل sf-memory على 8214 وربطه من /memory/ في Nginx."
  echo "G4 – Web UI: تشغيل sf-web على 8390 وربطه من /dashboard/ بدون لمس ffactory."
  echo "G5 – Brain / Learning: دمج خبرة smartfrind-learning في sf-learning / sf-ingest / sf-kb-build."
  echo "G6 – Spider / Harvester: جعل sf-spider هو Spider الرسمي مع نقل المنطق القديم إليه."
  echo "G7 – Bots: حصر 3–4 بوتات رسمية من sf-* وإيقاف/أرشفة الباقي."
  echo "G8 – Health / Guard: Health/Watchdog موحّد عبر sf-health + منطق حراسة من smartfrind-guardian."
  echo "G9 – ENV / Secrets: ملف إعداد موحد للسيوت فقط (مثل /etc/smartfriend/sf_suite.env) بدون اعتماد على legacy."
  echo "G10 – Cleanup legacy units: أرشفة ملفات systemd القديمة smartfrind-* بدون حذف الكود أو قواعد البيانات."

  echo
  echo "ملحوظة: هذه الخطة DRY-RUN فقط – لا يوجد أي systemctl stop/disable أو تعديل Nginx هنا."
} | tee "$PLAN_FILE"

log "تم إنشاء ملف خطة DRY-RUN:"
log "  $PLAN_FILE"
