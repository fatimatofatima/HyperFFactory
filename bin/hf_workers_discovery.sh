#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
# HyperFFactory – اكتشاف ملفات العمال (Workers) في الريبو
# ---------------------------------------------------------

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"
LOG_FILE="$REPORT_DIR/hf_workers_discovery_$(date +%Y%m%d_%H%M%S).log"

log() {
  echo "[$(date +%F_%T)] $*" | tee -a "$LOG_FILE"
}

log "============================================================"
log "🧩 HyperFFactory – اكتشاف ملفات العمال (Workers) في الريبو"
log "ROOT: $ROOT"
log "============================================================"

# 1) سكربتات hyper_* المرتبطة بالعمال/المهام
log "---- سكربتات hyper_* الخاصة بالعمال/المهام ----"

root_scripts=(
  "hyper_init_workers_tables.sh"
  "hyper_seed_workers_from_services.sh"
  "hyper_seed_runtime_from_legacy.sh"
  "hyper_seed_tasks_basics.sh"
  "hyper_init_brain_and_knowledge.sh"
  "hyper_init_brain_and_knowledge_v2.sh"
)

for f in "${root_scripts[@]}"; do
  if [[ -f "$ROOT/$f" ]]; then
    log "🟢 $f"
    # نعرض الهيدر لتعريف السكربت (أول 60 سطر تقريبًا)
    {
      echo "    ───── بداية معاينة الكود ($f) ─────"
      sed -n '1,60p' "$ROOT/$f" | sed 's/^/    | /'
      echo "    ───── نهاية المعاينة ─────"
    } >> "$LOG_FILE"
  else
    log "⚪ $f غير موجود في $ROOT"
  fi
done

# 2) البحث في config/* عن تعريفات workers
log "---- البحث في ملفات config عن workers ----"
if [[ -d "$ROOT/config" ]]; then
  find "$ROOT/config" -maxdepth 2 -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' \) 2>/dev/null \
    | sort | while read -r cfg; do
        if grep -qiE 'worker|workers' "$cfg"; then
          rel="$(realpath --relative-to="$ROOT" "$cfg")"
          log "📄 $rel:"
          grep -niE 'worker|workers' "$cfg" | sed 's/^/    | /' >> "$LOG_FILE" || true
        fi
      done
else
  log "⚪ مجلد config غير موجود"
fi

# 3) مسح scripts/agents و scripts/services عن أي سكربت يذكر workers
log "---- مسح scripts/agents و scripts/services ----"

for d in "$ROOT/scripts/agents" "$ROOT/scripts/services"; do
  if [[ -d "$d" ]]; then
    rel_d="$(realpath --relative-to="$ROOT" "$d")"
    log "📂 $rel_d:"
    find "$d" -maxdepth 3 -type f \( -name '*.sh' -o -name '*.py' -o -name '*.yaml' -o -name '*.yml' \) \
      ! -path '*collected_scripts_from_opt*' 2>/dev/null \
      | sort | while read -r f; do
          if grep -qiE 'worker|workers' "$f"; then
            rel_f="$(realpath --relative-to="$ROOT" "$f")"
            log "   • $rel_f"
          fi
        done
  else
    log "⚪ المجلد غير موجود: $d"
  fi
done

log "============================================================"
log "✅ اكتشاف العمال في الريبو انتهى – التقرير: $LOG_FILE"
