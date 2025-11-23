#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
BACKUP_DIR="$ROOT/backups/db_smartfriend"

SFS_ROOT="/opt/smartfriend-suite"
TARGET_DIR="$SFS_ROOT/var/db"
TARGET_DB="$TARGET_DIR/smartfriend_unified.db"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR" "$TARGET_DIR"

LOG_FILE="$REPORT_DIR/hyper_recover_smartfriend_$(date +%Y%m%d_%H%M%S).log"

log() {
  echo "[$(date +%F_%T)] $*" | tee -a "$LOG_FILE"
}

log "=================================================="
log "🧠 HyperFFactory – SmartFriend Unified DB Recover"
log "TARGET_DB: $TARGET_DB"
log "=================================================="

# 1) لو القاعدة موجودة بالفعل – لا نلمسها
if [ -f "$TARGET_DB" ]; then
  size=$(stat -c '%s' "$TARGET_DB" 2>/dev/null || echo "?")
  log "✅ smartfriend_unified.db موجودة بالفعل (الحجم: $size بايت). لا حاجة للاستعادة."
  exit 0
fi

log "⚠️ smartfriend_unified.db غير موجودة. بدء البحث عن نسخ بديلة..."

tmp_candidates="$(mktemp)"
trap 'rm -f "$tmp_candidates"' EXIT

# --------------------------------------------------
# 2) المرشح الأول: مجلد الباكاب الرسمي في HyperFFactory
# --------------------------------------------------
if ls "$BACKUP_DIR"/smartfriend_unified*.db >/dev/null 2>&1; then
  log "🔎 العثور على نسخ في $BACKUP_DIR"
  ls "$BACKUP_DIR"/smartfriend_unified*.db >> "$tmp_candidates"
fi

# --------------------------------------------------
# 3) المرشح الثاني: تقارير تدقيق قواعد البيانات (db_audit_*.txt)
# --------------------------------------------------
for audit in "$ROOT"/reports/db_audit_*.txt; do
  if [ -f "$audit" ]; then
    log "🔎 فحص تقرير: $audit"
    grep -h "smartfriend_unified" "$audit" 2>/dev/null \
      | grep -o '/[^ ]*smartfriend_unified[^ ]*\.db' \
      >> "$tmp_candidates" || true
  fi
done

# --------------------------------------------------
# 4) المرشح الثالث: بحث مباشر في /root و /opt (طوارئ)
# --------------------------------------------------
if [ ! -s "$tmp_candidates" ]; then
  log "🔎 لا توجد مراجع في الباكاب/التقارير – بدء بحث مباشر في /root و /opt (قد يستغرق قليلاً)..."
  find /root /opt \
    -maxdepth 8 -type f -name 'smartfriend_unified*.db' 2>/dev/null \
    >> "$tmp_candidates" || true
fi

if [ ! -s "$tmp_candidates" ]; then
  log "❌ لم يتم العثور على أي smartfriend_unified*.db على السيرفر."
  log "ℹ️ في هذه الحالة، نحتاج لاحقًا لتهيئة قاعدة جديدة (schema) يدويًا من تعريف الجداول."
  exit 1
fi

# إزالة التكرار
sort -u "$tmp_candidates" > "${tmp_candidates}.uniq"
mv "${tmp_candidates}.uniq" "$tmp_candidates"

log "📄 المرشّحات المحتملة:"
sed 's/^/   - /' "$tmp_candidates" | tee -a "$LOG_FILE"

# --------------------------------------------------
# 5) اختيار أفضل مرشح (الأكبر حجمًا)
# --------------------------------------------------
best_path=""
best_size=0

while IFS= read -r path; do
  [ -z "$path" ] && continue
  if [ -f "$path" ]; then
    size=$(stat -c '%s' "$path" 2>/dev/null || echo 0)
    log "   • مرشح: $path (الحجم: $size)"
    if [ "$size" -gt "$best_size" ]; then
      best_size="$size"
      best_path="$path"
    fi
  fi
done < "$tmp_candidates"

if [ -z "$best_path" ]; then
  log "❌ لا يوجد أي مرشح صالح يمكن نسخه."
  exit 1
fi

log "✅ أفضل مرشح: $best_path (الحجم: $best_size بايت)"

# --------------------------------------------------
# 6) نسخ القاعدة إلى المسار الرسمي
# --------------------------------------------------
if [ -f "$TARGET_DB" ]; then
  ts="$(date +%Y%m%d_%H%M%S)"
  cp -p "$TARGET_DB" "$BACKUP_DIR/smartfriend_unified_existing_$ts.db"
  log "📦 تم أخذ نسخة احتياطية من الهدف الحالي إلى: $BACKUP_DIR/smartfriend_unified_existing_$ts.db"
fi

cp -p "$best_path" "$TARGET_DB"
log "📦 تم نسخ قاعدة البيانات إلى المسار الرسمي: $TARGET_DB"

ls -lh "$TARGET_DB" | tee -a "$LOG_FILE"

log "🎯 الاستعادة اكتملت. يُفضّل الآن تشغيل:"
log "   - bin/hf_health_all.sh"
log "   - ثم مراجعة حالة خدمات sf-core / sf-web / sf-health / sf-memory"

exit 0
