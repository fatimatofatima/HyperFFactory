#!/usr/bin/env bash
# HyperFFactory – Seed Experience/Skills Tasks into hf_tasks.db
# - READ/WRITE فقط على hf_tasks.db
# - يضيف مهام hyper_experience_manager بدون تكرار (INSERT OR IGNORE على actor+scope)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB_TASKS="$META_DIR/hf_tasks.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

log() {
  local level="$1"; shift
  echo "$(ts) [TASKS-EXPERIENCE] [$level] $*"
}

log "INFO" "HyperFFactory – Seed Experience Tasks"
log "INFO" "ROOT     = $ROOT"
log "INFO" "META_DIR = $META_DIR"
log "INFO" "DB_TASKS = $DB_TASKS"

if [ ! -f "$DB_TASKS" ]; then
  log "WARN" "hf_tasks.db غير موجود – لا يمكن حقن مهام الخبرة."
  exit 0
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR" "sqlite3 غير متوفر."
  exit 1
fi

sqlite3 "$DB_TASKS" <<'SQL'
PRAGMA foreign_keys = OFF;

-- ضمان وجود فهرس يمنع التكرار حسب (actor,scope)
CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_actor_scope
ON tasks(actor, scope);

-- مهام نظام الخبرة/المهارات
INSERT OR IGNORE INTO tasks (actor, scope, status, priority, title, created_at, updated_at)
VALUES
  ('hyper_experience_manager',
   'experience:init_stats',
   'PLANNED',
   60,
   'تهيئة نظام الخبرة من مهام المصنع (hf_experience_init.sh)',
   datetime('now'),
   datetime('now'));

INSERT OR IGNORE INTO tasks (actor, scope, status, priority, title, created_at, updated_at)
VALUES
  ('hyper_experience_manager',
   'experience:refresh_stats_daily',
   'PLANNED',
   55,
   'تحديث دوري لإحصائيات الخبرة من مهام اليوم',
   datetime('now'),
   datetime('now'));

INSERT OR IGNORE INTO tasks (actor, scope, status, priority, title, created_at, updated_at)
VALUES
  ('hyper_experience_manager',
   'experience:report_weekly',
   'PLANNED',
   40,
   'تقرير أسبوعي عن أداء المدراء/العمال ومستويات الخبرة',
   datetime('now'),
   datetime('now'));
SQL

log "INFO" "تم حقن مهام hyper_experience_manager في hf_tasks.db (بدون تكرار)."
