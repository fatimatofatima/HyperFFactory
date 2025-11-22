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
sep()    { echo -e "${YELLOW}────────────────────────────────────────────────────${NC}"; }

APP_APP="/opt/smartfriend-suite/smartfriend/app"
DATA_BASE="/opt/smartfriend-suite/data"
VAR_DB="/opt/smartfriend-suite/var/db"

log "=== SmartFriend Suite – Memory DB & Code Fix (Stage3) ==="
echo

###############################################################################
# 1) إصلاح صلاحيات الكود smartfrind/* (بما فيها ingest_agent.py)
###############################################################################
log "1) إصلاح صلاحيات smartfrind package داخل السويت..."

if [ -d "$APP_APP/smartfrind" ]; then
    chmod -R u+rwX,go+rX "$APP_APP/smartfrind" || warn "   تعذر ضبط صلاحيات smartfrind/*"
    success "   تم ضبط صلاحيات smartfrind/* (u+rwX,go+rX)."
    ls -l "$APP_APP/smartfrind/ingest_agent.py" || true
else
    warn "   مجلد $APP_APP/smartfrind غير موجود."
fi

###############################################################################
# 2) استخراج مسار DB من db.py وإنشاءه إن لزم
###############################################################################
log "2) قراءة مسار قاعدة البيانات من db.py ومحاولة تهيئتها..."

DB_PY="$APP_APP/smartfrind/db.py"
DB_PATH=""

if [ -f "$DB_PY" ]; then
    DB_PATH=$(python3 <<'PY'
import re, os, sys
p = "/opt/smartfriend-suite/smartfriend/app/smartfrind/db.py"
try:
    txt = open(p, "r", encoding="utf-8").read()
except Exception:
    sys.exit(0)

m = re.search(r"DB\s*=\s*['\"]([^'\"]+)['\"]", txt)
if not m:
    sys.exit(0)
val = m.group(1).strip()

# لو المسار نسبي، نخليه تحت /opt/smartfriend-suite/data
if not os.path.isabs(val):
    val = os.path.join("/opt/smartfriend-suite/data", val)

print(val)
PY
    ) || true

    if [ -n "$DB_PATH" ]; then
        success "   مسار DB في db.py: $DB_PATH"
        DB_DIR="$(dirname "$DB_PATH")"

        mkdir -p "$DB_DIR" || warn "   تعذر إنشاء مجلد DB: $DB_DIR"
        chmod 775 "$DB_DIR" || true

        if [ ! -f "$DB_PATH" ]; then
            log "   إنشاء ملف قاعدة البيانات: $DB_PATH"
            : > "$DB_PATH" || warn "   تعذر إنشاء الملف $DB_PATH"
        fi

        chmod 664 "$DB_PATH" || warn "   تعذر ضبط صلاحيات $DB_PATH"
        success "   تم ضمان وجود ملف DB والصلاحيات المناسبة."
    else
        warn "   لم أستطع استخراج DB= من db.py، سأهيئ المسارات الشائعة يدويًا."
    fi
else
    warn "   ملف db.py غير موجود في: $DB_PY"
fi

###############################################################################
# 3) تهيئة مسارات قواعد البيانات الشائعة احتياطيًا
###############################################################################
log "3) تهيئة بعض مسارات قواعد البيانات الشائعة (احتياطيًا)..."

mkdir -p "$DATA_BASE" "$DATA_BASE/db" "$VAR_DB" || true
chmod 775 "$DATA_BASE" "$DATA_BASE/db" "$VAR_DB" 2>/dev/null || true

for db in \
  "$DATA_BASE/memory.db" \
  "$DATA_BASE/smart_core_memory.db" \
  "$DATA_BASE/smartfriend_unified.db" \
  "$DATA_BASE/db/memory.db" \
  "$DATA_BASE/db/smartfriend_unified.db" \
  "$VAR_DB/memory.db" \
  "$VAR_DB/active_memory.db" \
  "$VAR_DB/smartfriend_unified.db"
do
  dir=$(dirname "$db")
  mkdir -p "$dir" 2>/dev/null || true
  chmod 775 "$dir" 2>/dev/null || true
  [ -f "$db" ] || : > "$db"
  chmod 664 "$db" 2>/dev/null || true
done
success "   تم تهيئة ملفات ومسارات DB الشائعة."

###############################################################################
# 4) إعادة تشغيل الخدمات الأربع وطباعة حالة مختصرة
###############################################################################
log "4) إعادة تشغيل خدمات خط الذاكرة/الهارفست..."

for svc in \
  smartfrind-harvest.service \
  smartfrind-ingest.service \
  smartfrind-raw-clean.service \
  smartfrind-reflector.service
do
  sep
  log "▸ إعادة تشغيل $svc ..."
  if systemctl restart "$svc"; then
      success "   restart نجح لـ $svc"
  else
      warn "   restart فشل لـ $svc"
  fi
  systemctl --no-pager -l status "$svc" | sed -n '1,18p' || true
done

sep
success "انتهى Stage3 – إصلاح كود ingest_agent وقاعدة بيانات smartfrind."
