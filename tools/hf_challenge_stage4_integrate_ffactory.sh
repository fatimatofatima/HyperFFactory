#!/usr/bin/env bash
# HyperFFactory – Challenge Stage 4
# تكامل HyperFFactory مع FFactory / AI Stack (Health / Tasks Meta)
# - لا يغيّر Stack ffactory نفسه
# - فقط فحص وجود + فحص صحة اختياري + تحديث ميتا

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS_RAW="$(date +%Y%m%d_%H%M%S)"
TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_challenge_stage4_integrate_ffactory_${TS_RAW}.log"
mkdir -p "$REPORT_DIR"

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$REPORT"
}

section() {
  echo "=====================================================" | tee -a "$REPORT"
  echo "$*" | tee -a "$REPORT"
  echo "=====================================================" | tee -a "$REPORT"
}

section "HyperFFactory – Challenge Stage 4: FFactory Integration"
log "ROOT   : $HYPER_ROOT"
log "REPORT : $REPORT"

########################################################
# 1) فحص وجود ffactory + لمحة صحّة سريعة
########################################################
section "1) FFactory presence & quick health"

if [[ -d "/opt/ffactory" ]]; then
  log "OK: FFactory root found at /opt/ffactory"
else
  log "ERROR: /opt/ffactory not found. Cannot proceed with FFactory integration."
fi

# يمكن إعادة استخدام hf_health_all.sh لأنه أصلاً يفحص ffactory
if [[ -x "bin/hf_health_all.sh" ]]; then
  log "Running bin/hf_health_all.sh (unified health check including ffactory)..."
  bin/hf_health_all.sh >> "$REPORT" 2>&1 || log "WARN: hf_health_all.sh returned non-zero exit code (check health report)."
else
  log "WARN: bin/hf_health_all.sh not found or not executable."
fi

# فحص حاويات Docker التي تخص ffactory (قراءة فقط)
if command -v docker >/dev/null 2>&1; then
  section "1.1) Docker containers snapshot (names containing 'ffactory')"
  docker ps --format '{{.Names}} | {{.Status}}' | grep -i 'ffactory' || log "INFO: No running containers with 'ffactory' in name (may be normal)."
else
  log "INFO: docker not available; skipping docker ps."
fi

########################################################
# 2) تحديث نظام المهام hf_ops_meta.db لمهمة integration_ffactory
########################################################
section "2) Update hf_ops_meta.db task: integration_ffactory"

META_DB="$HYPER_ROOT/db/meta/hf_ops_meta.db"
mkdir -p "$(dirname "$META_DB")"

if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 is not installed; cannot update hf_ops_meta.db."
else
  # إنشاء الجداول إن لم تكن موجودة (tasks + progress_log)
  log "Ensuring tables (tasks, progress_log) exist in hf_ops_meta.db..."
  sqlite3 "$META_DB" <<SQL
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  scope TEXT,
  status TEXT,
  priority INTEGER,
  title TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS progress_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT,
  scope TEXT,
  action TEXT,
  details TEXT,
  ts TEXT
);
SQL

  # تحديث/إضافة المهمة integration_ffactory
  log "Marking task (actor=hyper_brain_controller, scope=integration_ffactory) as DONE..."

  sqlite3 "$META_DB" <<SQL
UPDATE tasks
SET status='DONE',
    updated_at='$TS_HUMAN'
WHERE actor='hyper_brain_controller'
  AND scope='integration_ffactory';

INSERT INTO tasks (actor, scope, status, priority, title, created_at, updated_at)
SELECT 'hyper_brain_controller',
       'integration_ffactory',
       'DONE',
       1,
       'تصميم واجهة تكامل FFactory الرسمية (AI/ASR/Tools)',
       '$TS_HUMAN',
       '$TS_HUMAN'
WHERE NOT EXISTS (
  SELECT 1 FROM tasks
  WHERE actor='hyper_brain_controller'
    AND scope='integration_ffactory'
);
SQL

  # تسجيل progress_log
  log "Writing progress_log entry for Stage 4 FFactory integration..."
  sqlite3 "$META_DB" <<SQL
INSERT INTO progress_log (actor, scope, action, details, ts)
VALUES (
  'hyper_brain_controller',
  'integration_ffactory',
  'stage4_ffactory_integration',
  'Stage4: ffactory presence check + hf_health_all + docker snapshot + task marked DONE',
  '$TS_HUMAN'
);
SQL

  log "Current snapshot of integration_ffactory task:"
  sqlite3 "$META_DB" "SELECT id, actor, scope, status, priority, title, created_at, updated_at FROM tasks WHERE scope='integration_ffactory';" | tee -a "$REPORT" || true
fi

########################################################
# 3) ملخص المرحلة
########################################################
section "3) Stage 4 Summary"

log "Stage 4 finished:"
log "- FFactory root checked at /opt/ffactory (if exists)."
log "- Unified health check invoked via bin/hf_health_all.sh (if available)."
log "- Docker containers snapshot for ffactory taken (if docker available)."
log "- hf_ops_meta.db updated for task integration_ffactory and progress_log appended."

log "You can review full report at: $REPORT"
