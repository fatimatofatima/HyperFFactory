#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

CANON_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
DATA_DB1="/opt/smartfriend-suite/data/db/smartfriend_unified.db"
DATA_DB2="/opt/smartfriend-suite/data/smartfriend_unified.db"

log "=== SmartFriend – Fix state/reflector + sf-spider CHDIR ==="
echo

########################################################################
# 1) توحيد قاعدة البيانات smartfriend_unified.db
########################################################################
if [ ! -f "$CANON_DB" ]; then
  error "القاعـدة الرسمية غير موجودة: $CANON_DB"
  exit 1
fi

log "1) القاعدة الرسمية:"
ls -lh "$CANON_DB" || true
echo

log "2) تجهيز مجلدات data/ و data/db ..."
mkdir -p /opt/smartfriend-suite/data/db

backup_if_real(){
  local p="$1"
  if [ -e "$p" ] && [ ! -L "$p" ]; then
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local bak="${p}.bak_${ts}"
    mv "$p" "$bak"
    warn "تم نقل النسخة القديمة: $p -> $bak"
  fi
}

backup_if_real "$DATA_DB1"
backup_if_real "$DATA_DB2"

log "3) إنشاء symlink من المسارات القديمة إلى القاعدة الرسمية ..."
ln -sfn ../../var/db/smartfriend_unified.db "$DATA_DB1"
ln -sfn ../var/db/smartfriend_unified.db "$DATA_DB2"

ls -l "$DATA_DB1" "$DATA_DB2" || true

log "4) ضبط صلاحيات القاعدة الرسمية ومجلد var/db ..."
chown smartfriend-suite:smartfriend-suite "$CANON_DB" || warn "فشل chown للـ DB (تجاهَل لو المالك مضبوط)."
chown smartfriend-suite:smartfriend-suite /opt/smartfriend-suite/var/db || true
chmod 660 "$CANON_DB" || true
chmod 770 /opt/smartfriend-suite/var/db || true

########################################################################
# 2) ضمان وجود جدول state + صف id=1 في القاعدة الرسمية
########################################################################
log "5) فحص/إنشاء جدول state في القاعدة الرسمية ..."
sqlite3 "$CANON_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY,
    last_reflection_at TIMESTAMP,
    last_harvest_at    TIMESTAMP,
    last_ingest_at     TIMESTAMP,
    meta               JSON
);

INSERT INTO state(id,last_reflection_at,last_harvest_at,last_ingest_at,meta)
    SELECT 1,NULL,NULL,NULL,NULL
    WHERE NOT EXISTS (SELECT 1 FROM state WHERE id=1);

UPDATE state
   SET last_reflection_at = COALESCE(last_reflection_at, CURRENT_TIMESTAMP)
 WHERE id = 1;
SQL

if sqlite3 "$CANON_DB" ".schema state" >/tmp/state_schema.$$ 2>/dev/null; then
  success "تم ضمان وجود جدول state + صف id=1 في القاعدة الرسمية."
  log "Schema state:"
  cat /tmp/state_schema.$$ || true
  rm -f /tmp/state_schema.$$
else
  warn "لم أستطع قراءة schema لـ state – افحص القاعدة يدويًا."
fi

########################################################################
# 3) إعادة تشغيل smartfrind-reflector على القاعدة الصحيحة
########################################################################
log "6) إعادة تشغيل smartfrind-reflector.service ..."
systemctl daemon-reload || true
systemctl restart smartfrind-reflector.service || warn "فشل restart لـ smartfrind-reflector.service"
systemctl status smartfrind-reflector.service --no-pager -n 20 || true

########################################################################
# 4) إصلاح sf-spider.service (CHDIR/WorkingDirectory)
########################################################################
SPIDER_UNIT="/etc/systemd/system/sf-spider.service"

echo
log "7) فحص/إصلاح sf-spider.service (WorkingDirectory + ExecStart)..."

if [ ! -f "$SPIDER_UNIT" ]; then
  warn "وحدة $SPIDER_UNIT غير موجودة – لا يوجد ما يُصلّح للـ spider."
else
  log "محتوى الوحدة قبل التعديل (مختصر):"
  head -n 40 "$SPIDER_UNIT" || true
  echo

  # ضبط WorkingDirectory
  CWD_LINE="$(grep -E '^WorkingDirectory=' "$SPIDER_UNIT" || true)"
  if [ -n "$CWD_LINE" ]; then
    CURRENT_CWD="${CWD_LINE#WorkingDirectory=}"
    if [ ! -d "$CURRENT_CWD" ]; then
      warn "WorkingDirectory الحالي غير صالح: $CURRENT_CWD – سيتم تغييره إلى /opt/smartfriend-suite"
      sed -i 's#^WorkingDirectory=.*#WorkingDirectory=/opt/smartfriend-suite#' "$SPIDER_UNIT"
    else
      log "WorkingDirectory الحالي موجود: $CURRENT_CWD (لن أغيّره)."
    fi
  else
    log "لا يوجد WorkingDirectory في [Service] – سيتم حقنه بـ /opt/smartfriend-suite"
    # إدراج بعد سطر [Service]
    sed -i '/^\[Service\]/a WorkingDirectory=/opt/smartfriend-suite' "$SPIDER_UNIT"
  fi

  # التأكد من وجود سكربت sf_spider_run.sh وتنفيذه
  SPIDER_SCRIPT=""
  if grep -q 'sf_spider_run.sh' "$SPIDER_UNIT"; then
    SPIDER_SCRIPT_PATH="$(grep 'sf_spider_run.sh' "$SPIDER_UNIT" | head -1 | sed 's/.*ExecStart=//')"
    SPIDER_SCRIPT="${SPIDER_SCRIPT_PATH%% *}"
  fi

  if [ -z "$SPIDER_SCRIPT" ]; then
    # لو مش مذكور بوضوح حاول استخدام bin أو scripts
    if [ -x /opt/smartfriend-suite/bin/sf_spider_run.sh ]; then
      SPIDER_SCRIPT="/opt/smartfriend-suite/bin/sf_spider_run.sh"
      sed -i 's#^ExecStart=.*sf_spider_run.sh.*#ExecStart=/opt/smartfriend-suite/bin/sf_spider_run.sh#' "$SPIDER_UNIT" || true
    elif [ -x /opt/smartfriend-suite/scripts/sf_spider_run.sh ]; then
      SPIDER_SCRIPT="/opt/smartfriend-suite/scripts/sf_spider_run.sh"
      sed -i 's#^ExecStart=.*sf_spider_run.sh.*#ExecStart=/opt/smartfriend-suite/scripts/sf_spider_run.sh#' "$SPIDER_UNIT" || true
    fi
  fi

  if [ -n "$SPIDER_SCRIPT" ] && [ -e "$SPIDER_SCRIPT" ]; then
    log "سكربت spider المستخدم: $SPIDER_SCRIPT"
    chmod +x "$SPIDER_SCRIPT" || warn "تعذر ضبط chmod +x على $SPIDER_SCRIPT"
  else
    warn "تعذر تحديد سكربت sf_spider_run.sh أو الملف غير موجود – راجع ExecStart يدويًا."
  fi

  # ضمان أن /opt/smartfriend-suite قابل للوصول
  chmod 755 /opt/smartfriend-suite || true

  log "إعادة تحميل systemd + إعادة تشغيل sf-spider.service ..."
  systemctl daemon-reload || true
  systemctl restart sf-spider.service || warn "فشل restart لـ sf-spider.service"
  systemctl status sf-spider.service --no-pager -n 30 || true
fi

echo
success "انتهى السكربت: توحيد smartfriend_unified.db + state + reflector + محاولة إصلاح sf-spider."
