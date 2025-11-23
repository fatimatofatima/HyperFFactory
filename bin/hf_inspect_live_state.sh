#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$REPORT_DIR/hf_inspect_live_state_${TS}.log"

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

sep() {
  log "------------------------------------------------------------"
}

log "============================================================"
log "🔎 HF INSPECT LIVE STATE"
log "ROOT : $ROOT"
log "LOG  : $LOG_FILE"
log "============================================================"

############################
# 1) فحص أساسي للبيئة (Git / Python / Docker / Disk)
############################
sep
log "1) فحص أساسي للبيئة (Git / Python / Docker / Disk)"

# حالة الديسك للجذر /
if command -v df >/dev/null 2>&1; then
  log "ℹ️ df -h /:"
  df -h / 2>/dev/null | tee -a "$LOG_FILE" || true
else
  log "⚠️ أمر df غير متوفر."
fi

# حالة Git
if command -v git >/dev/null 2>&1 && [ -d ".git" ]; then
  log "ℹ️ Git status:"
  git status --short --branch 2>&1 | tee -a "$LOG_FILE" || true
else
  log "⚠️ هذا المجلد ليس مستودع Git أو git غير متاح."
fi

# Python / sqlite3 / docker
for cmd in python3 sqlite3 docker; do
  if command -v "$cmd" >/dev/null 2>&1; then
    log "✅ $cmd متوفر في PATH: $(command -v "$cmd")"
  else
    log "⚠️ $cmd غير متوفر في PATH"
  fi
done

############################
# 2) فحص symlinks وفق سياسة Unified Tree
############################
sep
log "2) فحص symlinks وفق سياسة Unified Tree Policy"

ESCAPE_COUNT=0

if command -v find >/dev/null 2>&1; then
  while IFS= read -r -d '' link; do
    target="$(readlink "$link" || true)"
    # لو target مطلق ويخرج برّا الهيكل، ومش في استثناءات التكامل المسموحة
    if [[ "$target" = /* ]] && \
       [[ "$target" != "$ROOT"* ]] && \
       [[ "$target" != /opt/smartfriend-suite* ]] && \
       [[ "$target" != /opt/ffactory* ]]; then
      log "🚨 ESCAPE LINK: $link -> $target"
      ESCAPE_COUNT=$((ESCAPE_COUNT+1))
    fi
  done < <(find "$ROOT" -type l -print0 2>/dev/null)
else
  log "⚠️ أمر find غير متوفر؛ لن يتم فحص symlinks."
fi

if [[ "$ESCAPE_COUNT" -eq 0 ]]; then
  log "✅ لا توجد symlinks تهرّب خارج الهيكل (حسب الفحص الحالي)."
else
  log "⚠️ تم العثور على $ESCAPE_COUNT symlinks تهريب خارج الهيكل – راجع السطور أعلاه."
fi

############################
# 3) فحص db/ وقواعد البيانات الأساسية
############################
sep
log "3) فحص مجلدات وقواعد بيانات db/ الأساسية"

mkdir -p db db/meta

EXPECTED_DBS=(
  "db/quality.db"
  "db/tasks.db"
  "db/experience.db"
  "db/errors.db"
  "db/meta/hf_changes.db"
  "db/meta/hf_learning.db"
)

for db_path in "${EXPECTED_DBS[@]}"; do
  if [[ -f "$db_path" ]]; then
    log "✅ موجود: $db_path"
  else
    log "⚠️ غير موجود (حتى الآن): $db_path"
  fi
done

############################
# 4) فحص جدول quality_checks في quality.db
############################
sep
log "4) فحص جدول quality_checks في db/quality.db"

QUALITY_DB="db/quality.db"

if command -v sqlite3 >/dev/null 2>&1; then
  if [[ -f "$QUALITY_DB" ]]; then
    log "ℹ️ .schema quality_checks:"
    sqlite3 "$QUALITY_DB" ".schema quality_checks" 2>&1 | tee -a "$LOG_FILE" || true

    log "ℹ️ PRAGMA table_info(quality_checks):"
    sqlite3 "$QUALITY_DB" "PRAGMA table_info(quality_checks);" 2>&1 | tee -a "$LOG_FILE" || true
  else
    log "⚠️ db/quality.db غير موجود – نظام الجودة لم يتهيأ بعد."
  fi
else
  log "⚠️ sqlite3 غير متوفر – لن يتم فحص الجداول."
fi

############################
# 5) فحص مسارات التكامل /opt/smartfriend-suite و /opt/ffactory
############################
sep
log "5) فحص مسارات الأنظمة المتكاملة (SmartFriend / FFactory)"

if [[ -d "/opt/smartfriend-suite" ]]; then
  log "✅ موجود: /opt/smartfriend-suite (كنظام متكامل خارجي)"
else
  log "⚠️ /opt/smartfriend-suite غير موجود (أو غير قابل للوصول)."
fi

if [[ -d "/opt/ffactory" ]]; then
  log "✅ موجود: /opt/ffactory (AI Stack خارجي)"
else
  log "⚠️ /opt/ffactory غير موجود (أو غير قابل للوصول)."
fi

############################
# 6) فحص stack/core/docker-compose.core.yml
############################
sep
log "6) فحص stack/core/docker-compose.core.yml وحالة الخدمات (إن أمكن)"

COMPOSE_FILE="stack/core/docker-compose.core.yml"

if [[ -f "$COMPOSE_FILE" ]]; then
  log "✅ ملف compose موجود: $COMPOSE_FILE"
  if command -v docker >/dev/null 2>&1; then
    log "ℹ️ docker compose ps (core stack):"
    docker compose -f "$COMPOSE_FILE" ps 2>&1 | tee -a "$LOG_FILE" || true
  else
    log "⚠️ docker غير متوفر – لا يمكن فحص حالة stack/core."
  fi
else
  log "⚠️ ملف $COMPOSE_FILE غير موجود داخل HyperFFactory."
fi

############################
# 7) فحص hyper_check_short / hyper_bootstrap_local (وضع check فقط)
############################
sep
log "7) تشغيل hyper_check_short.sh / hyper_bootstrap_local.sh (وضع check فقط إن وجدوا)"

if [[ -x "scripts/hyper_check_short.sh" ]]; then
  log "▶️ scripts/hyper_check_short.sh:"
  scripts/hyper_check_short.sh 2>&1 | tee -a "$LOG_FILE" || true
else
  log "⚠️ scripts/hyper_check_short.sh غير موجود أو غير قابل للتنفيذ."
fi

if [[ -x "hyper_bootstrap_local.sh" ]]; then
  log "▶️ hyper_bootstrap_local.sh (HYPER_MODE=check):"
  HYPER_MODE=check ./hyper_bootstrap_local.sh 2>&1 | tee -a "$LOG_FILE" || true
else
  log "⚠️ hyper_bootstrap_local.sh غير موجود أو غير قابل للتنفيذ."
fi

############################
# 8) ملخّص نهائي
############################
sep
log "8) ملخص الفحص (HIGH LEVEL):"
log "• symlink ESCAPES المكتشفة: $ESCAPE_COUNT"
log "• تم فحص وجود قواعد البيانات الأساسية تحت db/."
log "• تم فحص quality.db (schema + table_info) إن وُجدت."
log "• تم فحص وجود /opt/smartfriend-suite و /opt/ffactory."
log "• تم فحص حالة stack/core (docker compose ps) إن أمكن."
log "• تم محاولة تشغيل hyper_check_short / hyper_bootstrap_local في وضع check إن وجدت."

sep
log "✅ انتهى فحص الوضع الحي للمصنع. راجع الملف: $LOG_FILE"
