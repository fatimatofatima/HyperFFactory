#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

MODE="${1:-list}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/root/db_cleanup_backup_${TS}"

log(){ echo "[$(date '+%F %T')] $*"; }

log "===== التنظيف الشامل لقواعد البيانات القديمة ====="
log "MODE: $MODE"
log "BACKUP_DIR: $BACKUP_DIR"

# القواعد التي يجب الاحتفاظ بها (الهيكل النهائي)
KEEP_DBS=(
  "/opt/smartfriend-suite/var/db/active_memory.db"
  "/opt/smartfriend-suite/var/db/smartfriend_unified.db"
  "/opt/smartfriend-suite/var/db/memory.db"
  "/opt/smartfriend-suite/var/db/smart_core_memory.db"
)

# القواعد التي يجب حذفها (جميع القديمة والزائدة)
TARGET_DBS=(
  # قواعد الذاكرة القديمة
  "/opt/smartfriend-suite/var/db/unified_memory.db"
  "/opt/smartfriend-suite/var/db/neural_memory.db"
  "/opt/smartfriend-suite/var/db/smartfriend_memory.db"
  "/opt/smartfriend-suite/var/db/cognitive_memory.db"
  
  # قواعد BRAIN_CORE القديمة
  "/opt/BRAIN_CORE/memory/shared.db"
  "/opt/BRAIN_CORE/memory/legacy_memory.db"
  "/opt/BRAIN_CORE/data/core_memory.db"
  
  # قواعد ffactory القديمة
  "/opt/ffactory/data/memory.db"
  "/opt/ffactory/data/core.db"
  "/opt/ffactory/data/brain.db"
  
  # أي قاعدة أخرى في مجلدات smartfriend
  "/opt/smartfriend-suite/cognitive_system/memory/smartfriend_memory.db"
  "/opt/smartfriend-suite/data/neural_memory.db"
  "/opt/smartfriend-suite/data/legacy_memory.db"
)

# أنماط النسخ الاحتياطية للحذف
BACKUP_PATTERNS=(
  "*.bak_*"
  "*.backup_*"
  "*.old_*"
  "*.legacy_*"
  "*.prev_*"
  "*_backup_*"
  "*_old_*"
  "*_legacy_*"
  "memory.db.bak_*"
  "smart_core_memory.db.bak_*"
  "unified_memory.db.bak_*"
  "active_memory.db.bak_*"
)

# إنشاء مجلد النسخ الاحتياطية
mkdir -p "$BACKUP_DIR"

log "[1] فحص القواعد المستهدفة للحذف..."

ALL_TARGETS=()

# إضافة القواعد الرئيسية المستهدفة
for db in "${TARGET_DBS[@]}"; do
  if [ -e "$db" ]; then
    ALL_TARGETS+=("$db")
    log "✅ وجد: $db"
  else
    log "⏭️  غير موجود: $db"
  fi
done

# إضافة النسخ الاحتياطية
for pattern in "${BACKUP_PATTERNS[@]}"; do
  while IFS= read -r -d $'\0' file; do
    ALL_TARGETS+=("$file")
    log "✅ وجد: $file"
  done < <(find /opt/smartfriend-suite /opt/BRAIN_CORE /opt/ffactory -name "$pattern" -type f -print0 2>/dev/null || true)
done

# البحث عن أي قواعد بيانات أخرى غير معروفة
while IFS= read -r -d $'\0' file; do
  # استبعاد القواعد التي يجب الاحتفاظ بها
  keep=0
  for keep_db in "${KEEP_DBS[@]}"; do
    if [[ "$file" == "$keep_db" ]]; then
      keep=1
      break
    fi
  done
  
  if [[ $keep -eq 0 ]] && [[ "$file" == *.db ]]; then
    ALL_TARGETS+=("$file")
    log "🔍 قاعدة إضافية: $file"
  fi
done < <(find /opt/smartfriend-suite /opt/BRAIN_CORE /opt/ffactory -name "*.db" -type f -print0 2>/dev/null || true)

if [ "${#ALL_TARGETS[@]}" -eq 0 ]; then
  log "🎉 لا توجد قواعد بيانات قديمة للتنظيف!"
  exit 0
fi

log "عدد الملفات المستهدفة: ${#ALL_TARGETS[@]}"

echo
log "=== القواعد التي سيتم الاحتفاظ بها ==="
for db in "${KEEP_DBS[@]}"; do
  if [ -e "$db" ]; then
    log "✅ محفوظ: $db"
  fi
done

echo
log "=== الملفات المستهدفة للحذف ==="
for target in "${ALL_TARGETS[@]}"; do
  ls -lh "$target" 2>/dev/null || echo "❌ لا يمكن الوصول: $target"
done

echo
log "إجمالي الحجم الذي سيتم تحريره:"
du -ch "${ALL_TARGETS[@]}" 2>/dev/null | grep total || true

case "$MODE" in
  list)
    log ""
    log "📋 وضع المعاينة فقط - لم يتم حذف أي شيء"
    log "للتفيذ الفعلي، شغل: bash $0 delete"
    ;;

  delete)
    log ""
    log "🗑️  بدأ الحذف الفعلي..."
    
    # نسخ احتياطي قبل الحذف
    log "[2] عمل نسخ احتياطية..."
    for target in "${ALL_TARGETS[@]}"; do
      if [ -f "$target" ]; then
        backup_path="$BACKUP_DIR/$(basename "$target").${TS}.backup"
        cp -a "$target" "$backup_path" && log "✅ نسخ احتياطي: $(basename "$target")"
      fi
    done
    
    # الحذف الفعلي
    log "[3] حذف الملفات..."
    for target in "${ALL_TARGETS[@]}"; do
      if [ -e "$target" ]; then
        rm -f -- "$target" && log "✅ حذف: $target" || log "❌ فشل حذف: $target"
      fi
    done
    
    # تنظيف المجلدات الفارغة
    log "[4] تنظيف المجلدات الفارغة..."
    find /opt/smartfriend-suite /opt/BRAIN_CORE /opt/ffactory -type d -empty -delete 2>/dev/null || true
    
    log "[5] التحقق من الهيكل النهائي..."
    log "=== القواعد المتبقية ==="
    find /opt/smartfriend-suite /opt/BRAIN_CORE /opt/ffactory -name "*.db" -type f 2>/dev/null | while read -r db; do
      log "📁 $db"
    done
    
    log "✅ تم الانتهاء من التنظيف الشامل"
    log "📦 النسخ الاحتياطية محفوظة في: $BACKUP_DIR"
    ;;

  *)
    log "استخدام غير صحيح"
    echo "Usage:"
    echo "  bash $0 list     # معاينة الملفات المستهدفة"
    echo "  bash $0 delete   # الحذف الفعلي مع نسخ احتياطي"
    exit 1
    ;;
esac

echo
log "===== الهيكل النهائي بعد التنظيف ====="
log "🧠 الذاكرة التشغيلية:"
log "  - active_memory.db (الرئيسية)"
log "  - memory.db (رابط)"
log "  - smart_core_memory.db (رابط)"
log ""
log "📚 قاعدة المعرفة:"
log "  - smartfriend_unified.db (الكوربس الرئيسي)"
log ""
log "⚡ الخدمات النشطة:"
log "  - sf-memory.service → active_memory.db"
log "  - sf-unified.service → unified API"
log "  - sf-health.service → health monitoring"
log "  - sf-bot.service → telegram bot"
log "===== DONE ====="
