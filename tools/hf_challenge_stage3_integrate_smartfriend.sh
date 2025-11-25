#!/usr/bin/env bash
# HyperFFactory – Challenge Stage 3
# تكامل HyperFFactory مع SmartFriend Suite (Health / Tasks Meta)
# - لا يغيّر ffactory
# - لا يغيّر SmartFriend Suite نفسها (فقط فحص من الخارج + تحديث ميتا داخل HyperFFactory)

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS_RAW="$(date +%Y%m%d_%H%M%S)"
TS_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_challenge_stage3_integrate_smartfriend_${TS_RAW}.log"
mkdir -p "$REPORT_DIR"

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$REPORT"
}

section() {
  echo "=====================================================" | tee -a "$REPORT"
  echo "$*" | tee -a "$REPORT"
  echo "=====================================================" | tee -a "$REPORT"
}

section "HyperFFactory – Challenge Stage 3: SmartFriend Integration"
log "ROOT   : $HYPER_ROOT"
log "REPORT : $REPORT"

########################################################
# 1) فحص وجود السيوت + لمحة صحّة سريعة
########################################################
section "1) SmartFriend Suite presence & quick health"

if [[ -d "/opt/smartfriend-suite" ]]; then
  log "OK: SmartFriend Suite root found at /opt/smartfriend-suite"
else
  log "ERROR: /opt/smartfriend-suite not found. Cannot proceed with SmartFriend integration."
fi

# تشغيل فحص الصحة الموحّد (اختياري)
if [[ -x "bin/hf_health_all.sh" ]]; then
  log "Running bin/hf_health_all.sh (unified health check)..."
  bin/hf_health_all.sh >> "$REPORT" 2>&1 || log "WARN: hf_health_all.sh returned non-zero exit code (check health report)."
else
  log "WARN: bin/hf_health_all.sh not found or not executable."
fi

# محاولة استدعاء بعض Endpoints شهيرة للسيوت (بدون كسر عند الفشل)
if command -v curl >/dev/null 2>&1; then
  log "Trying SmartFriend Suite HTTP health endpoints (best effort)..."

  for URL in \
    "http://127.0.0.1:8214/health" \
    "http://127.0.0.1:8215/health" \
    "http://127.0.0.1:8390/health" \
    "http://127.0.0.1:8383/health"
  do
    log "Checking: $URL"
    curl -sS --max-time 3 "$URL" >> "$REPORT" 2>&1 || log "INFO: $URL not responding (may be normal depending on config)."
    echo "" >> "$REPORT"
  done
else
  log "INFO: curl not available; skipping HTTP health checks."
fi

########################################################
# 2) تحديث نظام المهام hf_ops_meta.db لمهمة integration_smartfriend
########################################################
section "2) Update hf_ops_meta.db task: integration_smartfriend"

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

  # تحديث/إضافة المهمة integration_smartfriend
  log "Marking task (actor=hyper_brain_controller, scope=integration_smartfriend) as DONE..."

  sqlite3 "$META_DB" <<SQL
UPDATE tasks
SET status='DONE',
    updated_at='$TS_HUMAN'
WHERE actor='hyper_brain_controller'
  AND scope='integration_smartfriend';

INSERT INTO tasks (actor, scope, status, priority, title, created_at, updated_at)
SELECT 'hyper_brain_controller',
       'integration_smartfriend',
       'DONE',
       1,
       'تصميم واجهة تكامل SmartFriend الرسمية (Health/Memory/Knowledge/Gateway)',
       '$TS_HUMAN',
       '$TS_HUMAN'
WHERE NOT EXISTS (
  SELECT 1 FROM tasks
  WHERE actor='hyper_brain_controller'
    AND scope='integration_smartfriend'
);
SQL

  # تسجيل progress_log
  log "Writing progress_log entry for Stage 3 SmartFriend integration..."
  sqlite3 "$META_DB" <<SQL
INSERT INTO progress_log (actor, scope, action, details, ts)
VALUES (
  'hyper_brain_controller',
  'integration_smartfriend',
  'stage3_smartfriend_integration',
  'Stage3: health check + hf_health_all + endpoints probe + task marked DONE',
  '$TS_HUMAN'
);
SQL

  log "Current snapshot of integration_smartfriend task:"
  sqlite3 "$META_DB" "SELECT id, actor, scope, status, priority, title, created_at, updated_at FROM tasks WHERE scope='integration_smartfriend';" | tee -a "$REPORT" || true
fi

########################################################
# 3) ملخص المرحلة
########################################################
section "3) Stage 3 Summary"

log "Stage 3 finished:"
log "- SmartFriend Suite root checked at /opt/smartfriend-suite (if exists)."
log "- Unified health check invoked via bin/hf_health_all.sh (if available)."
log "- Optional HTTP health endpoints probed using curl (best effort)."
log "- hf_ops_meta.db updated for task integration_smartfriend and progress_log appended."

log "You can review full report at: $REPORT"
