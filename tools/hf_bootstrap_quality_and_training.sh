#!/usr/bin/env bash
# HyperFFactory – Bootstrap Quality & Training layer (Phase 3 – جزء 2)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_DIR="$ROOT/reports"
LOG="$LOG_DIR/hf_bootstrap_quality_and_training_${TS}.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d_%H:%M:%S')] $*" | tee -a "$LOG"
}

log "=================================================="
log "🧩 HyperFFactory – Bootstrap Quality & Training"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "=================================================="

DB_DIR="$ROOT/db/meta"
mkdir -p "$DB_DIR"

QUALITY_DB="$DB_DIR/hf_quality.db"
LEARN_DB="$DB_DIR/hf_learning.db"

# 1) hf_quality.db – events/KPIs
log "ℹ️ تهيئة قاعدة الجودة: $QUALITY_DB"

sqlite3 "$QUALITY_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS quality_events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  system_name  TEXT,
  metric_name  TEXT,
  metric_value REAL,
  window_label TEXT,
  meta_json    TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_quality_events_sys_metric
  ON quality_events(system_name, metric_name);
SQL

log "✅ إنشاء/تأكيد جدول quality_events في $QUALITY_DB"

# 2) hf_learning.db – SkillState بسيط
log "ℹ️ تهيئة قاعدة التعلم: $LEARN_DB"

sqlite3 "$LEARN_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS learning_skill_states (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  actor       TEXT,
  skill_key   TEXT,
  level       TEXT,
  samples     INTEGER DEFAULT 0,
  meta_json   TEXT,
  last_update TEXT DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_skill_state_actor_skill
  ON learning_skill_states(actor, skill_key);
SQL

log "✅ إنشاء/تأكيد جدول learning_skill_states في $LEARN_DB"

# 3) توليد tools/hf_quality_report.sh لو مش موجود
REPORT_SCRIPT="$ROOT/tools/hf_quality_report.sh"

if [[ -f "$REPORT_SCRIPT" ]]; then
  log "ℹ️ سكربت تقرير الجودة موجود مسبقاً: $REPORT_SCRIPT"
else
  cat > "$REPORT_SCRIPT" <<'RS_EOF'
#!/usr/bin/env bash
# HyperFFactory – Quality KPI Report (Summary)

set -euo pipefail

ROOT="/root/HyperFFactory"
QUALITY_DB="$ROOT/db/meta/hf_quality.db"

cd "$ROOT"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير متوفر."
  exit 1
fi

echo "=================================================="
echo "🧩 HyperFFactory – Quality KPI Summary"
echo "DB : $QUALITY_DB"
echo "=================================================="

sqlite3 -header -column "$QUALITY_DB" <<'SQL'
SELECT
  system_name,
  metric_name,
  ROUND(AVG(metric_value), 3) AS avg_value,
  COUNT(*) AS samples,
  MAX(window_label) AS last_window,
  MAX(created_at)  AS last_record
FROM quality_events
GROUP BY system_name, metric_name
ORDER BY system_name, metric_name;
SQL
RS_EOF

  chmod +x "$REPORT_SCRIPT"
  log "✅ إنشاء سكربت تقرير الجودة: $REPORT_SCRIPT"
fi

log "=================================================="
log "✅ Bootstrap Quality & Training اكتمل."
log "   - QUALITY_DB : $QUALITY_DB"
log "   - LEARN_DB   : $LEARN_DB"
log "=================================================="

echo "✅ تم تنفيذ hf_bootstrap_quality_and_training بنجاح."
echo "🔎 راجع التقرير: $LOG"
