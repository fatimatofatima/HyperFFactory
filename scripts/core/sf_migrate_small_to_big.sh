#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

SMALL_DB="/opt/smartfriend-suite/data/smartfriend_unified.db"
BIG_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
BACKUP_DIR="/opt/smartfriend-suite/var/db/backup_migration"

log "=== SmartFriend – ترحيل آمن من الصغيرة → الكبيرة (data → var/db) ==="

# 0) فحص وجود الملفات
if [ ! -f "$SMALL_DB" ]; then
  error "قاعدة البيانات الصغيرة غير موجودة: $SMALL_DB"
  exit 1
fi

if [ ! -f "$BIG_DB" ]; then
  error "قاعدة البيانات الكبيرة غير موجودة: $BIG_DB"
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  error "sqlite3 غير مثبت – لا يمكن المتابعة."
  exit 1
fi

# 1) نسخ احتياطي للطرفين
log "1) إنشاء نسخ احتياطية للطرفين ..."
mkdir -p "$BACKUP_DIR"
cp "$SMALL_DB" "$BACKUP_DIR/small_$(date +%Y%m%d_%H%M%S).db"
cp "$BIG_DB"   "$BACKUP_DIR/big_$(date +%Y%m%d_%H%M%S).db"
success "   ✅ تم حفظ نسخ احتياطية في: $BACKUP_DIR"

# 2) إيقاف الخدمات التي تكتب على unified DB (احترازيًا)
log "2) إيقاف الخدمات المرتبطة بقاعدة unified (احترازيًا) ..."
for svc in \
  smartfrind-reflector.service \
  smartfrind-ingest.service \
  smartfrind-harvest.service \
  smartfrind-raw-clean.service \
  smartfriend-api.service \
  smartfrind-api.service \
  sf-core.service
do
  systemctl stop "$svc" 2>/dev/null || true
done
success "   ✅ تم إرسال أوامر إيقاف للخدمات الحرجة (إن وجدت)"

# 3) عرض إحصائيات أولية قبل الدمج
log "3) إحصائيات قبل الدمج:"
SMALL_SIZE=$(du -h "$SMALL_DB" | awk '{print $1}')
BIG_SIZE=$(du -h "$BIG_DB"   | awk '{print $1}')
SMALL_TABLES=$(sqlite3 "$SMALL_DB" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
BIG_TABLES=$(sqlite3 "$BIG_DB" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")

echo "   • حجم الصغيرة: $SMALL_SIZE  – جداول: $SMALL_TABLES"
echo "   • حجم الكبيرة: $BIG_SIZE    – جداول: $BIG_TABLES"

if [ "$SMALL_TABLES" -eq 0 ]; then
  warn "   ⚠️ قاعدة البيانات الصغيرة لا تحتوي جداول فعلية، لا حاجة للدمج."
  success "   ✅ لا شيء يُنفذ على البيانات. يمكنك اعتماد var/db مباشرة."
  exit 0
fi

# 4) بناء سكربت دمج ديناميكي (per-table INSERT OR IGNORE)
log "4) بناء سكربت دمج ديناميكي لكل الجداول (INSERT OR IGNORE) ..."
MERGE_SQL=$(
  sqlite3 "$SMALL_DB" "
    SELECT name
    FROM sqlite_master
    WHERE type='table'
      AND name NOT LIKE 'sqlite_%'
    ORDER BY name;
  " | while read -r T; do
        [ -z "$T" ] && continue
        echo "INSERT OR IGNORE INTO \"$T\" SELECT * FROM small.\"$T\";"
      done
)

if [ -z "$MERGE_SQL" ]; then
  warn "   ⚠️ لم يتم العثور على جداول قابلة للدمج في الصغيرة."
  success "   ✅ لا شيء يُنفذ على البيانات. يمكنك اعتماد var/db مباشرة."
  exit 0
fi

# 5) تنفيذ الدمج داخل الكبيرة مع ATTACH
log "5) تنفيذ عملية الدمج داخل BIG_DB (قد يستغرق بعض الوقت حسب حجم البيانات) ..."
sqlite3 "$BIG_DB" <<SQL
ATTACH '$SMALL_DB' AS small;
PRAGMA foreign_keys = OFF;
BEGIN;
$MERGE_SQL
COMMIT;
DETACH small;
SQL

success "   ✅ تم تنفيذ الدمج من الصغيرة → الكبيرة بنجاح."

# 6) ضبط الصلاحيات على BIG_DB (احترازيًا)
log "6) ضبط صلاحيات BIG_DB بعد الدمج ..."
chown smartfriend-suite:smartfriend-suite "$BIG_DB" 2>/dev/null || true
chmod 664 "$BIG_DB" || true
success "   ✅ تم ضبط الصلاحيات (قدر الإمكان)."

# 7) إعادة تشغيل الخدمات الأساسية
log "7) إعادة تشغيل الخدمات الأساسية ..."
for svc in \
  sf-core.service \
  smartfriend-api.service \
  smartfrind-api.service \
  smartfrind-ingest.service \
  smartfrind-harvest.service \
  smartfrind-reflector.service \
  smartfrind-raw-clean.service
do
  systemctl start "$svc" 2>/dev/null || true
done

success "=== اكتملت عملية الدمج (small → big). القاعدة الرسمية الآن هي BIG_DB في var/db. ==="
echo "📁 BIG_DB النهائي: $BIG_DB"
echo "💾 النسخ الاحتياطية في: $BACKUP_DIR"
