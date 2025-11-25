#!/usr/bin/env bash
# HyperFFactory – Challenge Stage 0 Overview
# سكربت واحد يجمع:
#  - فحص التكامل الكامل (hf_full_integration_scan.sh)
#  - فحص مصنع التحليل الجنائي/السلوكي (hf_forensics_factory_scan.sh)
# ويكتب تقرير موحّد عن "الصورة الحالية" بدون لمس أي خدمات.

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$HYPER_ROOT/reports"
OVERVIEW_REPORT="$REPORT_DIR/hf_challenge_stage0_overview_${TS}.log"

mkdir -p "$REPORT_DIR"

# دوال لوج بسيطة
log() { printf '%s %s\n' "[$(date +%Y-%m-%dT%H:%M:%S%z)]" "$*" | tee -a "$OVERVIEW_REPORT"; }

section() {
  echo | tee -a "$OVERVIEW_REPORT"
  printf '=====================================================\n' | tee -a "$OVERVIEW_REPORT"
  printf '%s\n' "$*" | tee -a "$OVERVIEW_REPORT"
  printf '=====================================================\n' | tee -a "$OVERVIEW_REPORT"
}

section "HyperFFactory – Challenge Stage 0 Overview"
log "ROOT   : $HYPER_ROOT"
log "TIME   : $TS"
log "REPORT : $OVERVIEW_REPORT"

# ----------------------------------------------------
# 1) تشغيل فحص التكامل الكامل (إن وُجد)
# ----------------------------------------------------
section "1) تشغيل hf_full_integration_scan.sh (فحص تكامل كامل)"

FULL_SCAN_SCRIPT="$HYPER_ROOT/tools/hf_full_integration_scan.sh"
FULL_SCAN_LOG=""

if [[ -x "$FULL_SCAN_SCRIPT" ]]; then
  log "تشغيل: $FULL_SCAN_SCRIPT"
  # تشغيل الفحص (لا نستخدم set -x لتقليل الضجيج)
  "$FULL_SCAN_SCRIPT" | tee -a "$OVERVIEW_REPORT" || log "تحذير: hf_full_integration_scan.sh انتهى بحالة غير صفرية (سنكمل)."
  # التقاط أحدث تقرير ناتج عنه
  FULL_SCAN_LOG="$(ls -1 "$REPORT_DIR"/hf_full_integration_scan_*.log 2>/dev/null | sort | tail -n1 || true)"
  if [[ -n "$FULL_SCAN_LOG" && -f "$FULL_SCAN_LOG" ]]; then
    log "أحدث تقرير فحص تكامل: $FULL_SCAN_LOG"
  else
    log "تحذير: لم أجد أي تقرير hf_full_integration_scan_*.log داخل $REPORT_DIR"
  fi
else
  log "تحذير: لم أجد سكربت $FULL_SCAN_SCRIPT (تخطي هذا الجزء)."
fi

# ----------------------------------------------------
# 2) تشغيل فحص مصنع التحليل الجنائي/السلوكي (إن وُجد)
# ----------------------------------------------------
section "2) تشغيل hf_forensics_factory_scan.sh (مصنع التحليل الجنائي/السلوكي)"

FORENSICS_SCRIPT="$HYPER_ROOT/tools/hf_forensics_factory_scan.sh"
FORENSICS_LOG=""

if [[ -x "$FORENSICS_SCRIPT" ]]; then
  log "تشغيل: $FORENSICS_SCRIPT"
  "$FORENSICS_SCRIPT" | tee -a "$OVERVIEW_REPORT" || log "تحذير: hf_forensics_factory_scan.sh انتهى بحالة غير صفرية (سنكمل)."
  FORENSICS_LOG="$(ls -1 "$REPORT_DIR"/hf_forensics_factory_scan_*.log 2>/dev/null | sort | tail -n1 || true)"
  if [[ -n "$FORENSICS_LOG" && -f "$FORENSICS_LOG" ]]; then
    log "أحدث تقرير للمصنع الجنائي/السلوكي: $FORENSICS_LOG"
  else
    log "تحذير: لم أجد أي تقرير hf_forensics_factory_scan_*.log داخل $REPORT_DIR"
  fi
else
  log "تحذير: لم أجد سكربت $FORENSICS_SCRIPT (تخطي هذا الجزء)."
fi

# ----------------------------------------------------
# 3) مقتطفات مختصرة من آخر تقريرَيْن (لو موجودين)
# ----------------------------------------------------
section "3) مقتطفات مختصرة من تقارير الفحص (Snapshot)"

if [[ -n "$FULL_SCAN_LOG" && -f "$FULL_SCAN_LOG" ]]; then
  log "مقتطف من: $FULL_SCAN_LOG"
  echo "---- [Integration Scan – SmartFriend & ffactory Snapshot] ----" | tee -a "$OVERVIEW_REPORT"
  # نعرض فقط الجزء الأهم: META DBs + SmartFriend + ffactory + Behavioral
  awk '
    /1\) META DBs/ {flag=1}
    /5\) جذور أنظمة أخرى/ {flag=0}
    flag {print}
  ' "$FULL_SCAN_LOG" | tee -a "$OVERVIEW_REPORT" || true
else
  log "لا يوجد تقرير تكامل لعرض مقتطف منه."
fi

if [[ -n "$FORENSICS_LOG" && -f "$FORENSICS_LOG" ]]; then
  echo | tee -a "$OVERVIEW_REPORT"
  log "مقتطف من: $FORENSICS_LOG"
  echo "---- [Forensics Factory – Identity Snapshot] ----" | tee -a "$OVERVIEW_REPORT"
  # نعرض هوية المصنع + تصنيف الخدمات
  awk '
    /1\) البحث عن جذر مصنع التحليل الجنائي\/السلوكي/ {flag=1}
    /4\) ملاحظات أولية عن الدمج/ {flag2=1}
    flag || flag2 {print}
  ' "$FORENSICS_LOG" | tee -a "$OVERVIEW_REPORT" || true
else
  log "لا يوجد تقرير فورنزكس لعرض مقتطف منه."
fi

# ----------------------------------------------------
# 4) ملخص تنفيذي صغير في آخر الملف
# ----------------------------------------------------
section "4) ملخص تنفيذي للصورة الحالية (Stage 0 Summary)"

# SmartFriend Suite status من تقرير التكامل إن وجد
if [[ -n "$FULL_SCAN_LOG" && -f "$FULL_SCAN_LOG" ]]; then
  echo "---- حالة SmartFriend Suite (من آخر فحص) ----" | tee -a "$OVERVIEW_REPORT"
  grep -A10 "2) SmartFriend Suite – Services & HTTP Health" "$FULL_SCAN_LOG" | tee -a "$OVERVIEW_REPORT" || true

  echo | tee -a "$OVERVIEW_REPORT"
  echo "---- حالة ffactory / الحاويات (من آخر فحص) ----" | tee -a "$OVERVIEW_REPORT"
  grep -A20 "3) ffactory – Docker stack & compose mapping" "$FULL_SCAN_LOG" | tee -a "$OVERVIEW_REPORT" || true
fi

# Forensics Factory root snapshot
if [[ -n "$FORENSICS_LOG" && -f "$FORENSICS_LOG" ]]; then
  echo | tee -a "$OVERVIEW_REPORT"
  echo "---- تعريف جذر مصنع التحليل الجنائي/السلوكي (من آخر فحص) ----" | tee -a "$OVERVIEW_REPORT"
  grep -A20 "1) البحث عن جذر مصنع التحليل الجنائي/السلوكي" "$FORENSICS_LOG" | tee -a "$OVERVIEW_REPORT" || true
fi

echo | tee -a "$OVERVIEW_REPORT"
log "انتهت مرحلة 0: تم تجميع الصورة الكاملة الحالية في تقرير واحد."
log "يمكنك مراجعة الملف:"
log "  $OVERVIEW_REPORT"

exit 0
