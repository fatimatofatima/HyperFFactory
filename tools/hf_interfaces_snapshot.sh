#!/usr/bin/env bash
# HyperFFactory – Interfaces Snapshot (Markdown dashboard)

set -euo pipefail

ROOT="${ROOT:-/root/HyperFFactory}"
cd "$ROOT"

BIN_DIR="$ROOT/bin"
# shellcheck source=/dev/null
source "$BIN_DIR/hf_common.sh"

mkdir -p reports

TS_FULL="$(date '+%Y-%m-%d %H:%M:%S %z')"
TS_KEY="$(date '+%Y%m%d_%H%M%S')"

OUT_FILE="reports/hf_dashboard_snapshot_${TS_KEY}.md"
LATEST_LINK="reports/hf_dashboard_latest.md"

echo "[INFO] Generating dashboard snapshot: $OUT_FILE"

TASKS_TOP="$(sqlite3 -header -column "$HF_TASKS_DB" "
SELECT
  id,
  actor,
  title,
  scope,
  status,
  priority,
  created_at,
  updated_at,
  tags
FROM tasks
ORDER BY (status='PLANNED') DESC, priority DESC, id DESC
LIMIT 20;
")"

INCIDENTS_OPEN="$(sqlite3 -header -column "$HF_ERRORS_DB" "
SELECT
  id,
  actor,
  error_type,
  error_message,
  severity,
  COALESCE(scope, '') AS scope,
  COALESCE(state, 'OPEN') AS state,
  ts
FROM errors
WHERE state IS NULL OR state='OPEN'
ORDER BY ts DESC
LIMIT 20;
")"

QUALITY_LAST="$(sqlite3 -header -column "$HF_QUALITY_DB" "
SELECT
  id,
  actor,
  check_name,
  result,
  score,
  scope,
  target,
  ts
FROM quality_checks
ORDER BY ts DESC
LIMIT 10;
")"

ACTORS_STATS="$(sqlite3 -header -column "$HF_ACTORS_DB" "
SELECT
  actor,
  runs_total,
  runs_success,
  success_rate,
  experience_level
FROM hf_actor_stats
ORDER BY runs_total DESC, runs_success DESC
LIMIT 10;
")"

cat > "$OUT_FILE" <<SNAP
# HyperFFactory – Dashboard Snapshot

وقت التوليد: $TS_FULL  
ROOT: $ROOT  

---

## 1) المهام (Top 20 من tasks)

\`\`\`
$TASKS_TOP
\`\`\`

---

## 2) الحوادث المفتوحة (errors – state=NULL/OPEN, Top 20)

\`\`\`
$INCIDENTS_OPEN
\`\`\`

---

## 3) آخر فحوص الجودة (quality_checks – آخر 10 صفوف)

\`\`\`
$QUALITY_LAST
\`\`\`

---

## 4) إحصائيات الخبرة (hf_actor_stats – Top 10)

\`\`\`
$ACTORS_STATS
\`\`\`

---

تقرير آلي من HyperFFactory – interfaces snapshot.
SNAP

ln -sf "$(basename "$OUT_FILE")" "$LATEST_LINK"

echo "✅ Snapshot written to $OUT_FILE"
echo "🔗 Latest symlink: $LATEST_LINK"
