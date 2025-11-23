#!/usr/bin/env bash
# HyperFFactory - Add Learning Experience
# Usage:
#   hf_learning_add_experience.sh <source> <pattern> <outcome> <confidence> [tags]
# confidence ∈ 0–1 (مثلاً 0.8)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB="$ROOT_DIR/db/meta/hf_learning.db"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <source> <pattern> <outcome> <confidence> [tags]" >&2
  exit 1
fi

SOURCE="$1"
PATTERN="$2"
OUTCOME="$3"
CONF="$4"
shift 4 || true
TAGS="${*:-}"

if ! [[ "$CONF" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "❌ confidence يجب أن يكون رقمًا (0–1)." >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  echo "❌ hf_learning.db غير موجود. شغّل hf_learning_init.sh أولاً." >&2
  exit 1
fi

TS="$(date '+%Y-%m-%d %H:%M:%S')"

sqlite3 "$DB" <<SQL
INSERT INTO experiences (source,pattern,outcome,confidence,tags,created_at)
VALUES (
  '$SOURCE',
  '$PATTERN',
  '$OUTCOME',
  $CONF,
  '$TAGS',
  '$TS'
);
SQL

echo "✅ تم تسجيل خبرة جديدة من المصدر: $SOURCE"

PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_learning_add_experience" "INFO" "source=$SOURCE outcome=$OUTCOME conf=$CONF"
fi

exit 0
