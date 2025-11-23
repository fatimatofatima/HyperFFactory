#!/usr/bin/env bash
# HyperFFactory - Add Experience (Learning)
# Usage:
#   hf_experience_add.sh <source> <confidence> <pattern> <outcome> <tags>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_learning.db"

LEARN_INIT="$ROOT_DIR/bin/hf_learning_init.sh"
PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت." >&2
  exit 1
fi

if [[ ! -f "$DB" ]]; then
  if [[ -x "$LEARN_INIT" ]]; then
    "$LEARN_INIT"
  else
    echo "❌ hf_learning.db غير موجود و hf_learning_init.sh غير متاح." >&2
    exit 1
  fi
fi

if [[ $# -lt 5 ]]; then
  echo "Usage: $(basename "$0") <source> <confidence> <pattern> <outcome> <tags>" >&2
  exit 1
fi

source="$1"
confidence_raw="$2"
pattern="$3"
outcome="$4"
tags="$5"

# التأكد من أن confidence رقم (0–1)
if ! printf '%s' "$confidence_raw" | grep -Eq '^[0-9]*\.?[0-9]+$'; then
  echo "⚠️ confidence '$confidence_raw' ليس رقمًا، سيتم تخزينه 0.5" >&2
  confidence="0.5"
else
  confidence="$confidence_raw"
fi

created_at="$(date '+%Y-%m-%d %H:%M:%S')"

esc() {
  printf "%s" "$1" | sed "s/'/''/g"
}

sql="
INSERT INTO experiences (source,pattern,outcome,confidence,tags,created_at)
VALUES (
  '$(esc "$source")',
  '$(esc "$pattern")',
  '$(esc "$outcome")',
  $confidence,
  '$(esc "$tags")',
  '$(esc "$created_at")'
);
"

sqlite3 "$DB" "$sql"

if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_experience_add" "INFO" "source=$source confidence=$confidence"
fi

echo "✅ تم إضافة خبرة/نمط جديد في $DB"
