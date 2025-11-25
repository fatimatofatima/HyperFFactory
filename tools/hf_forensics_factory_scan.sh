#!/usr/bin/env bash
# HyperFFactory – Forensics & Behavioral Factory Scan
# يبحث عن مصنع التحليل الجنائي/السلوكي ويطلع تقرير هوية عنه

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_forensics_factory_scan_${TS}.log"

mkdir -p "$REPORT_DIR"

# ألوان بسيطة
RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
RESET="$(printf '\033[0m')"

log()  { printf '%s\n' "$*" | tee -a "$REPORT"; }
section() {
  echo >> "$REPORT"
  printf '=====================================================\n' | tee -a "$REPORT"
  printf '%s\n' "$*" | tee -a "$REPORT"
  printf '=====================================================\n' | tee -a "$REPORT"
}

echo "====================================================="
echo "HyperFFactory – Forensics & Behavioral Factory Scan"
echo "ROOT   : $HYPER_ROOT"
echo "TIME   : $TS"
echo "REPORT : $REPORT"
echo "====================================================="

section "1) البحث عن جذر مصنع التحليل الجنائي/السلوكي"

# نحاول اكتشاف الجذر بالاعتماد على فولدرات مميزة ظهرت في الصور
CANDIDATE_DIRS=()
while IFS= read -r path; do
  CANDIDATE_DIRS+=("$path")
done < <(
  find /root /opt -maxdepth 5 -type d \
    \( -name "behavior-analytics" -o -name "behavioral-analytics" -o -name "behavioral-patterns" \
       -o -name "temporal-forensics" -o -name "media-forensics" -o -name "ocr-engine" \
       -o -name "vision-engine" -o -name "asr-engine" -o -name "api-gateway" \
       -o -name "telegram-bots" \) 2>/dev/null
)

if [[ ${#CANDIDATE_DIRS[@]} -eq 0 ]]; then
  log "لم أجد أي فولدرات match للأسماء (behavior-analytics / temporal-forensics / media-forensics / ocr-engine / vision-engine / api-gateway / telegram-bots) تحت /root أو /opt."
  log "تحقق يدويًا من مسار الريبو ثم أعد التشغيل بعد تحديث السكربت."
  exit 0
fi

log "الفولدرات المطابقة المكتشفة:"
for d in "${CANDIDATE_DIRS[@]}"; do
  log "  - $d"
done

# نفترض أن الجذر هو parent الأعلى (الذي يحتوي على كل هذه الخدمات كفولدورات مباشرة تحته)
# نأخذ أول match ونصعد مستوى واحد
FACTORY_ROOT="$(dirname "${CANDIDATE_DIRS[0]}")"
log ""
log "الافتراض الأولي لجذر المصنع: $FACTORY_ROOT"

if [[ ! -d "$FACTORY_ROOT" ]]; then
  log "❌ الجذر المفترض غير موجود كفولدر! تحقق يدويًا."
  exit 1
fi

section "2) نظرة عامة على محتوى المصنع (Top-level services)"

log "محتوى $FACTORY_ROOT:"
ls -1 "$FACTORY_ROOT" | sed 's/^/  - /' | tee -a "$REPORT"

section "3) تصنيف الخدمات حسب الهوية الوظيفية"

# دالة مساعدة لطباعة قائمة لو وجدت
print_group() {
  local title="$1"; shift
  local -a names=("$@")
  log ""
  log "---- $title ----"
  local found_any=0
  for name in "${names[@]}"; do
    if [[ -d "$FACTORY_ROOT/$name" ]]; then
      printf "  %b[FOUND]%b %s\n" "$GREEN" "$RESET" "$name" | tee -a "$REPORT"
      found_any=1
    fi
  done
  if [[ $found_any -eq 0 ]]; then
    printf "  %b[NONE]%b لا توجد خدمات مطابقة في هذه الفئة.\n" "$YELLOW" "$RESET" | tee -a "$REPORT"
  fi
}

# 3.1) خدمات Forensics / Evidence
print_group "Forensics / Evidence" \
  "advanced-forensics" \
  "cloud-forensics" \
  "mobile-forensics" \
  "memory-forensics" \
  "media-forensics" \
  "media-forensics-pro" \
  "media-analyzer" \
  "video-prober" \
  "video-metadata" \
  "iot-forensics" \
  "temporal-forensics" \
  "digital-archiver" \
  "blockchain-analyzer" \
  "chain-of-custody-manager" \
  "chain-custody-verifier" \
  "case-manager" \
  "evidence-tracker" \
  "evidence-uploader" \
  "investigation-api" \
  "hashset-service"

# 3.2) Behavioral / Social / Risk / Threat
print_group "Behavioral / Social / Risk / Threat" \
  "behavior-analytics" \
  "behavioral-analytics" \
  "behavioral-patterns" \
  "criminal-profiler" \
  "relationship-intel" \
  "relationship-risk" \
  "social-analyzer" \
  "social-intelligence" \
  "social-correlator" \
  "social-linker" \
  "threat-intelligence" \
  "risk-analyzer" \
  "predictive-analytics" \
  "triage" \
  "status-unifier"

# 3.3) Core AI Engines (Vision / NLP / Audio / Embeddings)
print_group "AI Engines (Vision / NLP / Audio / Embeddings)" \
  "ocr-engine" \
  "vision-engine" \
  "face-engine" \
  "asr-engine" \
  "nlp" \
  "language-processor" \
  "neural-core" \
  "embed-search" \
  "deepfake-detector" \
  "video-metadata"

# 3.4) Orchestration / Dashboards / APIs
print_group "Orchestration / Dashboards / APIs" \
  "api-gateway" \
  "orchestrator" \
  "frontend-dashboard" \
  "real-time-dashboard" \
  "report-generator" \
  "alert-manager" \
  "error-aggregator" \
  "backup-manager" \
  "external-integration" \
  "data-export-service" \
  "integrity-monitor" \
  "graph-writer" \
  "geospatial-tracker" \
  "quantum-security"

# 3.5) Ingest / Workers / Gateways
print_group "Ingest / Workers / Gateways" \
  "ingest-gateway" \
  "ingest-service" \
  "ingest-worker" \
  "investigation-api" \
  "external-integration"

# 3.6) Telegram Bots / Interaction
print_group "Telegram / Bots" \
  "telegram-bots" \
  "bot-admin" \
  "bot-nextwin"

section "4) ملاحظات أولية عن الدمج مع HyperFFactory / SmartFriend"

log "1) FACTORY_ROOT = $FACTORY_ROOT سيتم اعتباره 'مصنع التحليل الجنائي/السلوكي' داخل HyperFFactory."
log "2) يمكن لاحقًا إنشاء manifest مثل: config/forensics_factory_manifest.yaml داخل HyperFFactory يصف:"
log "   - root: $FACTORY_ROOT"
log "   - مجموعات الخدمات (Forensics / Behavioral / AI Engines / Dashboards / Bots)."
log "3) HyperFFactory سيتعامل معه كـ Factory مستقل؛ SmartFriend سيتكامل معه عبر البوتات وواجهات الـ API فقط."
log "4) لا يتم نقل أو إعادة تسمية الخدمات الحالية؛ فقط نعرّفها في الهرم الأعلى ونربطها بمصفوفة الأدوار والبيانات."

echo
echo "====================================================="
echo "تم الانتهاء من فحص مصنع التحليل الجنائي/السلوكي."
echo "تقرير مفصل محفوظ في:"
echo "  $REPORT"
echo "====================================================="
