#!/usr/bin/env bash
# HyperFFactory – Challenge Stage 1
# تسجيل هوية "مصنع التحليل الجنائي/السلوكي" رسميًا داخل HyperFFactory
# بدون تشغيل أي خدمات؛ فقط تعريف / فحص / طباعة بطاقة هوية.

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_challenge_stage1_register_forensics_factory_${TS}.log"

mkdir -p "$REPORT_DIR"

log() { printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$REPORT"; }

section() {
  echo | tee -a "$REPORT"
  printf '=====================================================\n' | tee -a "$REPORT"
  printf '%s\n' "$*" | tee -a "$REPORT"
  printf '=====================================================\n' | tee -a "$REPORT"
}

section "HyperFFactory – Challenge Stage 1: Register Forensics/Behavior Factory"
log "ROOT   : $HYPER_ROOT"
log "TIME   : $TS"
log "REPORT : $REPORT"

# ----------------------------------------------------
# 1) الحصول على FACTORY_ROOT من آخر فحص forensics
# ----------------------------------------------------
section "1) استنتاج FACTORY_ROOT من تقارير hf_forensics_factory_scan"

FORENSICS_LOG="$(ls -1 "$REPORT_DIR"/hf_forensics_factory_scan_*.log 2>/dev/null | sort | tail -n1 || true)"
FACTORY_ROOT=""

if [[ -n "$FORENSICS_LOG" && -f "$FORENSICS_LOG" ]]; then
  log "استخدام أحدث تقرير: $FORENSICS_LOG"
  FACTORY_ROOT="$(grep 'الافتراض الأولي لجذر المصنع' "$FORENSICS_LOG" | awk -F': ' '{print $2}' | tail -n1 || true)"
  if [[ -z "$FACTORY_ROOT" ]]; then
    log "تحذير: لم أستطع استخراج FACTORY_ROOT من التقرير. يمكنك تشغيل hf_forensics_factory_scan.sh يدويًا."
  else
    log "FACTORY_ROOT (من التقرير): $FACTORY_ROOT"
  fi
else
  log "تحذير: لا يوجد أي تقرير hf_forensics_factory_scan_*.log في $REPORT_DIR"
  log "يمكنك تشغيل: tools/hf_forensics_factory_scan.sh ثم إعادة هذا السكربت."
fi

if [[ -n "$FACTORY_ROOT" ]]; then
  if [[ -d "$FACTORY_ROOT" ]]; then
    log "تم تأكيد وجود المسار فعليًا على السيرفر."
  else
    log "تحذير: FACTORY_ROOT موجود في التقرير لكنه غير موجود كمجلد فعليًا!"
  fi
fi

# ----------------------------------------------------
# 2) فحص/إنشاء config/forensics_factory_manifest.yaml
# ----------------------------------------------------
section "2) فحص/إنشاء forensics_factory_manifest.yaml"

MANIFEST_FILE="$HYPER_ROOT/config/forensics_factory_manifest.yaml"

if [[ -f "$MANIFEST_FILE" ]]; then
  log "تم العثور على manifest موجود مسبقًا: $MANIFEST_FILE"
  log "نطبع أول 60 سطر منه كمرجع هوية:"
  echo "-----------------------------------------------------" | tee -a "$REPORT"
  sed -n '1,60p' "$MANIFEST_FILE" | tee -a "$REPORT" || true
  echo "-----------------------------------------------------" | tee -a "$REPORT"
else
  if [[ -z "$FACTORY_ROOT" ]]; then
    log "لا أستطيع توليد manifest جديد لأن FACTORY_ROOT غير معروف."
  else
    log "لم أجد manifest؛ سيتم إنشاء ملف جديد بالحد الأدنى من تعريف الهوية."
    cat > "$MANIFEST_FILE" <<EOF_MAN
name: "Forensics & Behavioral Intelligence Factory"
description: >
  مصنع التحليل الجنائي والسلوكي، يحتوي على محركات التحليل، الأدلة،
  الذكاء الاجتماعي، ومحركات الـ AI المساعدة (ASR / Neural Core).

root: "${FACTORY_ROOT}"

groups:
  forensics:
    - advanced-forensics
    - media-forensics-pro

  behavioral:
    - behavioral-analytics
    - behavior-analytics
    - behavioral-patterns
    - social-intelligence

  ai_engines:
    - asr-engine
    - neural-core
    - vision-engine
    - ocr-engine
    - media-forensics
    - media-forensics-pro

  dashboards_apis:
    - quantum-security
    - ai-reporting
    - api-gateway

notes:
  - "تعامل HyperFFactory مع هذا المصنع ككيان مستقل للقدرات الجنائية/السلوكية."
  - "SmartFriend يتكامل معه عبر البوتات وواجهات الـ API فقط."
  - "لا يتم نقل أو إعادة تسمية الخدمات القديمة؛ فقط يتم ربطها بالهوية الجديدة."

EOF_MAN
    log "تم إنشاء manifest جديد: $MANIFEST_FILE"
  fi
fi

# ----------------------------------------------------
# 3) استخراج بطاقة هوية من identity_roles.yaml
# ----------------------------------------------------
section "3) بطاقة هوية Behavioral Forensic Engine + Behavior Bot من identity_roles.yaml"

IDENTITY_FILE="$HYPER_ROOT/config/identity_roles.yaml"

if [[ -f "$IDENTITY_FILE" ]]; then
  log "استخدام: $IDENTITY_FILE"

  echo "---- مقتطف: تعريف behavioral_forensic_engine ----" | tee -a "$REPORT"
  awk '
    /behavioral_forensic_engine:/ {flag=1}
    /^ *[a-zA-Z0-9_-]+:/ && $1 !~ /behavioral_forensic_engine:/ && flag==1 {flag=0}
    flag {print}
  ' "$IDENTITY_FILE" | tee -a "$REPORT" || true

  echo | tee -a "$REPORT"
  echo "---- مقتطف: تعريف behavior_bot + Behavior & Forensic Bot ----" | tee -a "$REPORT"
  awk '
    /behavior_bot:/ {flag=1}
    /^ *[a-zA-Z0-9_-]+:/ && $1 !~ /behavior_bot:/ && flag==1 {flag=0}
    flag {print}
  ' "$IDENTITY_FILE" | tee -a "$REPORT" || true

  echo | tee -a "$REPORT"
  echo "---- مقتطف: bots_roles_matrix (للتأكد من وجود Behavior & Forensic Bot) ----" | tee -a "$REPORT"
  awk '
    /bots_roles_matrix:/ {flag=1}
    /^integration_matrix:/ && flag==1 {flag=0}
    flag {print}
  ' "$IDENTITY_FILE" | tee -a "$REPORT" || true

else
  log "تحذير: لم أجد $IDENTITY_FILE – لا يمكن استخراج الهوية من identity_roles.yaml"
fi

# ----------------------------------------------------
# 4) ملخص تنفيذي: هل المصنع مُسجّل وهوّيّته محفوظة؟
# ----------------------------------------------------
section "4) ملخص تنفيذي (Stage 1 Registration Summary)"

if [[ -n "$FACTORY_ROOT" && -d "$FACTORY_ROOT" ]]; then
  log "FACTORY_ROOT مسجّل وموجود: $FACTORY_ROOT"
else
  log "FACTORY_ROOT غير مؤكد بالكامل – راجع التقارير السابقة أو شغّل hf_forensics_factory_scan.sh."
fi

if [[ -f "$MANIFEST_FILE" ]]; then
  log "forensics_factory_manifest.yaml موجود الآن ويصف المصنع ككيان مستقل."
else
  log "تحذير: manifest غير موجود – الخطوة القادمة هي إنشاءه يدويًا أو إصلاح هذا السكربت."
fi

if [[ -f "$IDENTITY_FILE" ]]; then
  log "identity_roles.yaml يحتوي على تعريفات behavioral_forensic_engine / behavior_bot (مقتطفاتها أعلاه)."
else
  log "identity_roles.yaml مفقود – يجب إصلاح هوية النظام قبل تشغيل المصنع."
fi

echo | tee -a "$REPORT"
log "انتهت Stage 1: تسجيل/تثبيت الهوية المنطقية للمصنع الجنائي/السلوكي داخل HyperFFactory."
log "لم يتم تشغيل أي خدمة؛ فقط تعريف وفحص هوية."

exit 0
