#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ============================================================
# SmartFriend Full Stack Setup & Health Report (Read/Configure)
# - لا يقوم بحذف أي بيانات.
# - يفعّل فقط الخدمات التالية: smartfrind-learning, smartfriend-smartcore, smartfriend-unified
# ============================================================

TS="$(date +%Y%m%d_%H%M%S)"
APP_ROOT="/opt/smartfriend-suite"
SMARTFRIND_ROOT="/opt/smartfrind"
FF_ROOT="/opt/ffactory"
REPORT_ROOT="/root/sf_global_reports"
UNITS_BACKUP="/root/sf_units_backup_${TS}"

mkdir -p "$REPORT_ROOT" "$UNITS_BACKUP"
LOG="${REPORT_ROOT}/full_stack_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG" ; }
sec(){
  echo | tee -a "$LOG"
  echo "============================================================" | tee -a "$LOG"
  echo ">>> $*" | tee -a "$LOG"
  echo "============================================================" | tee -a "$LOG"
}

backup_unit(){
  local u="$1"
  local f="/etc/systemd/system/$u"
  if [ -f "$f" ]; then
    cp "$f" "$UNITS_BACKUP/$u"
    log "Backup للوحدة $u -> $UNITS_BACKUP/$u"
  else
    log "الوحدة $u غير موجودة (لا يوجد شيء لعمل Backup له)."
  fi
}

# ------------------------------------------------------------
# 0) ملخص المسارات
# ------------------------------------------------------------
sec "0) التحقق من المسارات الأساسية"

for d in "$APP_ROOT" "$SMARTFRIND_ROOT" "$FF_ROOT"; do
  if [ -d "$d" ]; then
    log "✓ موجود: $d"
  else
    log "✗ غير موجود: $d"
  fi
done

# ------------------------------------------------------------
# 1) فحص مختصر لـ /opt (بلا حذف)
# ------------------------------------------------------------
sec "1) ملخص /opt (مجلدات رئيسية فقط)"

if [ -d /opt ]; then
  find /opt -maxdepth 1 -type d ! -path "/opt" 2>/dev/null | sort | while read -r d; do
    size=$(du -sh "$d" 2>/dev/null | cut -f1)
    log " - $(basename "$d"): الحجم التقريبي = $size"
  done
else
  log "[WARN] لا يوجد /opt على هذا النظام."
fi

# ------------------------------------------------------------
# 2) إعداد SmartFrind (التعلم المستمر)
# ------------------------------------------------------------
sec "2) إعداد SmartFrind (التعلم المستمر + cron + خدمة systemd)"

if [ ! -d "$SMARTFRIND_ROOT" ]; then
  log "[ERROR] مسار /opt/smartfrind غير موجود – لن يتم تفعيل التعلم المستمر."
else
  VENV="$SMARTFRIND_ROOT/venv"
  PY="$VENV/bin/python"
  PIP="$VENV/bin/pip"

  # 2.1 إنشاء/إصلاح venv
  if [ ! -x "$PY" ]; then
    log "لا يوجد venv جاهز لـ SmartFrind – سيتم إنشاء واحد جديد..."
    python3 -m venv "$VENV"
  else
    log "تم العثور على venv جاهز لـ SmartFrind."
  fi

  # 2.2 اختيار ملف requirements
  REQ=""
  if   [ -f "$SMARTFRIND_ROOT/requirements.final.txt" ]; then
    REQ="$SMARTFRIND_ROOT/requirements.final.txt"
  elif [ -f "$SMARTFRIND_ROOT/requirements_fixed.txt" ]; then
    REQ="$SMARTFRIND_ROOT/requirements_fixed.txt"
  elif [ -f "$SMARTFRIND_ROOT/requirements.txt" ]; then
    REQ="$SMARTFRIND_ROOT/requirements.txt"
  fi

  if [ -n "$REQ" ]; then
    log "تثبيت المتطلبات من: $REQ"
    "$PIP" install --upgrade pip >/dev/null 2>&1 || true
    "$PIP" install -r "$REQ" || log "[WARN] فشل جزئي في تثبيت بعض الحزم، يمكن مراجعة اللوج."
  else
    log "[WARN] لم أجد ملف requirements.* داخل /opt/smartfrind – تخطي تثبيت المتطلبات."
  fi

  # 2.3 تشغيل fix_and_setup.sh إن وجد
  if [ -x "$SMARTFRIND_ROOT/fix_and_setup.sh" ]; then
    log "تشغيل fix_and_setup.sh (ممكن يأخذ وقتًا قليلًا)..."
    (
      cd "$SMARTFRIND_ROOT"
      bash ./fix_and_setup.sh
    ) || log "[WARN] fix_and_setup.sh خرج بخطأ، راجع اللوج لاحقًا."
  else
    log "لم أجد fix_and_setup.sh، تخطي هذه الخطوة."
  fi

  # 2.4 تشغيل setup_cron.sh إن وجد
  if [ -x "$SMARTFRIND_ROOT/setup_cron.sh" ]; then
    log "تشغيل setup_cron.sh لإعداد cron للتعلم المستمر..."
    (
      cd "$SMARTFRIND_ROOT"
      bash ./setup_cron.sh
    ) || log "[WARN] setup_cron.sh خرج بخطأ، راجع اللوج."
  else
    log "لم أجد setup_cron.sh، يمكنك لاحقًا إعداد cron يدويًا."
  fi

  # 2.5 إنشاء خدمة smartfrind-learning.service
  sec "2.5) إعداد smartfrind-learning.service"
  backup_unit "smartfrind-learning.service"

  cat > /etc/systemd/system/smartfrind-learning.service <<'SERVICE'
[Unit]
Description=SmartFrind Continuous Learning Engine
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/opt/smartfrind
EnvironmentFile=-/opt/secure/smart.env
ExecStart=/bin/bash /opt/smartfrind/continuous_learning.sh
Restart=always
RestartSec=30
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
SERVICE

  log "تم إنشاء/تحديث smartfrind-learning.service"
fi

# ------------------------------------------------------------
# 3) إعداد SmartFriend Suite (Smart Core + Unified)
# ------------------------------------------------------------
sec "3) إعداد SmartFriend Suite (Smart Core + Unified API)"

if [ ! -d "$APP_ROOT" ]; then
  log "[ERROR] مسار /opt/smartfriend-suite غير موجود – لن يتم تفعيل Smart Core / Unified."
else
  SCRIPTS_DIR="$APP_ROOT/scripts"
  mkdir -p "$SCRIPTS_DIR"

  # 3.1 إنشاء run_smart_core.sh إن لم يكن موجودًا
  if [ ! -x "$SCRIPTS_DIR/run_smart_core.sh" ]; then
    log "run_smart_core.sh غير موجود – سيتم إنشاؤه."
    cat > "$SCRIPTS_DIR/run_smart_core.sh" <<'EOSC'
#!/usr/bin/env bash
set -Eeuo pipefail

echo "[SmartCore] بدء Smart Core API..."
cd /opt/smartfriend-suite

if [ ! -f "ENV/identity.env" ]; then
  echo "[SmartCore][ERROR] ملف ENV/identity.env غير موجود!"
  exit 1
fi

if [ -d "venv" ]; then
  # shellcheck source=/dev/null
  source venv/bin/activate
fi

# ضمان وجود الحزم الأساسية (لا يتوقف عند فشل pip)
pip install -q fastapi uvicorn python-dotenv || true

python -m smart_core.app
EOSC
    chmod +x "$SCRIPTS_DIR/run_smart_core.sh"
  else
    log "تم العثور على run_smart_core.sh – لن يتم تغييره."
  fi

  # 3.2 Backup للوحدات القديمة
  sec "3.2) Backup للوحدات القديمة الخاصة بـ SmartFriend Suite"
  backup_unit "smartfriend-smartcore.service"
  backup_unit "smartfriend-unified.service"
  backup_unit "smartfriend-api.service"

  # 3.3 smartfriend-smartcore.service
  sec "3.3) إنشاء/تحديث smartfriend-smartcore.service"
  cat > /etc/systemd/system/smartfriend-smartcore.service <<'SERVICE'
[Unit]
Description=SmartFriend Smart Core API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/run_smart_core.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

  # 3.4 smartfriend-unified.service
  sec "3.4) إنشاء/تحديث smartfriend-unified.service"
  cat > /etc/systemd/system/smartfriend-unified.service <<'SERVICE'
[Unit]
Description=SmartFriend Unified API
After=network.target smartfriend-smartcore.service
Requires=smartfriend-smartcore.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/run_unified_api.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

fi

# ------------------------------------------------------------
# 4) فحص قواعد بيانات الذاكرة/المعرفة (بدون تحريك ملفات)
# ------------------------------------------------------------
sec "4) فحص مواقع قواعد بيانات الذاكرة/المعرفة (Smart Memory)"

DB_DIR_CANDIDATE="/var/lib/smartfrind"
mkdir -p "$DB_DIR_CANDIDATE"

log "مسار رسمي مقترح لقواعد smart_memory: $DB_DIR_CANDIDATE"

# البحث عن ملفات smart_memory.db أو smartfrind.db
find /var/lib /opt -maxdepth 5 -type f \
  \( -iname "smart_memory.db" -o -iname "smartfrind.db" -o -iname "smart_memory*.sqlite*" \) 2>/dev/null \
  | sort | while read -r db; do
    size=$(du -h "$db" 2>/dev/null | cut -f1)
    log " - تم العثور على قاعدة محتملة: $db (الحجم: $size)"
done

log "ملاحظة: لم يتم نقل أو نسخ أي قاعدة بيانات – هذا فحص استكشافي فقط."

# ------------------------------------------------------------
# 5) تفعيل وإعادة تشغيل الخدمات
# ------------------------------------------------------------
sec "5) تفعيل وإعادة تشغيل الخدمات (systemd)"

log "systemctl daemon-reload ..."
systemctl daemon-reload

ENABLE_UNITS=()
[ -d "$SMARTFRIND_ROOT" ]  && ENABLE_UNITS+=("smartfrind-learning.service")
[ -d "$APP_ROOT" ]         && ENABLE_UNITS+=("smartfriend-smartcore.service" "smartfriend-unified.service")

if [ "${#ENABLE_UNITS[@]}" -gt 0 ]; then
  log "تمكين الوحدات على الإقلاع: ${ENABLE_UNITS[*]}"
  systemctl enable "${ENABLE_UNITS[@]}" >/dev/null 2>&1 || true
  log "إعادة تشغيل الوحدات الآن..."
  systemctl restart "${ENABLE_UNITS[@]}" || true
else
  log "[WARN] لا توجد وحدات لتفعيلها (قد تكون المسارات الأساسية مفقودة)."
fi

sec "5.1) حالة الوحدات (مختصرة)"
if [ "${#ENABLE_UNITS[@]}" -gt 0 ]; then
  systemctl --no-pager --lines=10 status "${ENABLE_UNITS[@]}" || true | tee -a "$LOG"
else
  log "لا يوجد وحدات لفحص حالتها."
fi

# ------------------------------------------------------------
# 6) ملخص نهائي
# ------------------------------------------------------------
sec "6) ملخص تنفيذي نهائي"

log "- مسار SmartFriend Suite : $APP_ROOT"
log "- مسار SmartFrind (التعلم): $SMARTFRIND_ROOT"
log "- مسار FFactory (إن وجد):   $FF_ROOT"
log "- مجلد Backup للوحدات:      $UNITS_BACKUP"
log "- ملف اللوج لهذا التشغيل:   $LOG"

log "ملاحظة: لا يوجد أي حذف لملفات/قواعد بيانات؛ كل التغييرات في تعريف الوحدات وتشغيلها."

echo
log "انتهى sf_full_stack_setup بنجاح (مع التحفظ على أي تحذيرات ظهرت في اللوج)."
