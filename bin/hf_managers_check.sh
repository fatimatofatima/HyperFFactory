#!/usr/bin/env bash
# HyperFFactory - Managers Runtime Snapshot
# يظهر قائمة المدراء من hf_learning.db + آخر نشاط مسجّل لهم من hf_changes.db

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
LDB="$ROOT_DIR/db/meta/hf_learning.db"
CDB="$ROOT_DIR/db/meta/hf_changes.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

if [[ ! -f "$LDB" ]]; then
  echo "❌ قاعدة التعلّم غير موجودة: $LDB" >&2
  exit 1
fi

if [[ ! -f "$CDB" ]]; then
  echo "❌ قاعدة التغييرات غير موجودة: $CDB" >&2
  exit 1
fi

echo "=================================================="
echo "🧠 HYPERFFACTORY – MANAGERS RUNTIME SNAPSHOT"
echo "📍 Time  : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root  : $ROOT_DIR"
echo "📄 LDB   : $LDB"
echo "📄 CDB   : $CDB"
echo "=================================================="
echo

echo "1) فهرس المدراء من طبقة التعلّم (hf_learning.db) – الأعلى أولوية:"
echo "--------------------------------------------------"
sqlite3 -header -column "$LDB" "
  SELECT
    system,
    category,
    role,
    priority,
    name,
    path
  FROM scripts
  WHERE role = 'manager'
  ORDER BY priority ASC, system ASC, name ASC
  LIMIT 80;
"
echo

echo "2) آخر نشاط مسجّل للمدراء (hf_changes.db) – آخر 50 حدث:"
echo "--------------------------------------------------"
sqlite3 -header -column "$CDB" "
  SELECT
    ts,
    actor,
    status,
    message
  FROM changes
  ORDER BY id DESC
  LIMIT 50;
"
echo

echo "3) إحصائيات سريعة:"
echo "--------------------------------------------------"
echo "- عدد المدراء في learning.db:"
sqlite3 "$LDB" "SELECT COUNT(*) FROM scripts WHERE role='manager';"

echo
echo "- عدد سجلات التقدّم في changes.db:"
sqlite3 "$CDB" "SELECT COUNT(*) FROM changes;"

echo
echo "✅ انتهى فحص المدراء (Managers Runtime Snapshot)."
