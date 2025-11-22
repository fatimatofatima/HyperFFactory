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
VENV_PY="/opt/smartfriend-suite/smartfriend/venv/bin/python"

log "=== SmartFriend Suite – Reflector DB Path Auto-Fix ==="
echo

if [ ! -x "$VENV_PY" ]; then
    error "Python venv غير موجود أو غير قابل للتنفيذ: $VENV_PY"
    exit 1
fi

# 1) إنشاء سكربت بايثون صغير لاستخراج DB من smartfrind.db
log "1) إنشاء سكربت بايثون مساعد لاستخراج مسار DB من smartfrind.db ..."
cat > /root/_sf_show_db_path.py <<'PYEOF'
import sys
try:
    from smartfrind.db import DB
except Exception as e:
    print(f"ERROR:{e}", file=sys.stderr)
    sys.exit(1)
# اطبع المسار فقط
print(DB)
PYEOF

# 2) تشغيل سكربت بايثون واستخراج المسار
log "2) تشغيل سكربت قراءة DB داخل APP_APP لمعرفة المسار الحقيقي ..."
DB_PATH=""
pushd "$APP_APP" >/dev/null 2>&1 || {
    error f"لا يمكن الدخول إلى {APP_APP}"
    exit 1
}

DB_PATH="$("$VENV_PY" /root/_sf_show_db_path.py 2>/root/_sf_show_db_path.err || true)"
popd >/dev/null 2>&1 || true

if [ -z "$DB_PATH" ]; then
    error "لم أتمكّن من قراءة مسار DB من smartfrind.db. راجع /root/_sf_show_db_path.err"
    exit 1
fi

if echo "$DB_PATH" | grep -q '^ERROR:'; then
    error "فشل استيراد smartfrind.db: $DB_PATH"
    error "راسل محتوى /root/_sf_show_db_path.err لو لسه في مشكلة."
    exit 1
fi

log "   • مسار DB كما يراه الكود: '$DB_PATH'"

# 3) تحويل المسار إلى مطلق إذا كان نسبي
if [ "${DB_PATH:0:1}" != "/" ]; then
    # مسار نسبي، اعتبره نسبي لـ APP_APP
    ABS_DB_PATH="$APP_APP/$DB_PATH"
else
    ABS_DB_PATH="$DB_PATH"
fi

DB_DIR="$(dirname "$ABS_DB_PATH")"

log "3) تهيئة الدليل المستهدف: $DB_DIR"
mkdir -p "$DB_DIR"
chmod 775 "$DB_DIR" || warn "تعذّر ضبط صلاحيات $DB_DIR"

# 4) إنشاء ملف DB لو مش موجود + ضبط صلاحياته
if [ ! -f "$ABS_DB_PATH" ]; then
    log "   • إنشاء قاعدة البيانات الجديدة: $ABS_DB_PATH"
    : > "$ABS_DB_PATH"
else
    log "   • ملف قاعدة البيانات موجود مسبقًا."
fi

chmod 664 "$ABS_DB_PATH" || warn "تعذّر ضبط صلاحيات $ABS_DB_PATH"

success "تم تهيئة المسار الفعلي لقاعدة بيانات الـ Reflector:"
echo "   DB = $ABS_DB_PATH"

# 5) إعادة تشغيل خدمة الـ Reflector وطباعة الحالة
sep
log "5) إعادة تشغيل smartfrind-reflector.service ..."
if systemctl restart smartfrind-reflector.service 2>/tmp/sf_reflector_restart.err; then
    success "تم restart لـ smartfrind-reflector.service بنجاح."
else
    warn "فشل restart لـ smartfrind-reflector.service"
    warn "راجع: cat /tmp/sf_reflector_restart.err"
fi

sep
systemctl --no-pager -l status smartfrind-reflector.service || true

success "=== انتهى إصلاح Reflector DB Path ==="
