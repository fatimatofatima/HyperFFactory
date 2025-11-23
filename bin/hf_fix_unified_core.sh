#!/usr/bin/env bash
# HyperFFactory - Fix Unified Core Layout
# يضمن الهيكل الأساسي + ملفات الهوية والخطة داخل /root/HyperFFactory فقط

set -euo pipefail

ROOT="/root/HyperFFactory"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$ROOT/reports"
LOG="$REPORT_DIR/hf_fix_unified_core_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HF FIX UNIFIED CORE START"
log "ROOT = $ROOT"
log "=================================================="

# 1) إنشاء المجلدات الأساسية داخل الهيكل الموحّد فقط
REQUIRED_DIRS=(
  "$ROOT/opt"
  "$ROOT/data"
  "$ROOT/data/inbox"
  "$ROOT/data/raw"
  "$ROOT/data/processed"
  "$ROOT/data/semantic"
  "$ROOT/data/serving"
  "$ROOT/logs"
  "$ROOT/reports"
  "$ROOT/db"
  "$ROOT/db/meta"
  "$ROOT/db/tasks"
  "$ROOT/db/quality"
  "$ROOT/db/experience"
  "$ROOT/db/errors"
  "$ROOT/config"
  "$ROOT/workers"
  "$ROOT/bin"
)

CREATED=0
EXISTING=0

for d in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$d" ]; then
    log "DIR OK     : $d"
    EXISTING=$((EXISTING+1))
  else
    mkdir -p "$d"
    log "DIR CREATED: $d"
    CREATED=$((CREATED+1))
  fi
done

log "DIRS EXISTING = $EXISTING"
log "DIRS CREATED  = $CREATED"

# 2) ضمان وجود README.md
README="$ROOT/README.md"
if [ ! -f "$README" ]; then
  log "README.md غير موجود – سيتم إنشاء نسخة أساسية."
  cat > "$README" <<'RMD'
========================================================
        HyperFFactory – Unified Factory Login
========================================================

هذا الملف يمثل هوية المصنع الموحّد HyperFFactory.
المصدر الحقيقي للتنفيذ هو هذا السيرفر، وليس GitHub.

- الجذر الموحّد: /root/HyperFFactory
- أنظمة متكاملة (تكامل فقط):
  - /opt/smartfriend-suite
  - /opt/ffactory

أي سكربت أو خدمة تعمل خارج هذه السياسة يجب إصلاحها
عبر سكربتات HyperFFactory داخل bin/ و workers/ و reports/.

RMD
  log "README.md تم إنشاؤه."
else
  log "README.md موجود – لم يتم تغييره."
fi

# 3) ضمان وجود plan_status.md (حالة الخطة)
PLAN_STATUS="$ROOT/plan_status.md"
if [ ! -f "$PLAN_STATUS" ]; then
  log "plan_status.md غير موجود – سيتم إنشاء لوحة حالة افتراضية."
  cat > "$PLAN_STATUS" <<'PMD'
# HyperFFactory – Plan Status

| البند                         | الحالة | ملاحظات مختصرة                          |
|------------------------------|--------|----------------------------------------|
| المرحلة 1 – توحيد المسارات   | 🟡     | HyperFFactory + SmartFriend + FFactory |
| المرحلة 2 – قنوات التكامل   | 🟡     | Health / Memory / Gateway / AI Stack   |
| المرحلة 3 – الجودة والتحسين | 🟡     | KPIs / Dashboards / تقييم دوري         |
| نظام المهام (Tasks)         | 🟡     | إنشاء DB وجداول المهام                 |
| نظام الجودة (Quality)       | 🟡     | إنشاء DB وجداول الجودة                 |
| نظام الخبرة (Experience)    | 🟡     | إنشاء DB وجداول الخبرة                 |
| نظام الأخطاء (Errors)       | 🟡     | إنشاء DB وجداول الحوادث                |

تحديث هذه اللوحة يتم يدويًا أو عبر سكربتات إدارة الخطة.
PMD
  log "plan_status.md تم إنشاؤه."
else
  log "plan_status.md موجود – لم يتم تغييره."
fi

log "=================================================="
log "HF FIX UNIFIED CORE DONE"
log "LOG = $LOG"
log "=================================================="
