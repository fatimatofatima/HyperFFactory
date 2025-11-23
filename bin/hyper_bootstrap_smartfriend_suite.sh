#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
LOG_FILE="$REPORT_DIR/hf_bootstrap_smartfriend_$(date +%Y%m%d_%H%M%S).log"

SFS_ROOT="/opt/smartfriend-suite"
TARGET_DIR="$SFS_ROOT/var/db"
TARGET_DB="$TARGET_DIR/smartfriend_unified.db"

BACKUP_DIR="$ROOT/backups/db_smartfriend"
mkdir -p "$REPORT_DIR" "$BACKUP_DIR" "$TARGET_DIR"

log() {
  echo "[$(date +%F_%T)] $*" | tee -a "$LOG_FILE"
}

log "=================================================="
log "🚀 SmartFriend Suite Runtime Bootstrap (HyperFFactory)"
log "📍 ROOT: $ROOT"
log "📂 SFS : $SFS_ROOT"
log "=================================================="

if [ ! -d "$SFS_ROOT" ]; then
  log "❌ مجلد /opt/smartfriend-suite غير موجود – لا يمكن المتابعة."
  exit 1
fi

# 1) لو في قاعدة بيانات رسمية، نعمل لها Backup آمن ونمشي.
if [ -f "$TARGET_DB" ]; then
  TS=$(date +%Y%m%d_%H%M%S)
  BAK="$BACKUP_DIR/smartfriend_unified_${TS}.db"
  log "✅ smartfriend_unified.db موجودة بالفعل: $TARGET_DB"
  log "📦 أخذ نسخة احتياطية إلى: $BAK"
  cp -p "$TARGET_DB" "$BAK"
  log "🎯 لا حاجة لتغيير المسار الرسمي. Bootstrap انتهى."
  log "ℹ️ يمكنك الآن مراجعة الخدمات وتشغيلها يدويًا (sf-core / sf-web / sf-health / sf-memory / sf-bot)."
  exit 0
fi

log "⚠️ smartfriend_unified.db غير موجودة في المسار الرسمي: $TARGET_DB"
log "🔍 البحث عن أي نسخ بديلة داخل /opt/smartfriend-suite ..."

# 2) البحث عن أي smartfriend_unified*.db داخل سيوت + أي DBs محتملة
CANDIDATES=$(find "$SFS_ROOT" -maxdepth 6 -type f \
  \( -name 'smartfriend_unified*.db' -o -name '*smartfriend*unified*.db' \) 2>/dev/null || true)

if [ -n "$CANDIDATES" ]; then
  log "📄 تم العثور على المرشحين التالية:"
  echo "$CANDIDATES" | tee -a "$LOG_FILE"

  # اختيار أحدث ملف حسب mtime
  BEST_CANDIDATE=$(printf "%s\n" "$CANDIDATES" | xargs -I{} stat -c '%Y %n' {} | sort -nr | head -n1 | awk '{ $1=""; sub(/^ /,""); print }')

  if [ -n "$BEST_CANDIDATE" ]; then
    TS=$(date +%Y%m%d_%H%M%S)
    BAK="$BACKUP_DIR/smartfriend_unified_from_candidate_${TS}.db"
    log "🎯 اختيار أحدث مرشح كقاعدة بيانات أساسية:"
    log "   -> $BEST_CANDIDATE"

    log "📦 أخذ نسخة احتياطية من المرشح إلى: $BAK"
    cp -p "$BEST_CANDIDATE" "$BAK"

    log "🔗 نسخ القاعدة الأساسية إلى المسار الرسمي: $TARGET_DB"
    cp -p "$BEST_CANDIDATE" "$TARGET_DB"

    log "✅ تم إنشاء smartfriend_unified.db من أحدث مرشح."
    log "ℹ️ يمكنك لاحقًا تشغيل hyper_db_audit_readonly.sh للتدقيق."
    exit 0
  fi
fi

log "⚠️ لا توجد أي smartfriend_unified*.db داخل /opt/smartfriend-suite."
log "🧠 الانتقال لخيار التهيئة من سكربتات HyperFFactory (identity/brain/knowledge)."

# 3) تهيئة من الصفر باستخدام سكربتات hyper_*
cd "$ROOT"

# نتأكد أن السكربتات موجودة (لن نشغّل ما هو غير موجود)
check_script() {
  local s="$1"
  if [ ! -x "$s" ]; then
    if [ -f "$s" ]; then
      log "ℹ️ جعل السكربت قابل للتنفيذ: $s"
      chmod +x "$s"
    else
      log "⚠️ سكربت مفقود (سيتم تخطيه): $s"
      return 1
    fi
  fi
  return 0
}

# ترتيب التهيئة: data_home → runtime_dbs → identity → brain/knowledge
SEQUENCE=(
  "hyper_init_data_home.sh"
  "hyper_init_runtime_dbs.sh"
  "hyper_identity_init.sh"
  "hyper_identity_seed.sh"
  "hyper_init_brain_and_knowledge_v2.sh"
)

for scr in "${SEQUENCE[@]}"; do
  if check_script "$ROOT/$scr"; then
    log "▶ تشغيل $scr ..."
    if "$ROOT/$scr" >>"$LOG_FILE" 2>&1; then
      log "✅ $scr: نجح"
    else
      log "❌ $scr: فشل – راجع اللوج أعلاه، سيتم متابعة باقي خطوات البوتستراب قدر الإمكان."
    fi
  fi
done

# بعد التهيئة، نتأكد مرة ثانية من وجود smartfriend_unified.db
if [ -f "$TARGET_DB" ]; then
  TS=$(date +%Y%m%d_%H%M%S)
  BAK="$BACKUP_DIR/smartfriend_unified_after_init_${TS}.db"
  log "✅ تم إنشاء smartfriend_unified.db أثناء التهيئة."
  log "📦 أخذ نسخة احتياطية تأمينية إلى: $BAK"
  cp -p "$TARGET_DB" "$BAK"
  log "🎯 Bootstrap مكتمل بنجاح من التهيئة."
else
  log "❌ بعد التهيئة، ما زالت smartfriend_unified.db غير موجودة."
  log "   - تحقق يدويًا من سكربتات hyper_* أو هيكل SmartFriend Suite."
  exit 1
fi

log "=================================================="
log "📌 خطوات مقترحة (لا يتم تنفيذها تلقائيًا):"
log "   systemctl restart sf-core.service sf-memory.service sf-health.service sf-web.service sf-bot.service"
log "   systemctl status sf-core.service sf-memory.service sf-health.service sf-web.service sf-bot.service"
log "=================================================="
