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

BASE_DIR="/opt/smartfriend-suite"
APP_DIR="$BASE_DIR/smartfriend"
APP_APP="$APP_DIR/app"
REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"

log "=== SmartFriend Suite – Memory/Harvest/DB Permissions Fix (Stage2) ==="
echo

########################################################################
# 1) تجهيز مجلدات البيانات الأساسية
########################################################################
log "1) تجهيز مجلدات البيانات تحت $BASE_DIR/data ..."
DATA_DIRS=(
  "$BASE_DIR/data"
  "$BASE_DIR/data/raw"
  "$BASE_DIR/data/harvest"
  "$BASE_DIR/data/archive"
  "$BASE_DIR/data/archive/raw"
  "$BASE_DIR/data/logs"
)

for d in "${DATA_DIRS[@]}"; do
  if [ ! -d "$d" ]; then
    log "   • إنشاء المجلد: $d"
    mkdir -p "$d"
  fi
  chmod 775 "$d" || warn "   • فشل chmod 775 على $d"
done
success "   ✓ مجلدات البيانات موجودة وبصلاحيات 775 (rwxrwxr-x)."

########################################################################
# 2) إصلاح صلاحيات ملفات الـ .db ومجلداتها
########################################################################
log "2) فحص وإصلاح صلاحيات ملفات .db داخل $BASE_DIR (عمق 7)..."
DB_LIST_FILE="$REPORT_DIR/db_list_$(date +%Y%m%d_%H%M%S).txt"
: > "$DB_LIST_FILE"

find "$BASE_DIR" -maxdepth 7 -type f -name '*.db' 2>/dev/null | sort | tee -a "$DB_LIST_FILE" || true

if [ ! -s "$DB_LIST_FILE" ]; then
  warn "   • لم يتم العثور على أي ملف .db داخل $BASE_DIR (ربما DB في مسار آخر)."
else
  while IFS= read -r dbf; do
    [ -z "$dbf" ] && continue
    dbdir="$(dirname "$dbf")"
    log "   • ضبط الصلاحيات للـ DB: $dbf (dir: $dbdir)"
    chmod 664 "$dbf"   || warn "      - فشل chmod 664 على $dbf"
    chmod 775 "$dbdir" || warn "      - فشل chmod 775 على $dbdir"
  done < "$DB_LIST_FILE"
  success "   ✓ تم ضبط صلاحيات ملفات .db ومجلداتها (664 للملفات، 775 للمجلدات)."
fi

########################################################################
# 3) إجبار خدمات الذاكرة/الهارفست على العمل كـ root + WorkingDirectory صحيح
########################################################################
log "3) إنشاء drop-in لتشغيل خدمات الذاكرة كـ root وبـ WorkingDirectory=$APP_APP ..."

MEM_SERVICES=(
  smartfrind-harvest
  smartfrind-ingest
  smartfrind-raw-clean
  smartfrind-reflector
)

for svc in "${MEM_SERVICES[@]}"; do
  UNIT_DIR="/etc/systemd/system/${svc}.service.d"
  mkdir -p "$UNIT_DIR"
  DROPIN="$UNIT_DIR/30-run-as-root.conf"

  cat > "$DROPIN" <<'EOC'
[Service]
User=root
Group=root
WorkingDirectory=/opt/smartfriend-suite/smartfriend/app
EOC

  log "   • تم إنشاء/تحديث drop-in: $DROPIN"
done
success "   ✓ تم تجهيز drop-ins لخدمات الذاكرة."

########################################################################
# 4) daemon-reload + restart الخدمات ومراجعة الحالة
########################################################################
log "4) systemctl daemon-reload ..."
systemctl daemon-reload
success "   ✓ daemon-reload تم."

log "5) إعادة تشغيل الخدمات المستهدفة + طباعة حالة مختصرة:"
for svc in "${MEM_SERVICES[@]}"; do
  sep
  log "   ▸ الخدمة: ${svc}.service"
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    if systemctl restart "${svc}.service"; then
      success "      - restart ناجح لـ ${svc}.service"
    else
      warn "      - restart فشل لـ ${svc}.service"
    fi
    echo "      - حالة مختصرة:" 
    systemctl --no-pager -l --lines=10 status "${svc}.service" || true
  else
    warn "      - ${svc}.service غير موجودة في systemd (list-unit-files)."
  fi
done
sep
success "انتهى Stage2 – إصلاح صلاحيات الذاكرة/الهارفست/DB. راجع الرسائل أعلاه لأي تحذيرات."
