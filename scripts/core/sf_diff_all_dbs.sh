#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

CANON_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
SEARCH_ROOTS=(
  "/opt/smartfriend-suite"
  "/root"
)

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="/root/sf_db_diff_report_${TS}.txt"
TMP_DIR="/tmp/sf_db_diff_${TS}"
mkdir -p "$TMP_DIR"

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*" | tee -a "$REPORT"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" | tee -a "$REPORT" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" | tee -a "$REPORT" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*" | tee -a "$REPORT"; }

echo "==================================================================" > "$REPORT"
echo " SmartFriend – مقارنة قواعد البيانات القديمة مع الرسمية (unified)" >> "$REPORT"
echo " التاريخ: $(date '+%F %T')" >> "$REPORT"
echo "==================================================================" >> "$REPORT"
echo >> "$REPORT"

# 0) تحقق من وجود sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
  error "sqlite3 غير مثبت – لا يمكن إتمام الفحص."
  exit 1
fi

# 1) تحقق من وجود القاعدة الرسمية
if [ ! -f "$CANON_DB" ]; then
  error "قاعدة البيانات الرسمية غير موجودة: $CANON_DB"
  exit 1
fi

log "1) القاعدة الرسمية (الجديدة):"
ls -la "$CANON_DB" | tee -a "$REPORT"
echo >> "$REPORT"

# 2) جمع كل قواعد smartfriend_unified.db القديمة
log "2) البحث عن كل نسخ smartfriend_unified.db الأخرى تحت /opt/smartfriend-suite و /root ..."
CANDIDATES_FILE="$TMP_DIR/candidates.txt"
: > "$CANDIDATES_FILE"

for ROOT in "${SEARCH_ROOTS[@]}"; do
  if [ -d "$ROOT" ]; then
    find "$ROOT" -maxdepth 10 -type f -name 'smartfriend_unified.db' 2>/dev/null
  fi
done | sort -u | grep -v "^${CANON_DB}$" > "$CANDIDATES_FILE" || true

if ! [ -s "$CANDIDATES_FILE" ]; then
  warn "لا توجد قواعد بيانات أخرى بإسم smartfriend_unified.db (غير الرسمية). لا يوجد شيء للمقارنة."
  echo
  echo "📄 التقرير: $REPORT"
  exit 0
fi

log "تم العثور على النسخ التالية:"
cat "$CANDIDATES_FILE" | tee -a "$REPORT"
echo >> "$REPORT"

# 3) تجهيز schema القاعدة الرسمية
CANON_SCHEMA="$TMP_DIR/canon_schema.sql"
log "3) استخراج schema من القاعدة الرسمية ..."
if ! sqlite3 "$CANON_DB" ".schema" > "$CANON_SCHEMA"; then
  error "فشل في قراءة .schema من القاعدة الرسمية."
  exit 1
fi

# دالة مساعدة: إحضار عدد السجلات لجدول معيّن إن وجد
table_count() {
  local DB="$1"
  local TBL="$2"
  local EXISTS
  EXISTS="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='$TBL';" 2>/dev/null || true)"
  if [ -z "$EXISTS" ]; then
    echo "N/A"
  else
    sqlite3 "$DB" "SELECT COUNT(*) FROM \"$TBL\";" 2>/dev/null || echo "ERR"
  fi
}

# 4) مقارنة كل قاعدة قديمة مع القاعدة الرسمية
log "4) بدء المقارنات ..."
echo >> "$REPORT"

TABLES_TO_CHECK=(
  "knowledge_base"
  "interactions"
  "summaries"
  "state"
  "ai_memory"
  "memories"
  "memory_links"
  "bronze_pages"
  "silver_docs"
  "ingest_runs"
)

IDX=0
while IFS= read -r OLD_DB; do
  IDX=$((IDX+1))
  echo "------------------------------------------------------------------" >> "$REPORT"
  echo "[$IDX] مقارنة:" >> "$REPORT"
  echo "  OLD: $OLD_DB" >> "$REPORT"
  echo "  NEW: $CANON_DB" >> "$REPORT"
  echo "------------------------------------------------------------------" >> "$REPORT"

  if [ ! -f "$OLD_DB" ]; then
    warn "قاعدة قديمة مفقودة: $OLD_DB – سيتم تجاوزها."
    echo >> "$REPORT"
    continue
  fi

  # 4.1 – معلومات عامة عن الحجم
  echo "[A] معلومات عامة عن الحجم:" >> "$REPORT"
  du -h "$OLD_DB" "$CANON_DB" 2>/dev/null | sed 's/^/    /' >> "$REPORT"
  echo >> "$REPORT"

  # 4.2 – مقارنة قائمة الجداول
  echo "[B] مقارنة قائمة الجداول (.tables):" >> "$REPORT"
  OLD_TABLES="$TMP_DIR/old_tables_${IDX}.txt"
  NEW_TABLES="$TMP_DIR/new_tables_${IDX}.txt"

  sqlite3 "$OLD_DB" ".tables" 2>/dev/null | tr -s ' ' '\n' | sed '/^$/d' | sort > "$OLD_TABLES" || true
  sqlite3 "$CANON_DB" ".tables" 2>/dev/null | tr -s ' ' '\n' | sed '/^$/d' | sort > "$NEW_TABLES" || true

  echo "  - الجداول الموجودة في القديمة وغير موجودة في الجديدة:" >> "$REPORT"
  comm -23 "$OLD_TABLES" "$NEW_TABLES" | sed 's/^/      + /' >> "$REPORT" || echo "      (لا شيء)" >> "$REPORT"

  echo "  - الجداول الموجودة في الجديدة وغير موجودة في القديمة:" >> "$REPORT"
  comm -13 "$OLD_TABLES" "$NEW_TABLES" | sed 's/^/      + /' >> "$REPORT" || echo "      (لا شيء)" >> "$REPORT"

  echo >> "$REPORT"

  # 4.3 – diff كامل للـ schema
  echo "[C] فرق الـ schema (diff .schema):" >> "$REPORT"
  OLD_SCHEMA="$TMP_DIR/old_schema_${IDX}.sql"
  if sqlite3 "$OLD_DB" ".schema" > "$OLD_SCHEMA" 2>/dev/null; then
    diff -u "$CANON_SCHEMA" "$OLD_SCHEMA" >> "$REPORT" 2>/dev/null || echo "    (diff انتهى – قد لا توجد فروقات أو يوجد اختلاف بسيط)" >> "$REPORT"
  else
    echo "    [WARN] فشل في استخراج .schema من القاعدة القديمة." >> "$REPORT"
  fi
  echo >> "$REPORT"

  # 4.4 – مقارنة أعداد السجلات في الجداول المهمة
  echo "[D] مقارنة أعداد السجلات في الجداول المهمة:" >> "$REPORT"
  printf "    %-20s | %-12s | %-12s\n" "Table" "OLD_COUNT" "NEW_COUNT" >> "$REPORT"
  printf "    %-20s-+-%-12s-+-%-12s\n" "--------------------" "------------" "------------" >> "$REPORT"
  for TBL in "${TABLES_TO_CHECK[@]}"; do
    OLD_CNT="$(table_count "$OLD_DB" "$TBL")"
    NEW_CNT="$(table_count "$CANON_DB" "$TBL")"
    printf "    %-20s | %-12s | %-12s\n" "$TBL" "$OLD_CNT" "$NEW_CNT" >> "$REPORT"
  done
  echo >> "$REPORT"

done < "$CANDIDATES_FILE"

echo "==================================================================" >> "$REPORT"
echo "انتهت المقارنات. راجع التقرير أعلاه." >> "$REPORT"
echo "📄 مسار التقرير الكامل: $REPORT" >> "$REPORT"

success "اكتمل فحص كل قواعد smartfriend_unified.db القديمة ومقارنتها مع الرسمية."
echo
echo "📄 التقرير: $REPORT"
