#!/usr/bin/env bash
# HyperFFactory - Workers Audit (Config vs Runtime)
# - يفحص تكامل "العمال" (workers/agents) بين:
#   * تعريفات الـ AI Agents في config/agents*.yaml (مثل agents_hf_core.yaml)
#   * برومبتات AI (ai/agent_*.md) لو موجودة
#   * قواعد البيانات:
#       - hf_quality.db   (quality_checks.actor)
#       - hf_errors.db    (errors.actor)
#       - hf_tasks.db     (tasks.actor)
#       - hf_learning.db  (learning.source)
# - قراءة فقط، بدون أي تعديل على البيانات
# - يسجّل التقدّم في hf_changes.db عبر hf_progress_log.sh لو موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB_DIR="$ROOT_DIR/db/meta"
REPORTS_DIR="$ROOT_DIR/reports"

HF_CHANGES_DB="$DB_DIR/hf_changes.db"
PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

HF_QUALITY_DB="$DB_DIR/hf_quality.db"
HF_ERRORS_DB="$DB_DIR/hf_errors.db"
HF_TASKS_DB="$DB_DIR/hf_tasks.db"
HF_LEARNING_DB="$DB_DIR/hf_learning.db"

mkdir -p "$REPORTS_DIR"

log_progress() {
  local context="$1"
  local detail="${2:-INFO}"
  if [[ -x "$PROGRESS_LOG" ]]; then
    "$PROGRESS_LOG" "hf_workers_audit" "$context" "$detail" >/dev/null 2>&1 || true
  fi
}

echo "=================================================="
echo "🔍 HyperFFactory – Workers Audit (Config vs Runtime)"
echo "📍 Root : $ROOT_DIR"
echo "=================================================="

log_progress "workers_audit_start" "START"
log_progress "INFO" "workers_audit_running"

#######################################
# 1) قراءة العمال من ملفات config/agents*.yaml
#######################################

CONFIG_AGENTS=()

if compgen -G "$ROOT_DIR/config/agents*.yaml" >/dev/null 2>&1; then
  while IFS= read -r file; do
    # نستخرج الأسطر التي تحتوي على "- id:" ونأخذ القيمة
    while IFS= read -r line; do
      id="$(echo "$line" | awk -F'id:' '{gsub(/ /, "", $2); print $2}')"
      if [[ -n "$id" ]]; then
        CONFIG_AGENTS+=("$id")
      fi
    done < <(grep -E '^[[:space:]]*- id:' "$file" || true)
  done < <(ls "$ROOT_DIR"/config/agents*.yaml 2>/dev/null)
fi

# إزالة التكرارات
if [[ ${#CONFIG_AGENTS[@]} -gt 0 ]]; then
  mapfile -t CONFIG_AGENTS < <(printf '%s\n' "${CONFIG_AGENTS[@]}" | sort -u)
fi

#######################################
# 2) قراءة العمال من برومبتات ai/agent_*.md (اختياري)
#######################################

PROMPT_AGENTS=()

if [[ -d "$ROOT_DIR/ai" ]]; then
  if compgen -G "$ROOT_DIR/ai/agent_*.md" >/dev/null 2>&1; then
    while IFS= read -r file; do
      base="$(basename "$file")"               # agent_foo.md
      name="${base#agent_}"                    # foo.md
      name="${name%.md}"                       # foo
      [[ -n "$name" ]] && PROMPT_AGENTS+=("$name")
    done < <(ls "$ROOT_DIR"/ai/agent_*.md 2>/dev/null)
  fi
fi

if [[ ${#PROMPT_AGENTS[@]} -gt 0 ]]; then
  mapfile -t PROMPT_AGENTS < <(printf '%s\n' "${PROMPT_AGENTS[@]}" | sort -u)
fi

#######################################
# 3) قراءة الـ actors/sources من قواعد البيانات
#######################################

DB_ACTORS=()

# helper: جمع نتائج استعلام sqlite بدون إسقاط السكربت عند الخطأ
sqlite_distinct_column() {
  local db="$1"
  local sql="$2"
  if [[ -f "$db" ]]; then
    sqlite3 "$db" "$sql" 2>/dev/null || true
  fi
}

# quality_checks.actor
if [[ -f "$HF_QUALITY_DB" ]]; then
  while IFS= read -r a; do
    [[ -n "$a" ]] && DB_ACTORS+=("$a")
  done < <(sqlite_distinct_column "$HF_QUALITY_DB" "SELECT DISTINCT actor FROM quality_checks;")
fi

# errors.actor
if [[ -f "$HF_ERRORS_DB" ]]; then
  while IFS= read -r a; do
    [[ -n "$a" ]] && DB_ACTORS+=("$a")
  done < <(sqlite_distinct_column "$HF_ERRORS_DB" "SELECT DISTINCT actor FROM errors;")
fi

# tasks.actor
if [[ -f "$HF_TASKS_DB" ]]; then
  while IFS= read -r a; do
    [[ -n "$a" ]] && DB_ACTORS+=("$a")
  done < <(sqlite_distinct_column "$HF_TASKS_DB" "SELECT DISTINCT actor FROM tasks;")
fi

# learning.source (نعتبره actor منطقي)
if [[ -f "$HF_LEARNING_DB" ]]; then
  while IFS= read -r a; do
    [[ -n "$a" ]] && DB_ACTORS+=("$a")
  done < <(sqlite_distinct_column "$HF_LEARNING_DB" "SELECT DISTINCT source FROM learning;")
fi

if [[ ${#DB_ACTORS[@]} -gt 0 ]]; then
  mapfile -t DB_ACTORS < <(printf '%s\n' "${DB_ACTORS[@]}" | sort -u)
fi

#######################################
# 4) عرض النتائج
#######################################

echo
echo "== العمال المعرّفون في config/agents*.yaml =="
if [[ ${#CONFIG_AGENTS[@]} -eq 0 ]]; then
  echo "ℹ️ لا توجد تعريفات agents في config/agents*.yaml حتى الآن."
else
  for id in "${CONFIG_AGENTS[@]}"; do
    echo " - $id"
  done
fi

echo
echo "== العمال المعرّفون عبر برومبتات AI (ai/agent_*.md) =="
if [[ ${#PROMPT_AGENTS[@]} -eq 0 ]]; then
  echo "ℹ️ لا توجد ملفات ai/agent_*.md حتى الآن."
else
  for id in "${PROMPT_AGENTS[@]}"; do
    echo " - $id"
  done
fi

echo
echo "== العمال النشطون فعليًا في قواعد البيانات (actors / sources) =="
if [[ ${#DB_ACTORS[@]} -eq 0 ]]; then
  echo "ℹ️ لا توجد أي سجلات actors/sources حتى الآن في قواعد الجودة/الأخطاء/المهام/التعلّم."
else
  for a in "${DB_ACTORS[@]}"; do
    echo " - $a"
  done
fi

#######################################
# 5) مقارنة: من في config ولم يظهر في DB؟
#######################################

echo
echo "== عمال موجودون في config/agents*.yaml لكن لا يوجد لهم نشاط في قواعد البيانات =="

MISSING_IN_DB=()

for id in "${CONFIG_AGENTS[@]}"; do
  found=0
  for a in "${DB_ACTORS[@]}"; do
    if [[ "$a" == "$id" ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    MISSING_IN_DB+=("$id")
  fi
done

if [[ ${#MISSING_IN_DB[@]} -eq 0 ]]; then
  echo "✅ كل العمال المعرّفين في config لديهم نشاط (أو لا توجد تعريفات config بعد)."
else
  for id in "${MISSING_IN_DB[@]}"; do
    echo " - $id (مُعرّف في config/agents*.yaml لكن لم يَظهر بعد في DB)"
  done
fi

#######################################
# 6) مقارنة: من في DB وليس مذكور في config/agents أو ai/agent_*.md؟
#######################################

echo
echo "== عمال لديهم نشاط في DB لكن لا يوجد لهم تعريف في config/agents أو ai/agent_*.md =="

CONFIG_AND_PROMPTS=("${CONFIG_AGENTS[@]}" "${PROMPT_AGENTS[@]}")
if [[ ${#CONFIG_AND_PROMPTS[@]} -gt 0 ]]; then
  mapfile -t CONFIG_AND_PROMPTS < <(printf '%s\n' "${CONFIG_AND_PROMPTS[@]}" | sort -u)
fi

ORPHANS_IN_DB=()

for a in "${DB_ACTORS[@]}"; do
  found=0
  for id in "${CONFIG_AND_PROMPTS[@]}"; do
    if [[ "$a" == "$id" ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    ORPHANS_IN_DB+=("$a")
  fi
done

if [[ ${#ORPHANS_IN_DB[@]} -eq 0 ]]; then
  echo "✅ لا توجد عمال أيتام في قواعد البيانات بدون تعريف مقابل في config/agents أو ai/agent_*.md."
else
  for a in "${ORPHANS_IN_DB[@]}"; do
    echo " - $a (actor نشط في DB ولا يوجد تعريف واضح له في config/agents أو ai/agent_*.md)"
  done
fi

echo
echo "=================================================="
echo "✅ فحص تكامل العمال مكتمل (Config vs Runtime) – بدون أي تعديل على البيانات"
echo "=================================================="

log_progress "workers_audit_done" "DONE"
