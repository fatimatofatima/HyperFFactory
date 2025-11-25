#!/usr/bin/env bash
# HyperFFactory – Seed DB Manager Tasks into hf_tasks.db
# - READ/WRITE فقط على hf_tasks.db
# - يضيف مهام hf_db_manager (meta_dbs + registry/index)
# - يستخدم INSERT OR IGNORE حتى لا يكرر نفس المهمة لو عندك UNIQUE (actor,scope)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB="$META_DIR/hf_tasks.db"

ts() {
  date +"%Y-%m-%d %H:%M:%S %z"
}

echo "====================================================="
echo " HyperFFactory – Seed hf_db_manager Tasks"
echo " ROOT : $ROOT"
echo " DB   : $DB"
echo " TIME : $(ts)"
echo "====================================================="

if [ ! -f "$DB" ]; then
  echo "❌ لم يتم العثور على $DB" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت على النظام." >&2
  exit 1
fi

# ضمان وجود جدول tasks (بنفس الشكل المستخدم في الداشبورد)
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS tasks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  actor      TEXT NOT NULL,
  scope      TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'PLANNED',
  priority   INTEGER NOT NULL DEFAULT 50,
  title      TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
SQL

# اختياري: UNIQUE على (actor,scope) لو مش موجود – لن يكسر لو موجود بشكل مختلف
# (CREATE IF NOT EXISTS للـ index غير مدعوم في SQLite، فنعمل IF NOT EXISTS يدوي بسيط)
HAS_UNIQUE=$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_tasks_actor_scope_unique';" || true)
if [ -z "$HAS_UNIQUE" ]; then
  sqlite3 "$DB" "CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_actor_scope_unique ON tasks(actor,scope);" 2>/dev/null || true
fi

NOW="$(ts)"

# قائمة المهام المطلوب حقنها (meta_dbs + registry/index)
sqlite3 "$DB" <<SQL
INSERT OR IGNORE INTO tasks (actor, scope, status, priority, title, created_at, updated_at) VALUES
  -- مهام قواعد بيانات الميتا (كما ظهرت في الداشبورد)
  ('hf_db_manager', 'db_manager:meta_dbs:check_schema',     'PLANNED', 80, 'فحص مخطط قواعد بيانات الميتا (schema check)',             '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:meta_dbs:integrity_check',  'PLANNED', 90, 'فحص سلامة قواعد بيانات الميتا (integrity_check)',         '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:meta_dbs:vacuum',           'PLANNED', 60, 'تهيئة وتحسين قواعد بيانات الميتا (VACUUM)',               '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:meta_dbs:backup_policy',    'PLANNED', 70, 'فحص التزام قواعد بيانات الميتا بسياسة النسخ الاحتياطي',  '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:meta_dbs:size_report',      'PLANNED', 50, 'تقرير أحجام قواعد بيانات الميتا',                         '$NOW', '$NOW'),

  -- مهام خاصة بالـ Registry + Index (أوعى ننسى الريجستري والاندكس)
  ('hf_db_manager', 'db_manager:registry:scan',             'PLANNED', 65, 'فحص جدول/جداول الريجستري ومقارنتها بالملفات الفعلية',      '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:registry:validate_index',   'PLANNED', 75, 'فحص سلامة الفهارس (indexes) والقيود الفريدة على الريجستري', '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:registry:rebuild_index',    'PLANNED', 85, 'إعادة بناء الفهارس المفقودة أو التالفة في جداول الريجستري',  '$NOW', '$NOW'),
  ('hf_db_manager', 'db_manager:registry:orphans_cleanup',  'PLANNED', 55, 'كشف سجلات الريجستري اليتيمة (بدون ملفات فعلية) وجدولتها', '$NOW', '$NOW');
SQL

echo "✅ تم حقن مهام hf_db_manager (meta_dbs + registry/index) في hf_tasks.db (بدون تكرار على actor+scope)."
