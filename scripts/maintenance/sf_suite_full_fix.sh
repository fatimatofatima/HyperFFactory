#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان بسيطة للّوج
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
VENV_DIR="$APP_DIR/venv"

REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"

fix_dir_perm() {
  local d="$1"
  if [ -d "$d" ]; then
    chmod 755 "$d" || warn "فشل chmod 755 على $d"
  fi
}

log "=== SmartFriend Suite – Full Memory/Harvest/DB Fix ==="
echo

########################################################################
# 1) إصلاح صلاحيات المجلدات الأساسية لمنع CHDIR Permission denied
########################################################################
log "1) إصلاح صلاحيات /opt/smartfriend-suite ومساراتها الأساسية..."
fix_dir_perm "/opt"
fix_dir_perm "$BASE_DIR"
fix_dir_perm "$APP_DIR"
fix_dir_perm "$APP_APP"
fix_dir_perm "$BASE_DIR/gateway"
fix_dir_perm "$BASE_DIR/data"

echo

########################################################################
# 2) ضبط مسار قاعدة البيانات المستخدمة في smartfrind/db.py
########################################################################
DB_PY="$APP_APP/smartfrind/db.py"

if [ -f "$DB_PY" ]; then
  log "2) محاولة استخراج مسار DB من $DB_PY ..."
  DB_LINE="$(grep -E 'DB\s*=' "$DB_PY" | head -n1 || true)"
  if [ -n "$DB_LINE" ]; then
    DB_PATH="$(printf '%s\n' "$DB_LINE" | sed -E "s/.*DB\s*=\s*['\"]([^'\"]+)['\"].*/\1/")"
    if [ -n "$DB_PATH" ]; then
      DB_DIR="$(dirname "$DB_PATH")"
      log "   • DB_PATH = $DB_PATH"
      log "   • DB_DIR  = $DB_DIR"

      if [ ! -d "$DB_DIR" ]; then
        log "   • إنشاء مجلد DB_DIR..."
        mkdir -p "$DB_DIR" || warn "فشل mkdir لـ $DB_DIR"
      fi

      chmod 775 "$DB_DIR" || warn "فشل chmod 775 على $DB_DIR"
    else
      warn "   لم أستطع تحليل مسار DB من السطر: $DB_LINE"
    fi
  else
    warn "   لم أجد سطر DB = في $DB_PY"
  fi
else
  warn "   ملف $DB_PY غير موجود، تخطّي خطوة ضبط DB."
fi

echo

########################################################################
# 3) إصلاح smartfrind-learner.service (WorkingDirectory + net_learner.py)
########################################################################
LEARNER_UNIT="/etc/systemd/system/smartfrind-learner.service"

if [ -f "$LEARNER_UNIT" ]; then
  log "3) إصلاح smartfrind-learner.service ..."

  # 3.1) إزالة WorkingDirectory من قسم [Install] لو موجود
  if grep -q "^\[Install\]" "$LEARNER_UNIT"; then
    sed -i '/^\[Install\]/,/^\[/ s/^\(WorkingDirectory=.*\)$/#\1/' "$LEARNER_UNIT" || \
      warn "   تعذّر تعديل WorkingDirectory داخل [Install] في $LEARNER_UNIT"
  fi

  # 3.2) محاولة اكتشاف net_learner.py تلقائيًا
  log "   • البحث عن net_learner.py داخل $BASE_DIR (عمق 6)..."
  NET_LEARNER="$(find "$BASE_DIR" -maxdepth 6 -type f -name 'net_learner.py' 2>/dev/null | head -n1 || true)"

  if [ -z "$NET_LEARNER" ]; then
    warn "   لم أجد net_learner.py – سيتم الاكتفاء بإزالة WorkingDirectory الخاطئ في [Install]."
  else
    log "   • تم العثور على: $NET_LEARNER"

    if [ ! -x "$VENV_DIR/bin/python" ]; then
      warn "   venv python غير موجود أو غير قابل للتنفيذ: $VENV_DIR/bin/python – لن أعيد كتابة الـ unit."
    else
      # استخراج User من الـ unit القديم (إن وجد)
      UNIT_USER_LINE="$(grep -E '^User=' "$LEARNER_UNIT" | head -n1 || true)"
      UNIT_USER="${UNIT_USER_LINE#User=}"
      [ -z "$UNIT_USER" ] && UNIT_USER="root"

      LEARNER_DIR="$(dirname "$NET_LEARNER")"

      log "   • إعادة كتابة $LEARNER_UNIT باستخدام المسار المكتشف و User=$UNIT_USER ..."
      cat > "$LEARNER_UNIT" <<EOFUNIT
[Unit]
Description=SmartFrind Net Learner (web→KB)
After=network.target smartfrind-api.service

[Service]
Type=simple
WorkingDirectory=$LEARNER_DIR
ExecStart=$VENV_DIR/bin/python $NET_LEARNER
Restart=always
User=$UNIT_USER
Group=$UNIT_USER

[Install]
WantedBy=multi-user.target
EOFUNIT

    fi
  fi
else
  warn "3) ملف smartfrind-learner.service غير موجود، تخطّي هذه الخطوة."
fi

echo

########################################################################
# 4) إعادة تحميل systemd
########################################################################
log "4) systemctl daemon-reload ..."
systemctl daemon-reload || warn "فشل daemon-reload، تأكد من عدم وجود أخطاء في ملفات الوحدات."

echo

########################################################################
# 5) Restart + Status للخدمات الخاصة بالذاكرة والهارفست
########################################################################
log "5) إعادة تشغيل وفحص الخدمات التالية:"

SERVICES=(
  smartfrind-harvest.service
  smartfrind-ingest.service
  smartfrind-learner.service
  smartfrind-learning-agent.service
  smartfrind-raw-clean.service
  smartfrind-reflector.service
)

for SVC in "${SERVICES[@]}"; do
  sep
  log "   ▸ الخدمة: $SVC"

  if ! systemctl list-unit-files "$SVC" >/dev/null 2>&1; then
    warn "   • $SVC غير معرّفة في systemd (list-unit-files). تخطّي."
    continue
  fi

  log "   • محاولة restart ..."
  if systemctl restart "$SVC" 2>/dev/null; then
    success "   • restart نجح لـ $SVC"
  else
    warn "   • restart فشل لـ $SVC – راجع journalctl -u $SVC -n 50"
  fi

  log "   • آخر حالة (status مختصر):"
  systemctl --no-pager -n 5 status "$SVC" || true
done

sep
success "انتهى سكربت الفحص والإصلاح الكامل لخط الذاكرة/الهارفست/DB في SmartFriend Suite."
echo "لو أي خدمة ما زالت فاشلة، شغّل مثلاً:"
echo "  journalctl -u smartfrind-reflector.service -n 50 --no-pager"
