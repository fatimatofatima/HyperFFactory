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
VENV_PY="$APP_ROOT/smartfriend/venv/bin/python"
CONFIG="$APP_APP/smartfrind/config.py"

CANON_DB="$APP_ROOT/var/db/smartfriend_unified.db"
DATA_DB="$APP_ROOT/data/smartfriend_unified.db"

log "=== SmartFriend – Final Reflector DB Fix (canonical var/db, no symlink) ==="
sep

########################################
log "1) ضمان وجود القاعدة الكَنونية وصلاحيات المسارات ..."

# مجلد var/db
mkdir -p "$APP_ROOT/var/db"
chown smartfriend-suite:smartfriend-suite "$APP_ROOT/var" "$APP_ROOT/var/db" 2>/dev/null || true
chmod 775 "$APP_ROOT/var" "$APP_ROOT/var/db" || true

# لو ما فيش ملف في CANON_DB لكن في DATA_DB → انسخه مرة واحدة
if [ ! -f "$CANON_DB" ] && [ -f "$DATA_DB" ]; then
  log "  • لا يوجد $CANON_DB لكن وجدت $DATA_DB → نسخ لمرة واحدة ..."
  cp "$DATA_DB" "$CANON_DB"
fi

if [ ! -f "$CANON_DB" ]; then
  error "  ❌ لا يوجد ملف قاعدة بيانات في $CANON_DB. توقف."
  exit 1
fi

# ضبط صلاحيات الملف الكَنوني
chown smartfriend-suite:smartfriend-suite "$CANON_DB" 2>/dev/null || true
chmod 664 "$CANON_DB" || true

log "  • CANON_DB: $CANON_DB"
ls -la "$CANON_DB" || true
sep

########################################
log "2) إعادة كتابة smartfrind.config.DB بشكل نظيف (env + fallback) ..."

python3 <<'PY'
import re, pathlib, textwrap, os

config_path = pathlib.Path("/opt/smartfriend-suite/smartfriend/app/smartfrind/config.py")
backup_path = config_path.with_suffix(".py.bak_final_db")

txt = config_path.read_text(encoding="utf-8")

# نسخة احتياطية
backup_path.write_text(txt, encoding="utf-8")

# ضمان وجود import os
if "import os" not in txt:
    txt = "import os\n" + txt

newline = (
    "DB = (os.environ.get('SMARTFRIND_DB') or "
    "os.environ.get('SMARTFRIEND_DB') or "
    "'/opt/smartfriend-suite/var/db/smartfriend_unified.db')\n"
)

if re.search(r'^DB\s*=.*$', txt, flags=re.M):
    txt = re.sub(r'^DB\s*=.*$', newline, txt, flags=re.M)
else:
    txt += "\n" + newline

config_path.write_text(txt, encoding="utf-8")
PY

success "  ✅ تم تحديث config.py + حفظ نسخة احتياطية"
sep

########################################
log "3) ضبط متغيرات البيئة في 20-smartfriend-env.conf لكل smartfrind-*.service ..."

for d in /etc/systemd/system/smartfrind-*.service.d; do
  [ -d "$d" ] || continue
  envf="$d/20-smartfriend-env.conf"
  if [ ! -f "$envf" ]; then
    cat > "$envf" <<EOF_ENV
[Service]
Environment=SMARTFRIND_DB=/opt/smartfriend-suite/var/db/smartfriend_unified.db
Environment=SMARTFRIEND_DB=/opt/smartfriend-suite/var/db/smartfriend_unified.db
EOF_ENV
  else
    # استبدال أي مسار قديم بـ var/db
    sed -i \
      -e 's|SMARTFRIND_DB=.*|SMARTFRIND_DB=/opt/smartfriend-suite/var/db/smartfriend_unified.db|' \
      -e 's|SMARTFRIEND_DB=.*|SMARTFRIEND_DB=/opt/smartfriend-suite/var/db/smartfriend_unified.db|' \
      "$envf"
  fi
  log "  • ضبط $envf"
done

systemctl daemon-reload
sep

########################################
log "4) اختبار فعلي لـ smartfrind.config.DB + sqlite3.connect داخل نفس venv/PYTHONPATH ..."

cd "$APP_APP"

PYTHONPATH="$APP_APP" \
SMARTFRIND_DB="$CANON_DB" \
SMARTFRIEND_DB="$CANON_DB" \
"$VENV_PY" - <<'PY'
import os, sqlite3
import smartfrind.config as c

print(">> smartfrind.config.DB =", repr(c.DB))
print(">> exists:", os.path.exists(c.DB))
print(">> access R:", os.access(c.DB, os.R_OK), "W:", os.access(c.DB, os.W_OK))

try:
    con = sqlite3.connect(c.DB, check_same_thread=False)
    cur = con.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' LIMIT 5;")
    print(">> sample tables:", [r[0] for r in cur.fetchall()])
    con.close()
    print(">> sqlite3.connect(DB) OK")
except Exception as e:
    print(">> sqlite3.connect(DB) FAILED:", repr(e))
    raise
PY

success "  ✅ اختبار connect داخل venv نجح"
sep

########################################
log "5) إعادة تشغيل smartfrind-reflector.service وعرض الحالة ..."

systemctl restart smartfrind-reflector.service || true
sleep 1
systemctl status smartfrind-reflector.service --no-pager -l || true

success "=== انتهى sf_final_fix_reflector_db ==="
