#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }

APP_ROOT="/opt/smartfriend-suite"
APP_APP="$APP_ROOT/smartfriend/app"
VENV_PY="$APP_ROOT/smartfriend/venv/bin/python"

log "=== SmartFrind Reflector Deep Debug ==="
echo

########################################
log "1) Environment من systemd لـ smartfrind-reflector.service ..."
echo "----- systemd Environment -----"
systemctl show smartfrind-reflector.service -p Environment | sed 's/^Environment=//' || true
echo

########################################
log "2) قراءة smartfrind.config.DB من داخل venv ..."
cd "$APP_APP"

"$VENV_PY" <<'PY'
import os, sqlite3, traceback
from smartfrind import config

DB = getattr(config, "DB", None)
print(">> smartfrind.config.DB =", repr(DB))

if not DB:
    print("!! DB فارغة أو غير معرّفة في config")
else:
    print(">> abs(DB) =", os.path.abspath(DB))
    print(">> exists:", os.path.exists(DB))
    parent = os.path.dirname(DB)
    print(">> parent dir:", parent, "exists:", os.path.isdir(parent))
    try:
        if os.path.exists(DB):
            st = os.stat(DB)
            print(">> perms (oct):", oct(st.st_mode)[-4:], "owner:", st.st_uid, "group:", st.st_gid)
    except Exception as e:
        print("!! stat error:", repr(e))

    print("\n>> تجربة sqlite3.connect(DB)...")
    try:
        con = sqlite3.connect(DB, check_same_thread=False)
        cur = con.execute("SELECT name FROM sqlite_master WHERE type='table' LIMIT 5")
        print(">> connect OK, sample tables:", [r[0] for r in cur.fetchall()])
        con.close()
    except Exception as e:
        print("!! sqlite3.connect ERROR:", repr(e))
        traceback.print_exc()
PY

echo
########################################
log "3) تشغيل reflector.py يدويًا بنفس WorkingDirectory ..."
cd "$APP_APP"
echo "----- python bin/reflector.py -----"
/opt/smartfriend-suite/smartfriend/venv/bin/python bin/reflector.py || error "reflector.py exited with non-zero"
echo

########################################
log "4) عرض حالة smartfrind-reflector.service بعد الفحص (للتحقق فقط) ..."
systemctl --no-pager -l status smartfrind-reflector.service || true

log '=== انتهى sf_debug_reflector ==='
