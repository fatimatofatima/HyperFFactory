#!/usr/bin/env bash
# HyperFFactory – Seed "gaps" as formal Tasks (excluding ffactory)
# يحوّل قائمة النواقص إلى مهام في hf_tasks.db بدون لمس ffactory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HF_TASKS_ADMIN="$ROOT_DIR/bin/hf_tasks_admin.sh"
HF_COMMON="$ROOT_DIR/bin/hf_common.sh"

if [[ ! -x "$HF_TASKS_ADMIN" ]]; then
  echo "❌ hf_tasks_admin.sh غير موجود أو غير قابل للتنفيذ: $HF_TASKS_ADMIN" >&2
  exit 1
fi

if [[ ! -f "$HF_COMMON" ]]; then
  echo "❌ hf_common.sh غير موجود: $HF_COMMON" >&2
  exit 1
fi

# نحصل على HF_TASKS_DB من hf_common.sh
# shellcheck source=/dev/null
source "$HF_COMMON"

if [[ -z "${HF_TASKS_DB:-}" ]]; then
  echo "❌ HF_TASKS_DB غير معرّف داخل hf_common.sh" >&2
  exit 1
fi

if [[ ! -f "$HF_TASKS_DB" ]]; then
  echo "❌ قاعدة المهام غير موجودة: $HF_TASKS_DB" >&2
  exit 1
fi

echo "====================================================="
echo " HyperFFactory – Seed Gaps as Tasks (no ffactory)"
echo " ROOT : $ROOT_DIR"
echo " DB   : $HF_TASKS_DB"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "====================================================="

create_if_missing() {
  local actor="$1"
  local scope="$2"
  local title="$3"
  local priority="$4"
  local tags="$5"

  # نتأكّد ما فيش مهمة بنفس (actor,scope) في جدول tasks الرسمي
  local count
  count="$(sqlite3 "$HF_TASKS_DB" "SELECT COUNT(*) FROM tasks WHERE actor = '$actor' AND scope = '$scope';")"

  if [[ "$count" -eq 0 ]]; then
    echo "➕ Creating task: actor=$actor scope=$scope priority=$priority"
    "$HF_TASKS_ADMIN" create "$actor" "$title" "$scope" "$priority" "$tags"
  else
    echo "↷ Skipping existing task: actor=$actor scope=$scope (count=$count)"
  fi
}

echo "📌 ملاحظة: هذا السكربت يتجنب أي مهام تخص ffactory عمداً."

# 2) غياب سكربتات snapshot الرسمية (status / KPI)
create_if_missing \
  "hyper_guard" \
  "meta:status_snapshot" \
  "إنشاء وتفعيل سكربت hf_status_snapshot.sh لأخذ لقطة حالة HyperFFactory" \
  70 \
  "[meta,status,snapshot]"

create_if_missing \
  "hyper_guard" \
  "meta:kpi_snapshot" \
  "إنشاء وتفعيل سكربت hf_kpi_snapshot.sh لتجميع KPIs من meta DBs" \
  70 \
  "[meta,kpi,snapshot]"

# 3) hf_db_manager – توسيع المسؤوليات (بدون لمس ffactory)
create_if_missing \
  "hf_db_manager" \
  "db_manager:scan_meta_dbs" \
  "بناء روتين scan_meta_dbs لفحص كل قواعد meta (tasks/errors/quality/actors)" \
  65 \
  "[db,meta,hf_db_manager]"

create_if_missing \
  "hf_db_manager" \
  "db_manager:check_integrity_all" \
  "تصميم وتنفيذ فحص كامل لسلامة جداول meta (PRAGMA integrity_check)" \
  80 \
  "[db,integrity,meta]"

create_if_missing \
  "hf_db_manager" \
  "db_manager:registry_rebuild" \
  "إعادة بناء registry للسكربتات والأنظمة داخل HyperFFactory فقط" \
  75 \
  "[db,registry,meta]"

# 4) mismatch بين runners و tools (script not found)
create_if_missing \
  "hyper_guard" \
  "meta:runners_tools_alignment" \
  "مراجعة استدعاءات المراحل/runners ومقارنتها بمحتوى tools/ وحل SCRIPT_NOT_FOUND" \
  85 \
  "[meta,runners,tools,guard]"

# 5) تعريف workers كـ systems/actors رسميين
create_if_missing \
  "hyper_systems_architect" \
  "workers:registry_define" \
  "تعريف كل workers في systems_registry + ربطهم بمهام hf_tasks.db" \
  80 \
  "[workers,systems,registry]"

# 6) حزمة تشغيل للتعلّم / RAG داخل HyperFFactory
create_if_missing \
  "hyper_learning_manager" \
  "learning:rag_system_define" \
  "تعريف أنظمة التعلّم/RAG في systems_registry + تصميم دورة تشغيل رسمية" \
  85 \
  "[learning,rag,meta]"

create_if_missing \
  "hyper_learning_manager" \
  "learning:rag_tasks_seed" \
  "زرع مهام دورية لتشغيل حلقات التعلم/RAG داخل HyperFFactory" \
  70 \
  "[learning,rag,tasks]"

# 7) Agents المتقدّمة
create_if_missing \
  "hyper_agents_manager" \
  "agents:advanced_register" \
  "تسجيل debug_expert/system_architect/technical_coach/knowledge_spider في meta systems" \
  75 \
  "[agents,meta,registry]"

create_if_missing \
  "hyper_agents_manager" \
  "agents:advanced_tasks" \
  "إنشاء مهام تشغيلية لكل Agent متقدّم وربطها بخط الإنتاج" \
  70 \
  "[agents,tasks]"

# 8) lakehouse + factories (بدون model-serving مرتبط بـ ffactory)
create_if_missing \
  "hyper_data_factory_manager" \
  "lakehouse:init_pipeline" \
  "إنشاء شجرة data_lakehouse (raw/cleansed/semantic/serving) وربطها بعُمّال HyperFFactory" \
  80 \
  "[data,lakehouse,factories]"

create_if_missing \
  "hyper_data_factory_manager" \
  "lakehouse:factories_bind" \
  "ربط factories/ (models/knowledge/quality) بمراحل lakehouse داخل HyperFFactory" \
  75 \
  "[data,factories,meta]"

# 9) واجهات HyperFFactory (Web / Telegram – فوق meta DBs فقط)
create_if_missing \
  "hyper_interfaces_manager" \
  "interfaces:web:dashboard_impl" \
  "تنفيذ Web Dashboard للـ meta DBs (tasks/quality/errors/experience) للقراءة فقط" \
  85 \
  "[interfaces,web,dashboard]"

create_if_missing \
  "hyper_interfaces_manager" \
  "interfaces:telegram:dashboard_impl" \
  "تنفيذ واجهة Telegram لعرض حالة HyperFFactory meta (tasks/incidents/experience)" \
  80 \
  "[interfaces,telegram,dashboard]"

# 10) إعادة تصنيف الأنظمة داخل registry
create_if_missing \
  "hyper_meta_manager" \
  "meta:taxonomy_classification" \
  "تصميم وتصنيف الأنظمة إلى فئات (workers/learning/ai/governance/devops/external_integration...)" \
  75 \
  "[meta,taxonomy,registry]"

# 11) ازدواجية جدول المهام (hf_tasks vs tasks)
create_if_missing \
  "hyper_meta_manager" \
  "meta:tasks_table_unify" \
  "حسم الجدول الرسمي للمهام (tasks vs hf_tasks) ووضع سياسة legacy/archiving" \
  90 \
  "[meta,tasks,governance]"

# 12) feedback loop من Quality/Errors → Tasks
create_if_missing \
  "hyper_meta_manager" \
  "meta:feedback_from_quality_errors" \
  "تصميم وتنفيذ hf_tasks_feedback_from_quality_and_errors.sh لتوليد مهام من الجودة/الحوادث" \
  85 \
  "[meta,quality,errors,tasks]"

# 13) تعريف Meta Controller / Control Cycle
create_if_missing \
  "hyper_meta_manager" \
  "meta:controller_define" \
  "تعريف hyper_meta_manager + meta control cycle لقراءة Tasks/Quality/Errors/Experience" \
  80 \
  "[meta,controller,cycle]"

echo "====================================================="
echo "✅ Seed gaps → tasks انتهى (بدون لمس ffactory)."
echo "====================================================="
