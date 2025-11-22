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

APP_ROOT="/opt/smartfriend-suite"
APP_APP="$APP_ROOT/smartfriend/app"
CONFIG="$APP_APP/smartfrind/config.py"

# القاعدة الكَنونية + fallback
CANON_DB="$APP_ROOT/var/db/smartfriend_unified.db"
FALLBACK_DB="$APP_ROOT/data/smartfriend_unified.db"

log "=== SmartFriend Suite – Reflector DB Fix v2 (path + env + file) ==="
echo

if [ ! -f "$CONFIG" ]; then
  error "لم أجد ملف config.py عند: $CONFIG"
  exit 1
fi

sep
log "1) اكتشاف مسار smartfriend_unified.db من config.py ..."

DB_PATH=""
if grep -q "smartfriend_unified.db" "$CONFIG"; then
  DB_PATH=$(grep -Eo "'/[^']*smartfriend_unified\.db'|\"/[^\"]*smartfriend_unified\.db\"" "$CONFIG" | head -n1 | tr -d "\"'")
fi

if [ -z "${DB_PATH:-}" ]; then
  warn "لم أجد smartfriend_unified.db صراحة في config.py، سأستخدم مسار افتراضي."
  if [ -f "$CANON_DB" ]; then
    DB_PATH="$CANON_DB"
  elif [ -f "$FALLBACK_DB" ]; then
    DB_PATH="$FALLBACK_DB"
  else
    DB_PATH="$CANON_DB"
  fi
fi

log "مسار DB الذي سيتم ضمانه (من config/افتراضي): $DB_PATH"
log "المسار الكَنوني (var/db): $CANON_DB"

sep
log "2) ضمان وجود قاعدة بيانات كَنونية في var/db ..."

mkdir -p "$(dirname "$CANON_DB")"

if [ -f "$CANON_DB" ]; then
  success "وجدت $CANON_DB موجود."
else
  if [ -f "$FALLBACK_DB" ]; then
    log "نسخ نسخة fallback من $FALLBACK_DB إلى $CANON_DB ..."
    cp -p "$FALLBACK_DB" "$CANON_DB"
    success "تم نسخ fallback إلى var/db."
  else
    warn "لا توجد أي نسخة مسبقة، سأعتمد على أن SQLite ينشئ الملف عند أول connect."
    # مجرد ضمان وجود الفولدر كفاية لعدم ظهور unable to open directory
  fi
fi

chown smartfriend-suite:smartfriend-suite "$CANON_DB" 2>/dev/null || true
chmod 664 "$CANON_DB" 2>/dev/null || true

sep
log "3) تحديث متغيرات البيئة SMARTFRIEND_DB/SMARTFRIND_DB لكل smartfrind-*.service ..."

for f in /etc/systemd/system/smartfrind-*.service.d/20-smartfriend-env.conf; do
  if [ -f "$f" ]; then
    log "تحديث $f ..."
    sed -i "s|^Environment=SMARTFRIEND_DB=.*|Environment=SMARTFRIEND_DB=$CANON_DB|" "$f" || true
    sed -i "s|^Environment=SMARTFRIND_DB=.*|Environment=SMARTFRIND_DB=$CANON_DB|" "$f" || true
  fi
done

sep
log "4) ربط مسار config.py بالمسار الكَنوني (إن اختلفا) ..."

DB_DIR="$(dirname "$DB_PATH")"
mkdir -p "$DB_DIR"

if [ "$DB_PATH" = "$CANON_DB" ]; then
  success "config يستخدم نفس مسار var/db بالفعل."
else
  if [ -e "$DB_PATH" ] && [ ! -L "$DB_PATH" ]; then
    warn "يوجد ملف فعلي عند $DB_PATH – أتركه كما هو (لن أحذفه أو أُعدّل عليه)."
  elif [ -L "$DB_PATH" ]; then
    warn "يوجد symlink موجود عند $DB_PATH – أتركه كما هو."
  else
    log "إنشاء رابط رمزي من الكَنوني إلى $DB_PATH ..."
    ln -s "$CANON_DB" "$DB_PATH"
    success "تم إنشاء symlink $DB_PATH → $CANON_DB."
  fi
fi

chown -h smartfriend-suite:smartfriend-suite "$DB_PATH" 2>/dev/null || true

sep
log "5) إعادة تحميل systemd وتشغيل smartfrind-reflector ..."

systemctl daemon-reload

if systemctl restart smartfrind-reflector.service; then
  success "تم إعادة تشغيل smartfrind-reflector.service بنجاح."
else
  warn "فشل restart لـ smartfrind-reflector، سيتم عرض الحالة للتشخيص."
fi

systemctl --no-pager -l status smartfrind-reflector.service || true

sep
success "اكتمل سكربت إصلاح Reflector DB v2."
