#!/usr/bin/env bash
# HyperFFactory – Seed Tasks for Experience & Integration
# - يضيف مهام PLANNED إلى hf_tasks.db بدون تكرار
# - لا يفترض وجود عمود 'details' أو أعمدة إضافية

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
TASKS_DB="$META_DIR/hf_tasks.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

echo "====================================================="
echo " HyperFFactory – Seed Experience & Integration Tasks"
echo " ROOT  : $ROOT"
echo " META  : $META_DIR"
echo " DB    : $TASKS_DB"
echo " TIME  : $(ts)"
echo "====================================================="

if [[ ! -f "$TASKS_DB" ]]; then
  echo "[ERROR] hf_tasks.db غير موجود: $TASKS_DB" >&2
  exit 1
fi

NOW="$(ts)"

seed_task() {
  local actor="$1"
  local scope="$2"
  local status="$3"
  local priority="$4"
  local title="$5"

  sqlite3 "$TASKS_DB" <<SQL
INSERT INTO tasks (actor, scope, status, priority, title, created_at, updated_at)
SELECT '$actor', '$scope', '$status', $priority, '$title', '$NOW', '$NOW'
WHERE NOT EXISTS (
  SELECT 1 FROM tasks
  WHERE actor = '$actor' AND scope = '$scope'
);
SQL
}

echo "[INFO] Seeding Experience tasks (hyper_experience_manager)..."
seed_task "hyper_experience_manager" "experience:init_stats"          "PLANNED" 60 "تهيئة نظام الخبرة من مهام المصنع (hf_experience_init.sh)"
seed_task "hyper_experience_manager" "experience:refresh_stats_daily" "PLANNED" 55 "تحديث دوري لإحصائيات الخبرة من مهام اليوم"
seed_task "hyper_experience_manager" "experience:report_weekly"       "PLANNED" 40 "تقرير أسبوعي عن أداء المدراء/العمال ومستويات الخبرة"

echo "[INFO] Seeding Integration tasks (hyper_integration_manager)..."
seed_task "hyper_integration_manager" "integration:smartfriend_health"  "PLANNED" 70 "فحص صحة تكامل SmartFriend Suite مع HyperFFactory"
seed_task "hyper_integration_manager" "integration:ffactory_health"     "PLANNED" 65 "فحص صحة تكامل FFactory Stack مع HyperFFactory"
seed_task "hyper_integration_manager" "integration:apis_map_refresh"    "PLANNED" 60 "تحديث خريطة تكامل APIs (integration_map)"

echo "[INFO] المهام بعد الـ seed (ملخص صغير):"
sqlite3 "$TASKS_DB" <<SQL
.headers on
.mode column
SELECT id, actor, scope, status, priority, title, created_at, updated_at
FROM tasks
WHERE actor IN ('hyper_experience_manager','hyper_integration_manager')
ORDER BY id;
SQL

echo "[INFO] Seed انتهى بنجاح."
