#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log() { echo "[$(date '+%F %T')] $*"; }

SFDIR="/opt/smartfriend-suite"
SFSCRIPTS="$SFDIR/scripts"
APP_BRAIN="$SFDIR/apps/brain"
VENVDIR="$SFDIR/venv"
PYTHON="$VENVDIR/bin/python"
SFUSER="smartfriend-suite"
SFGROUP="smartfriend-suite"
BRAIN_LOG_DIR="$SFDIR/var/logs/brain"

log "بدء إصلاح طبقة SF Brain داخل السيوت فقط (بدون لمس ffactory)..."

# تحقق من وجود مجلد السيوت
if [ ! -d "$SFDIR" ]; then
  log "خطأ: مجلد السيوت غير موجود: $SFDIR"
  exit 1
fi

# تحضير المسارات
mkdir -p "$SFSCRIPTS" "$APP_BRAIN" "$BRAIN_LOG_DIR"

# إنشاء سكربتات Brain wrappers (لا تنفّذ أي منطق فعلي إذا لم يوجد كود بايثون بعد)
log "إنشاء سكربتات التشغيل لطبقة Brain..."

cat > "$SFSCRIPTS/sf_brain_ingest.sh" <<'EOT'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/opt/smartfriend-suite"
VENV="$BASE/venv"
PY="$VENV/bin/python"
LOG_DIR="$BASE/var/logs/brain"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/ingest.log"
cd "$BASE" || exit 1

if [ -x "$PY" ] && [ -f "$BASE/apps/brain/ingest.py" ]; then
  exec "$PY" "$BASE/apps/brain/ingest.py" "$@" >>"$LOG" 2>&1
else
  echo "SF Brain Ingest: لا يوجد ingest.py فعلي حاليًا – خروج بدون تنفيذ." >>"$LOG"
  exit 0
fi
EOT

cat > "$SFSCRIPTS/sf_brain_learn.sh" <<'EOT'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/opt/smartfriend-suite"
VENV="$BASE/venv"
PY="$VENV/bin/python"
LOG_DIR="$BASE/var/logs/brain"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/learn.log"
cd "$BASE" || exit 1

if [ -x "$PY" ] && [ -f "$BASE/apps/brain/learn.py" ]; then
  exec "$PY" "$BASE/apps/brain/learn.py" "$@" >>"$LOG" 2>&1
else
  echo "SF Brain Learn: لا يوجد learn.py فعلي حاليًا – خروج بدون تنفيذ." >>"$LOG"
  exit 0
fi
EOT

cat > "$SFSCRIPTS/sf_brain_learning_loop.sh" <<'EOT'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/opt/smartfriend-suite"
VENV="$BASE/venv"
PY="$VENV/bin/python"
LOG_DIR="$BASE/var/logs/brain"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/learning_loop.log"
cd "$BASE" || exit 1

if [ -x "$PY" ] && [ -f "$BASE/apps/brain/learning_loop.py" ]; then
  exec "$PY" "$BASE/apps/brain/learning_loop.py" "$@" >>"$LOG" 2>&1
else
  echo "SF Brain Learning Loop: لا يوجد learning_loop.py فعلي حاليًا – خروج بدون تنفيذ." >>"$LOG"
  exit 0
fi
EOT

cat > "$SFSCRIPTS/sf_brain_kb_build.sh" <<'EOT'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/opt/smartfriend-suite"
VENV="$BASE/venv"
PY="$VENV/bin/python"
LOG_DIR="$BASE/var/logs/brain"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/kb_build.log"
cd "$BASE" || exit 1

if [ -x "$PY" ] && [ -f "$BASE/apps/brain/kb_build.py" ]; then
  exec "$PY" "$BASE/apps/brain/kb_build.py" "$@" >>"$LOG" 2>&1
else
  echo "SF Brain KB Build: لا يوجد kb_build.py فعلي حاليًا – خروج بدون تنفيذ." >>"$LOG"
  exit 0
fi
EOT

cat > "$SFSCRIPTS/sf_brain_fts_maint.sh" <<'EOT'
#!/usr/bin/env bash
set -Eeuo pipefail
BASE="/opt/smartfriend-suite"
VENV="$BASE/venv"
PY="$VENV/bin/python"
LOG_DIR="$BASE/var/logs/brain"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/fts_maint.log"
cd "$BASE" || exit 1

if [ -x "$PY" ] && [ -f "$BASE/apps/brain/fts_maint.py" ]; then
  exec "$PY" "$BASE/apps/brain/fts_maint.py" "$@" >>"$LOG" 2>&1
else
  echo "SF Brain FTS Maint: لا يوجد fts_maint.py فعلي حاليًا – خروج بدون تنفيذ." >>"$LOG"
  exit 0
fi
EOT

chmod 750 "$SFSCRIPTS"/sf_brain_*.sh || true

# ضبط الملكية إذا كان مستخدم السيوت موجود
if id -u "$SFUSER" >/dev/null 2>&1; then
  chown "$SFUSER:$SFGROUP" "$SFSCRIPTS"/sf_brain_*.sh "$BRAIN_LOG_DIR" || true
else
  log "تحذير: المستخدم $SFUSER غير موجود – لن يتم تطبيق chown على سكربتات Brain."
fi

# إنشاء/تحديث وحدات systemd لطبقة SF Brain فقط
log "إنشاء/تحديث وحدات systemd لخدمات SF Brain..."

cat > /etc/systemd/system/sf-ingest.service <<'EOT'
[Unit]
Description=SmartFriend Suite - Brain Ingest
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_brain_ingest.sh
Restart=on-failure
RestartSec=5
Environment=SF_ENV=production

[Install]
WantedBy=multi-user.target
EOT

cat > /etc/systemd/system/sf-learn.service <<'EOT'
[Unit]
Description=SmartFriend Suite - Brain Learn
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_brain_learn.sh
Restart=on-failure
RestartSec=10
Environment=SF_ENV=production

[Install]
WantedBy=multi-user.target
EOT

cat > /etc/systemd/system/sf-learning.service <<'EOT'
[Unit]
Description=SmartFriend Suite - Brain Continuous Learning Loop
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_brain_learning_loop.sh
Restart=always
RestartSec=15
Environment=SF_ENV=production

[Install]
WantedBy=multi-user.target
EOT

cat > /etc/systemd/system/sf-kb-build.service <<'EOT'
[Unit]
Description=SmartFriend Suite - Knowledge Base Builder
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_brain_kb_build.sh
Restart=on-failure
RestartSec=30
Environment=SF_ENV=production

[Install]
WantedBy=multi-user.target
EOT

cat > /etc/systemd/system/sf-fts-maint.service <<'EOT'
[Unit]
Description=SmartFriend Suite - FTS Maintenance
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_brain_fts_maint.sh
Restart=on-failure
RestartSec=60
Environment=SF_ENV=production

[Install]
WantedBy=multi-user.target
EOT

log "إعادة تحميل systemd..."
systemctl daemon-reload

# تفعيل الخدمات بدون لمس أي شيء يبدأ بـ ff-
for svc in sf-ingest.service sf-learn.service sf-learning.service sf-kb-build.service sf-fts-maint.service; do
  if systemctl enable "$svc" >/dev/null 2>&1; then
    log "تم تفعيل $svc على مستوى الإقلاع."
  else
    log "تحذير: فشل enable لـ $svc."
  fi
done

log "عدم لمس أي خدمات ffactory (ff-doctor, ff-selfaware, ...)."

log "انتهى sf_suite_brain_fix: طبقة Brain في السيوت الآن مربوطة على /opt/smartfriend-suite و venv."
