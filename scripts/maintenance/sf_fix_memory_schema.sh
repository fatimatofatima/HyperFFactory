#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%F %T')] [WARN] ${NC}$*" >&2; }
error() { echo -e "${RED}[$(date '+%F %T')] [ERROR] ${NC}$*" >&2; }
ok()    { echo -e "${GREEN}[$(date '+%F %T')] [OK] ${NC}$*"; }

DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP="/root/smartfriend_unified.db.before_schema_fix.${TS}"

if [[ ! -f "$DB" ]]; then
  error "قاعدة البيانات غير موجودة عند: $DB"
  exit 1
fi

log "=== إصلاح سكيمة smartfriend_unified.db (إضافة الجداول/الأعمدة الناقصة) ==="
log "قاعدة البيانات: $DB"

log "1) إنشاء نسخة احتياطية قبل أي تعديل: $BACKUP"
cp -p "$DB" "$BACKUP"
ok "تم إنشاء النسخة الاحتياطية."

log "2) إضافة العمود deleted_at إلى knowledge_base (إن لم يكن موجوداً)..."
sqlite3 "$DB" "ALTER TABLE knowledge_base ADD COLUMN deleted_at TIMESTAMP" 2>/dev/null || \
  warn "قد يكون العمود deleted_at موجوداً بالفعل في knowledge_base (تجاهل الخطأ إذا ظهر)."

log "3) إنشاء جدول interactions إذا لم يكن موجوداً..."
sqlite3 "$DB" "
CREATE TABLE IF NOT EXISTS interactions (
    id        INTEGER PRIMARY KEY,
    user_id   TEXT,
    role      TEXT,
    content   TEXT,
    timestamp TIMESTAMP,
    meta      JSON
);" || error "فشل إنشاء/تأكيد جدول interactions."

log "4) إنشاء جدول summaries إذا لم يكن موجوداً..."
sqlite3 "$DB" "
CREATE TABLE IF NOT EXISTS summaries (
    id         INTEGER PRIMARY KEY,
    user_id    TEXT,
    scope      TEXT,
    text       TEXT,
    coverage   TEXT,
    created_at TIMESTAMP
);" || error "فشل إنشاء/تأكيد جدول summaries."

log "5) إنشاء جدول state إذا لم يكن موجوداً..."
sqlite3 "$DB" "
CREATE TABLE IF NOT EXISTS state (
    id                INTEGER PRIMARY KEY,
    last_reflection_at TIMESTAMP,
    last_harvest_at    TIMESTAMP,
    last_ingest_at     TIMESTAMP
);" || error "فشل إنشاء/تأكيد جدول state."

log "6) إنشاء فهارس أساسية لتسريع الاستعلامات..."
sqlite3 "$DB" "CREATE INDEX IF NOT EXISTS idx_interactions_timestamp ON interactions(timestamp);" 2>/dev/null || true
sqlite3 "$DB" "CREATE INDEX IF NOT EXISTS idx_summaries_scope ON summaries(scope);" 2>/dev/null || true

log "7) تأكيد وجود صف واحد في جدول state (id=1)..."
count_state=$(sqlite3 "$DB" "SELECT COUNT(*) FROM state WHERE id=1;")
if [[ "$count_state" -eq 0 ]]; then
  sqlite3 "$DB" "
    INSERT INTO state(id,last_reflection_at,last_harvest_at,last_ingest_at)
    VALUES(1,NULL,NULL,NULL);
  " || warn "لم نتمكن من إدخال صف في state، تحقق يدوياً."
else
  ok "صف الحالة (id=1) موجود بالفعل في state."
fi

ok "اكتمل إصلاح السكيمة. النسخة الاحتياطية في: $BACKUP"
