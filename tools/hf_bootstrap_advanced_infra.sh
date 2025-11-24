#!/usr/bin/env bash
# HyperFFactory – Bootstrap Advanced Infrastructure Skeleton
# يبني الهياكل الناقصة (Lakehouse / Factories / Systems) داخل /root/HyperFFactory فقط.
# لا يلمس ffactory أو smartfriend-suite خارج الشجرة.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="reports"
mkdir -p "$LOG_DIR"
LOG="${LOG_DIR}/hf_bootstrap_advanced_infra_${TS}.log"

log() {
  echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"
}

log "=================================================="
log "🚀 HF – Bootstrap Advanced Infra Skeleton"
log "ROOT: ${ROOT}"
log "LOG : ${LOG}"
log "=================================================="

# 1) Lakehouse layout
log "📂 إنشاء هيكل data_lakehouse/* (إن لم يكن موجودًا)..."

LAKE_DIRS=(
  "data_lakehouse"
  "data_lakehouse/raw_zone"
  "data_lakehouse/cleansed_zone"
  "data_lakehouse/semantic_zone"
  "data_lakehouse/serving_zone"
)

for d in "${LAKE_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    log "  [SKIP] dir موجود بالفعل: $d"
  else
    mkdir -p "$d"
    log "  [OK]   تم إنشاء dir: $d"
  fi
done

LAKE_MANIFEST="config/lakehouse_manifest.yaml"
mkdir -p config

if [[ -f "$LAKE_MANIFEST" ]]; then
  log "  [SKIP] lakehouse_manifest.yaml موجود مسبقًا: $LAKE_MANIFEST"
else
  cat > "$LAKE_MANIFEST" <<'YAML'
# HyperFFactory – Lakehouse Manifest (Skeleton)
# هذه النسخة مبدئية، للاستخدام كمرجع للبنية فقط.
version: 1
root: data_lakehouse
zones:
  raw: data_lakehouse/raw_zone
  cleansed: data_lakehouse/cleansed_zone
  semantic: data_lakehouse/semantic_zone
  serving: data_lakehouse/serving_zone
owners:
  - id: hyper_brain
  - id: hyper_guard
notes:
  - "هذا الملف مبدئي ويحتاج استكمال الحقول لاحقًا."
YAML
  log "  [OK]   تم إنشاء lakehouse_manifest.yaml (skeleton)."
fi

# 2) Factories layout
log "🏭 إنشاء هيكل factories/{model,knowledge,quality}..."

FACTORY_DIRS=(
  "factories"
  "factories/model_factory/incoming"
  "factories/model_factory/trained"
  "factories/model_factory/logs"
  "factories/knowledge_factory/incoming"
  "factories/knowledge_factory/curated"
  "factories/knowledge_factory/logs"
  "factories/quality_factory/inputs"
  "factories/quality_factory/reports"
  "factories/quality_factory/logs"
)

for d in "${FACTORY_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    log "  [SKIP] dir موجود بالفعل: $d"
  else
    mkdir -p "$d"
    log "  [OK]   تم إنشاء dir: $d"
  fi
done

for d in factories/model_factory factories/knowledge_factory factories/quality_factory; do
  README="$d/README.md"
  if [[ -f "$README" ]]; then
    log "  [SKIP] README موجود بالفعل: $README"
  else
    cat > "$README" <<EOF2
# $(basename "$d") – Skeleton

هذا المجلد يمثل مصنعًا متخصصًا داخل HyperFFactory.

- يحفظ هذا الهيكل فقط؛ المنطق التنفيذي سيتم إضافته لاحقًا.
- لا توجد أي عمليات حذف أو تعديل تلقائي هنا.
EOF2
    log "  [OK]   تم إنشاء README: $README"
  fi
done

# 3) Systems skeletons (Patterns / Quality / Temporal Memory / Integration Hub)
log "🧠 إنشاء هياكل الأنظمة المتقدمة (patterns / quality / temporal / integration)..."

SYSTEM_DIRS=(
  "patterns_system"
  "patterns_system/rules"
  "patterns_system/reports"
  "quality_system"
  "quality_system/reports"
  "temporal_memory"
  "temporal_memory/reports"
  "integration_hub"
  "integration_hub/adapters"
  "integration_hub/reports"
)

for d in "${SYSTEM_DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    log "  [SKIP] dir موجود بالفعل: $d"
  else
    mkdir -p "$d"
    log "  [OK]   تم إنشاء dir: $d"
  fi
done

# README لكل نظام
declare -A SYSTEM_README_TEXT
SYSTEM_README_TEXT["patterns_system"]=$'# Patterns System (Skeleton)\n\nهذا المجلد هو المكان الرسمي لنظام الأنماط داخل HyperFFactory.\n- يعتمد لاحقًا على db/meta/hf_patterns.db.\n- التقارير النصية تذهب إلى patterns_system/reports.\n'
SYSTEM_README_TEXT["quality_system"]=$'# Quality System (Skeleton)\n\nنظام الجودة متعدد الأنظمة.\n- يستهلك بيانات من hf_quality.db.\n- يخرج تقارير إلى quality_system/reports.\n'
SYSTEM_README_TEXT["temporal_memory"]=$'# Temporal Memory (Skeleton)\n\nنظام الذاكرة الزمنية وتطور المستخدمين/الأنظمة.\n- يربط بين الجولات/الزمن/المهام.\n'
SYSTEM_README_TEXT["integration_hub"]=$'# Integration Hub (Skeleton)\n\nنقطة تكامل رسمية مع الأنظمة الخارجية (SmartFriend / ffactory / غيرها).\n- لا يلمس الأنظمة الخارجية مباشرة؛ يعمل عبر adapters و config.\n'

for sys in patterns_system quality_system temporal_memory integration_hub; do
  README="${sys}/README.md"
  if [[ -f "$README" ]]; then
    log "  [SKIP] README موجود بالفعل: $README"
  else
    printf "%b" "${SYSTEM_README_TEXT[$sys]}" > "$README"
    log "  [OK]   تم إنشاء README: $README"
  fi
done

# 4) Agents core config (debug_expert / system_architect / technical_coach / knowledge_spider)
log "👥 إعداد ملف config/agents_hf_core.yaml (لو غير موجود)..."

AGENTS_CFG="config/agents_hf_core.yaml"
if [[ -f "$AGENTS_CFG" ]]; then
  log "  [SKIP] agents_hf_core.yaml موجود مسبقًا: $AGENTS_CFG"
else
  cat > "$AGENTS_CFG" <<'YAML'
# HyperFFactory – Core Agents Definition (Skeleton)

version: 1
scope: hyper_ffactory
agents:
  debug_expert:
    role: "debug_expert"
    description: "عامل تصحيح أخطاء المصنع وأنظمة التكامل."
    default_scripts:
      - "bin/hf_smart_debug_scan.sh"
      - "tools/hf_scan_repo_health_fix_report.sh"
    enabled: true

  system_architect:
    role: "system_architect"
    description: "مسؤول عن فجوات التصميم والبنية (design gaps)."
    default_scripts:
      - "bin/hf_check_design_gaps.sh"
      - "tools/hf_check_advanced_arch.sh"
    enabled: true

  technical_coach:
    role: "technical_coach"
    description: "مسؤول التعليم والخبرة (Training / SkillState)."
    default_scripts:
      - "bin/hf_learn_all.sh"
      - "tools/hf_scan_brain_memory_quality.sh"
    enabled: true

  knowledge_spider:
    role: "knowledge_spider"
    description: "عامل جمع المعرفة من الأنظمة الخارجية/المصادر."
    default_scripts:
      - "scripts/spiders/sf_spider_run.sh"
      - "scripts/spiders/sf_simple_spider_test.sh"
    enabled: true

notes:
  - "هذا الملف Skeleton؛ يمكن تعديل المسارات اعتمادًا على السكربتات الموجودة فعليًا."
YAML
  log "  [OK]   تم إنشاء agents_hf_core.yaml (skeleton)."
fi

# 5) Integration config skeleton مع SmartFriend Suite (كهدف تكامل خارجي فقط)
log "🔗 إعداد config/integration_smartfriend.yaml (لو غير موجود)..."

INTEG_CFG="config/integration_smartfriend.yaml"
if [[ -f "$INTEG_CFG" ]]; then
  log "  [SKIP] integration_smartfriend.yaml موجود مسبقًا: $INTEG_CFG"
else
  cat > "$INTEG_CFG" <<'YAML'
# HyperFFactory – SmartFriend Suite Integration (Skeleton)
# هذا الملف لا يفعّل أي شيء بمفرده؛ فقط يعرّف نقاط التكامل المتفق عليها.

version: 1
external_system: "smartfriend_suite"

paths:
  root: "/opt/smartfriend-suite"
  db_main: "/opt/smartfriend-suite/var/db/smartfriend_unified.db"
  reports_dir: "/opt/smartfriend-suite/reports"

health:
  service_matrix_csv_glob: "sf_service_matrix_*.csv"
  audit_reports_glob: "audit_*.json"

policies:
  touch_files: false          # لا تعديل على ملفات smartfriend من HyperFFactory
  touch_services: false       # لا إدارة systemd للوحدات sf-* من هذا المستوى
  role: "observer"            # HyperFFactory يعمل كمراقب/محلل فقط هنا

notes:
  - "يتم استهلاك هذه الإعدادات من سكربتات health/integration فقط."
YAML
  log "  [OK]   تم إنشاء integration_smartfriend.yaml (skeleton)."
fi

log "✅ Bootstrap مكتمل. راجع التقرير: $LOG"
