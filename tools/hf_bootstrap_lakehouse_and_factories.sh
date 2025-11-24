#!/usr/bin/env bash
# HyperFFactory – Bootstrap Lakehouse & Factories Skeleton
# يبني هيكل data_lakehouse/ و factories/ + manifest مبدئي بدون لمس أي قواعد بيانات.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_DIR="$ROOT/reports"
LOG="$LOG_DIR/hf_bootstrap_lakehouse_and_factories_${TS}.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d_%H:%M:%S')] $*" | tee -a "$LOG"
}

log "=================================================="
log "🧩 HyperFFactory – Bootstrap Lakehouse & Factories"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "=================================================="

# ---------------------------------------------------------------------------
# 1) Lakehouse skeleton
#    data_lakehouse/{raw_zone,cleansed_zone,semantic_zone,serving_zone}
# ---------------------------------------------------------------------------
LAKE_DIR="$ROOT/data_lakehouse"

declare -a LAKE_SUBDIRS=(
  "raw_zone"
  "cleansed_zone"
  "semantic_zone"
  "serving_zone"
)

for sub in "${LAKE_SUBDIRS[@]}"; do
  dir="$LAKE_DIR/$sub"
  if [[ -d "$dir" ]]; then
    log "ℹ️ Lakehouse subdir موجود مسبقاً: $dir"
  else
    mkdir -p "$dir"
    log "✅ إنشاء Lakehouse subdir: $dir"
  fi
done

# ---------------------------------------------------------------------------
# 2) Factories skeleton
#    factories/model_factory/{incoming,trained,logs}
#    factories/knowledge_factory/{incoming,curated}
#    factories/quality_factory/{inputs,reports}
# ---------------------------------------------------------------------------
FACT_ROOT="$ROOT/factories"

declare -a FACT_SUBDIRS=(
  "model_factory/incoming"
  "model_factory/trained"
  "model_factory/logs"
  "knowledge_factory/incoming"
  "knowledge_factory/curated"
  "quality_factory/inputs"
  "quality_factory/reports"
)

for sub in "${FACT_SUBDIRS[@]}"; do
  dir="$FACT_ROOT/$sub"
  if [[ -d "$dir" ]]; then
    log "ℹ️ Factory subdir موجود مسبقاً: $dir"
  else
    mkdir -p "$dir"
    log "✅ إنشاء Factory subdir: $dir"
  fi
done

# ---------------------------------------------------------------------------
# 3) Lakehouse manifest (config/lakehouse_manifest.yaml)
#    - لو الملف موجود: نكتفي برسالة ولا نلمسه.
#    - لو غير موجود: ننشئ نسخة مبدئية بسيطة.
# ---------------------------------------------------------------------------
CONFIG_DIR="$ROOT/config"
MANIFEST="$CONFIG_DIR/lakehouse_manifest.yaml"

mkdir -p "$CONFIG_DIR"

if [[ -f "$MANIFEST" ]]; then
  log "ℹ️ ملف lakehouse_manifest.yaml موجود مسبقاً – لن يتم تعديله: $MANIFEST"
else
  cat > "$MANIFEST" <<'YAML'
# HyperFFactory – Lakehouse Manifest (Skeleton)
# هذه النسخة مبدئية فقط لتثبيت الهيكل.
# لاحقاً يمكن توسيعها بالمصانع والجداول وحالات الجودة والتدريب.

lakehouse:
  root: data_lakehouse

  zones:
    raw_zone:
      path: data_lakehouse/raw_zone
      description: "منطقة الإدخال الخام من الأنظمة المختلفة"
    cleansed_zone:
      path: data_lakehouse/cleansed_zone
      description: "بيانات منقّاة وموحّدة جاهزة للتحليل"
    semantic_zone:
      path: data_lakehouse/semantic_zone
      description: "تمثيلات دلالية (Features, Embeddings, Patterns)"
    serving_zone:
      path: data_lakehouse/serving_zone
      description: "مخرجات نهائية جاهزة للاستهلاك (Dashboards / APIs)"

factories:
  model_factory:
    root: factories/model_factory
    inputs: factories/model_factory/incoming
    outputs: factories/model_factory/trained
    logs: factories/model_factory/logs

  knowledge_factory:
    root: factories/knowledge_factory
    inputs: factories/knowledge_factory/incoming
    outputs: factories/knowledge_factory/curated

  quality_factory:
    root: factories/quality_factory
    inputs: factories/quality_factory/inputs
    outputs: factories/quality_factory/reports
YAML
  log "✅ إنشاء ملف manifest مبدئي: $MANIFEST"
fi

log "=================================================="
log "✅ Bootstrap مكتمل بدون أخطاء."
log "📁 Lakehouse root : $LAKE_DIR"
log "📁 Factories root : $FACT_ROOT"
log "📄 Manifest       : $MANIFEST"
log "=================================================="

echo "✅ تم تنفيذ hf_bootstrap_lakehouse_and_factories بنجاح."
echo "🔎 راجع التقرير: $LOG"
