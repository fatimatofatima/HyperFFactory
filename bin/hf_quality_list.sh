#!/usr/bin/env bash
# HyperFFactory - List Quality Checks
# Usage:
#   hf_quality_list.sh [LIMIT]
# الافتراضي LIMIT = 50

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_quality.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "${DB}" ]]; then
  echo "⚠️ قاعدة بيانات الجودة غير موجودة: ${DB}" >&2
  echo "▶ شغّل أولاً: bin/hf_quality_init.sh" >&2
  exit 1
fi

LIMIT="${1:-50}"

sqlite3 "${DB}" <<SQL
.headers on
.mode column
.width 4 22 24 8 6 19
SELECT id, actor, check_name, result, score, ts
FROM quality_checks
ORDER BY ts DESC
LIMIT ${LIMIT};
SQL
