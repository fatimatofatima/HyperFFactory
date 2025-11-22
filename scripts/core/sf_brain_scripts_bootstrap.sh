#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

APP_ROOT="/opt/smartfriend-suite"
SCRIPTS_DIR="$APP_ROOT/scripts"
# venv الفعلي داخل مجلد smartfriend
REAL_VENV="$APP_ROOT/smartfriend/venv"
PYTHON="$REAL_VENV/bin/python"

log "التحقق من venv الفعلي في: $REAL_VENV ..."
if [ ! -x "$PYTHON" ]; then
  log "خطأ: لم أجد $PYTHON أو غير قابل للتنفيذ."
  log "تأكد أن venv موجود فعلياً (smartfriend/venv) ثم أعد تشغيل هذا السكربت."
  exit 1
fi

log "إنشاء مجلد السكربتات إن لم يكن موجودًا: $SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"

# --------------------------------------------------------------------
# 1) sf_brain_ingest.sh   → مسؤول عن ingest / spider / جمع المعرفة
# --------------------------------------------------------------------
log "كتابة: $SCRIPTS_DIR/sf_brain_ingest.sh"
cat > "$SCRIPTS_DIR/sf_brain_ingest.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VENV="$APP_ROOT/smartfriend/venv"
PYTHON="$VENV/bin/python"

cd "$APP_ROOT" || exit 1

# مبدئياً: شغّل موديول health / spider / ingest كـ placeholder
# لاحقاً يمكن ربطه بـ smartfriend/spider_core.py أو أي موديول ingest فعلي
exec "$PYTHON" -m smartfriend.ingest_main
EOS
chmod 750 "$SCRIPTS_DIR/sf_brain_ingest.sh"

# --------------------------------------------------------------------
# 2) sf_brain_learn.sh    → تدريب / تعلم دفعي
# --------------------------------------------------------------------
log "كتابة: $SCRIPTS_DIR/sf_brain_learn.sh"
cat > "$SCRIPTS_DIR/sf_brain_learn.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VENV="$APP_ROOT/smartfriend/venv"
PYTHON="$VENV/bin/python"

cd "$APP_ROOT" || exit 1

# مبدئياً: استدعاء موديول للتعلم الدفعي
exec "$PYTHON" -m smartfriend.brain_learn
EOS
chmod 750 "$SCRIPTS_DIR/sf_brain_learn.sh"

# --------------------------------------------------------------------
# 3) sf_brain_learning_loop.sh → تعلم مستمر (daemon)
# --------------------------------------------------------------------
log "كتابة: $SCRIPTS_DIR/sf_brain_learning_loop.sh"
cat > "$SCRIPTS_DIR/sf_brain_learning_loop.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VENV="$APP_ROOT/smartfriend/venv"
PYTHON="$VENV/bin/python"

cd "$APP_ROOT" || exit 1

# مبدئياً: لوب تعلّم مستمر
exec "$PYTHON" -m smartfriend.brain_learning_loop
EOS
chmod 750 "$SCRIPTS_DIR/sf_brain_learning_loop.sh"

# --------------------------------------------------------------------
# 4) sf_brain_kb_build.sh → بناء/إعادة بناء قاعدة المعرفة (FTS, indexes..)
# --------------------------------------------------------------------
log "كتابة: $SCRIPTS_DIR/sf_brain_kb_build.sh"
cat > "$SCRIPTS_DIR/sf_brain_kb_build.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VENV="$APP_ROOT/smartfriend/venv"
PYTHON="$VENV/bin/python"

cd "$APP_ROOT" || exit 1

# مبدئياً: بناء indexes / FTS / views
exec "$PYTHON" -m smartfriend.brain_kb_build
EOS
chmod 750 "$SCRIPTS_DIR/sf_brain_kb_build.sh"

# --------------------------------------------------------------------
# 5) sf_brain_fts_maint.sh → صيانة فهارس FTS (تفريغ، إعادة بناء جزئي..)
# --------------------------------------------------------------------
log "كتابة: $SCRIPTS_DIR/sf_brain_fts_maint.sh"
cat > "$SCRIPTS_DIR/sf_brain_fts_maint.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VENV="$APP_ROOT/smartfriend/venv"
PYTHON="$VENV/bin/python"

cd "$APP_ROOT" || exit 1

# مبدئياً: صيانة دورية لــ FTS
exec "$PYTHON" -m smartfriend.brain_fts_maintenance
EOS
chmod 750 "$SCRIPTS_DIR/sf_brain_fts_maint.sh"

log "اكتمل إنشاء كل سكربتات Brain بنجاح تحت $SCRIPTS_DIR"
