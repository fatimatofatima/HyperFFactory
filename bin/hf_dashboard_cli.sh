#!/usr/bin/env bash
# HyperFFactory - Simple CLI Dashboard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"

TASKS_DB="$META_DIR/hf_tasks.db"
QUALITY_DB="$META_DIR/hf_quality.db"
ERRORS_DB="$META_DIR/hf_errors.db"
CHANGES_DB="$META_DIR/hf_changes.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

echo "=================================================="
echo "📊 HyperFFactory – CLI Dashboard"
echo "📍 Root : $ROOT_DIR"
echo "🕒 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="
echo

# 1) ملخّص المهام
if [[ -f "$TASKS_DB" ]]; then
  echo "1) Tasks Summary (hf_tasks.db)"
  echo "----------------------------------------"
  sqlite3 -header -column "$TASKS_DB" "
    SELECT status, COUNT(*) AS count
    FROM tasks
    GROUP BY status
    ORDER BY status;
  "
  echo
else
  echo "1) Tasks Summary: (لا توجد قاعدة hf_tasks.db)"
  echo
fi

# 2) ملخّص الجودة
if [[ -f "$QUALITY_DB" ]]; then
  echo "2) Quality Summary (hf_quality.db)"
  echo "----------------------------------------"
  sqlite3 -header -column "$QUALITY_DB" "
    SELECT result, COUNT(*) AS count
    FROM quality_checks
    GROUP BY result
    ORDER BY result;
  "
  echo
else
  echo "2) Quality Summary: (لا توجد قاعدة hf_quality.db)"
  echo
fi

# 3) ملخّص الأخطاء
if [[ -f "$ERRORS_DB" ]]; then
  echo "3) Errors Summary (hf_errors.db)"
  echo "----------------------------------------"
  sqlite3 -header -column "$ERRORS_DB" "
    SELECT severity, COUNT(*) AS count
    FROM errors
    GROUP BY severity
    ORDER BY
      CASE severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH' THEN 2
        WHEN 'MEDIUM' THEN 3
        WHEN 'LOW' THEN 4
        ELSE 5
      END;
  "
  echo
else
  echo "3) Errors Summary: (لا توجد قاعدة hf_errors.db)"
  echo
fi

# 4) آخر تغييرات مسجلة (hf_changes.db)
if [[ -f "$CHANGES_DB" ]]; then
  echo "4) Last 10 Changes (hf_changes.db)"
  echo "----------------------------------------"
  sqlite3 -header -column "$CHANGES_DB" "
    SELECT id,actor,scope,action,status,ts
    FROM changes
    ORDER BY ts DESC, id DESC
    LIMIT 10;
  "
  echo
else
  echo "4) Last Changes: (لا توجد قاعدة hf_changes.db أو لم تُنشأ بعد)"
  echo
fi

echo "=================================================="
echo "✅ نهاية لوحة التحكم CLI."
echo "=================================================="
