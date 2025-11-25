#!/usr/bin/env bash
# HyperFFactory – Challenge Stage 2
# تفعيل الربط بين Behavioral Forensic Engine + Behavior & Forensic Bot
# - لا يغيّر ffactory
# - يستخدم سكربت السيوت الموجود لإنشاء/تحديث sf-bot-behavior.service
# - يتأكد من وجود hf_patterns.db + ai/patterns/patterns.json

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_challenge_stage2_enable_behavior_bot_${TS}.log"
mkdir -p "$REPORT_DIR"

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" | tee -a "$REPORT"
}

section() {
  echo "=====================================================" | tee -a "$REPORT"
  echo "$*" | tee -a "$REPORT"
  echo "=====================================================" | tee -a "$REPORT"
}

section "HyperFFactory – Challenge Stage 2: Enable Behavioral Forensic Engine & Behavior Bot"
log "ROOT   : $HYPER_ROOT"
log "REPORT : $REPORT"

########################################################
# 1) فحوصات أساسية (وجود المسارات الأساسية)
########################################################
section "1) Basic checks"

# التحقق من مسار السيوت
if [[ -d "/opt/smartfriend-suite" ]]; then
  log "OK: SmartFriend Suite root found at /opt/smartfriend-suite"
else
  log "ERROR: /opt/smartfriend-suite not found. Cannot proceed with Behavior Bot wiring."
  exit 1
fi

# التحقق من ملف manifest الخاص بالمصنع الجنائي/السلوكي
if [[ -f "config/forensics_factory_manifest.yaml" ]]; then
  log "OK: forensics_factory_manifest.yaml found."
  head -n 20 config/forensics_factory_manifest.yaml | sed 's/^/[MANIFEST] /' | tee -a "$REPORT" || true
else
  log "WARN: config/forensics_factory_manifest.yaml not found (Stage 1 should have created it)."
fi

# التحقق من identity_roles.yaml لوجود التعريفات
if [[ -f "config/identity_roles.yaml" ]]; then
  log "OK: identity_roles.yaml found. Extracting behavioral_forensic_engine + behavior_bot snippets..."
  grep -n "behavioral_forensic_engine" -n config/identity_roles.yaml | head -n 5 | sed 's/^/[IDENTITY] /' | tee -a "$REPORT" || true
  grep -n "behavior_bot" -n config/identity_roles.yaml | head -n 10 | sed 's/^/[IDENTITY] /' | tee -a "$REPORT" || true
else
  log "WARN: config/identity_roles.yaml not found."
fi

########################################################
# 2) تشغيل سكربت إصلاح SmartFriend Spider + Behavior Bot (إن وجد)
########################################################
section "2) Run sf_suite_fix_spider_and_behavior.sh (if available)"

SPIDER_FIX_SCRIPT="scripts/spiders/sf_suite_fix_spider_and_behavior.sh"

if [[ -x "$SPIDER_FIX_SCRIPT" ]]; then
  log "Running $SPIDER_FIX_SCRIPT ..."
  # نضيف prefix [SPIDER] على كل سطر من مخرجات السكربت
  "$SPIDER_FIX_SCRIPT" 2>&1 | sed 's/^/[SPIDER] /' | tee -a "$REPORT" || log "WARN: spider fix script returned non-zero exit code."
else
  log "WARN: $SPIDER_FIX_SCRIPT not found or not executable. Skipping spider-based unit creation."
fi

########################################################
# 3) التأكد من وجود وتشغيل خدمة sf-bot-behavior.service
########################################################
section "3) Ensure sf-bot-behavior.service is enabled and running"

if systemctl list-unit-files | awk '{print $1}' | grep -qx "sf-bot-behavior.service"; then
  log "OK: sf-bot-behavior.service unit file is present (systemd)."
  log "Reloading systemd daemon..."
  systemctl daemon-reload || log "WARN: systemctl daemon-reload failed (continuing)."

  log "Enabling and starting sf-bot-behavior.service..."
  if systemctl enable --now sf-bot-behavior.service; then
    log "OK: sf-bot-behavior.service enabled and started (enable --now)."
  else
    log "WARN: Failed to enable/start sf-bot-behavior.service (check systemctl status manually)."
  fi

  log "Collecting short status for sf-bot-behavior.service..."
  systemctl status sf-bot-behavior.service --no-pager -l | head -n 40 >> "$REPORT" 2>&1 || true
else
  log "WARN: sf-bot-behavior.service unit file NOT found even after running spider script."
  log "      You may need to inspect /etc/systemd/system/ manually or re-run the spider fix script."
fi

########################################################
# 4) ضمان وجود hf_patterns.db + ai/patterns/patterns.json
########################################################
section "4) Ensure patterns DB and JSON snapshot exist"

# 4.1 hf_patterns.db
PATTERNS_DB="db/meta/hf_patterns.db"

if [[ -f "$PATTERNS_DB" ]]; then
  log "OK: $PATTERNS_DB exists."
else
  log "WARN: $PATTERNS_DB not found. Creating minimal SQLite DB with patterns table..."
  mkdir -p "$(dirname "$PATTERNS_DB")"
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$PATTERNS_DB" "CREATE TABLE IF NOT EXISTS patterns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pattern TEXT,
      source TEXT,
      created_at TEXT
    );"
    log "OK: Created $PATTERNS_DB with basic patterns table."
  else
    log "ERROR: sqlite3 is not installed. Cannot create $PATTERNS_DB automatically."
  fi
fi

# 4.2 ai/patterns/patterns.json
PATTERNS_JSON="ai/patterns/patterns.json"

if [[ -f "$PATTERNS_JSON" ]]; then
  log "OK: $PATTERNS_JSON exists. Showing first lines snapshot..."
  head -n 10 "$PATTERNS_JSON" | sed 's/^/[PATTERNS_JSON] /' | tee -a "$REPORT" || true
else
  log "WARN: $PATTERNS_JSON not found. Creating placeholder patterns.json..."
  mkdir -p "ai/patterns"
  cat > "$PATTERNS_JSON" <<'JSON'
{
  "patterns": [],
  "meta": {
    "created_by": "hf_challenge_stage2_enable_behavior_bot.sh",
    "description": "Initial placeholder patterns snapshot for Behavioral Forensic Engine",
    "version": 1
  }
}
JSON
  log "OK: Placeholder $PATTERNS_JSON created."
fi

########################################################
# 5) ملخص تنفيذي للمرحلة
########################################################
section "5) Stage 2 Summary"

log "Stage 2 finished:"
log "- SmartFriend Suite root checked at /opt/smartfriend-suite."
log "- forensics_factory_manifest.yaml / identity_roles.yaml inspected."
log "- sf_suite_fix_spider_and_behavior.sh executed if present."
log "- sf-bot-behavior.service enable/start attempted and status captured."
log "- hf_patterns.db ensured with basic schema (if sqlite3 available)."
log "- ai/patterns/patterns.json ensured (placeholder created if missing)."

log "You can review full report at: $REPORT"
