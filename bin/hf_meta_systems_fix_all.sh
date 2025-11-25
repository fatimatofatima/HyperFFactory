#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/hf_common.sh"

echo "====================================================="
echo " HyperFFactory – Meta Systems Fix-All"
echo " ROOT : $ROOT_DIR"
echo " META : $META_DB_DIR"
echo " TIME : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "====================================================="

# Helper: check if table exists
table_exists() {
  local db="$1" tbl="$2"
  sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name='$tbl';" | grep -qx "$tbl"
}

# Helper: check if column exists
column_exists() {
  local db="$1" tbl="$2" col="$3"
  sqlite3 "$db" "PRAGMA table_info($tbl);" | awk -F'|' '{print $2}' | grep -qx "$col"
}

echo "[1] Ensuring hf_tasks registry schema..."
if [[ -x "$SCRIPT_DIR/hf_tasks_ensure_schema.sh" ]]; then
  "$SCRIPT_DIR/hf_tasks_ensure_schema.sh"
else
  echo "  [WARN] hf_tasks_ensure_schema.sh غير موجود – تخطي."
fi

echo
echo "[2] Ensuring Errors schema (state/resolved_at/task_id/scope)..."
if [[ -x "$SCRIPT_DIR/hf_errors_schema_upgrade.sh" ]]; then
  "$SCRIPT_DIR/hf_errors_schema_upgrade.sh"
else
  echo "  [WARN] hf_errors_schema_upgrade.sh غير موجود – سأحاول الترقيع مباشرة."
fi

if table_exists "$HF_ERRORS_DB" "errors"; then
  if ! column_exists "$HF_ERRORS_DB" "errors" "scope"; then
    echo "  [+] Adding missing column errors.scope ..."
    sqlite3 "$HF_ERRORS_DB" "ALTER TABLE errors ADD COLUMN scope TEXT;"
  else
    echo "  [OK] errors.scope موجود."
  fi
else
  echo "  [WARN] جدول errors غير موجود في $HF_ERRORS_DB – لن ألمسه."
fi

echo
echo "[3] Ensuring Quality schema (quality_checks)..."
mkdir -p "$(dirname "$HF_QUALITY_DB")"

if table_exists "$HF_QUALITY_DB" "quality_checks"; then
  echo "  [OK] quality_checks موجود – فحص الأعمدة المطلوبة..."
  if ! column_exists "$HF_QUALITY_DB" "quality_checks" "check_key"; then
    echo "    [+] إضافة العمود check_key ..."
    sqlite3 "$HF_QUALITY_DB" "ALTER TABLE quality_checks ADD COLUMN check_key TEXT;"
  fi
  if ! column_exists "$HF_QUALITY_DB" "quality_checks" "target"; then
    echo "    [+] إضافة العمود target ..."
    sqlite3 "$HF_QUALITY_DB" "ALTER TABLE quality_checks ADD COLUMN target TEXT;"
  fi
  if ! column_exists "$HF_QUALITY_DB" "quality_checks" "created_at"; then
    echo "    [+] إضافة العمود created_at ..."
    sqlite3 "$HF_QUALITY_DB" "ALTER TABLE quality_checks ADD COLUMN created_at TEXT;"
  fi
else
  echo "  [WARN] quality_checks غير موجود – إنشاء جدول جديد..."
  sqlite3 "$HF_QUALITY_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS quality_checks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  check_key  TEXT NOT NULL,
  target     TEXT NOT NULL,
  score      REAL NOT NULL,
  details    TEXT,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_quality_checks_key_target
  ON quality_checks (check_key, target);
SQL
fi

echo
echo "[4] Ensuring Experience tables (hf_training_sessions + levels)..."
if [[ -x "$SCRIPT_DIR/hf_experience_training_schema.sh" ]]; then
  "$SCRIPT_DIR/hf_experience_training_schema.sh"
else
  echo "  [WARN] hf_experience_training_schema.sh غير موجود – تخطي إنشاء جدول التدريب."
fi

if [[ -x "$SCRIPT_DIR/hf_experience_recompute_levels.sh" ]]; then
  "$SCRIPT_DIR/hf_experience_recompute_levels.sh"
else
  echo "  [WARN] hf_experience_recompute_levels.sh غير موجود – لن أعيد حساب مستويات الخبرة."
fi

echo
echo "[5] Seeding Tasks (Experience / Integration / Interfaces)..."

if [[ -x "$ROOT_DIR/tools/hf_tasks_seed_experience_and_integration.sh" ]]; then
  "$ROOT_DIR/tools/hf_tasks_seed_experience_and_integration.sh"
else
  echo "  [WARN] tools/hf_tasks_seed_experience_and_integration.sh غير موجود – تخطي."
fi

if [[ -x "$SCRIPT_DIR/hf_tasks_seed_interfaces.sh" ]]; then
  "$SCRIPT_DIR/hf_tasks_seed_interfaces.sh"
else
  echo "  [WARN] hf_tasks_seed_interfaces.sh غير موجود – تخطي مهام الواجهات."
fi

echo
echo "[6] Quick registry diag..."
if [[ -x "$ROOT_DIR/tools/hf_tasks_diag_registry.sh" ]]; then
  "$ROOT_DIR/tools/hf_tasks_diag_registry.sh"
else
  echo "  [WARN] tools/hf_tasks_diag_registry.sh غير موجود – لا يوجد Diag."
fi

echo
echo "[7] Quick tasks snapshot (top 20)..."
if [[ -x "$SCRIPT_DIR/hf_tasks_admin.sh" ]]; then
  "$SCRIPT_DIR/hf_tasks_admin.sh" list | head -20 || true
else
  echo "  [WARN] hf_tasks_admin.sh غير موجود – لا يمكن عرض المهام."
fi

echo
echo "====================================================="
echo " Meta Systems Fix-All – DONE (بدون تعديل cron أو الخدمات)."
echo "====================================================="
