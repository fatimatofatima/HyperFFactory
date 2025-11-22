#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

APP_ROOT="/opt/smartfriend-suite"
SCRIPTS_DIR="$APP_ROOT/scripts"

log "إنشاء مجلد السكربتات إن لم يكن موجودًا: $SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"

############################################
# قالب مشترك يوضع في كل سكربت من سكربتات Brain
############################################
read -r -d '' COMMON <<'EOC'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
cd "$APP_ROOT"

VENV1="$APP_ROOT/smartfriend/venv/bin/python"
VENV2="$APP_ROOT/smartfrind/venv/bin/python"

if [ -x "$VENV1" ]; then
  PYTHON="$VENV1"
elif [ -x "$VENV2" ]; then
  PYTHON="$VENV2"
else
  echo "[SF Brain] لا يوجد venv فعّال تحت smartfriend/venv أو smartfrind/venv – الخروج بكود 0 (placeholder فقط)." >&2
  exit 0
fi

# Placeholder: هنا لاحقًا نربط منطق Brain الحقيقي (ingest/learn/KB/FTS)
EOC

create_script() {
  local NAME="$1"
  local BODY="$2"
  local PATH="$SCRIPTS_DIR/$NAME"

  log "كتابة $PATH ..."
  {
    printf '%s\n' "$COMMON"
    printf '\n%s\n' "$BODY"
  } > "$PATH"

  chown smartfriend-suite:smartfriend-suite "$PATH" || log "⚠️ فشل chown لـ $PATH (متابعة، لكن يُفضّل ضبط المالك يدويًا)."
  chmod 750 "$PATH"
}

# sf_brain_ingest.sh
create_script "sf_brain_ingest.sh" 'echo "[SF Brain] ingest placeholder – لا يوجد منطق فعلي بعد."
exec "$PYTHON" - <<PY
print("SF Brain ingest placeholder running (no-op)")
PY'

# sf_brain_learn.sh
create_script "sf_brain_learn.sh" 'echo "[SF Brain] learn placeholder – لا يوجد منطق فعلي بعد."
exec "$PYTHON" - <<PY
print("SF Brain learn placeholder running (no-op)")
PY'

# sf_brain_learning_loop.sh
create_script "sf_brain_learning_loop.sh" 'echo "[SF Brain] learning loop placeholder – لا يوجد منطق فعلي بعد."
exec "$PYTHON" - <<PY
print("SF Brain continuous learning loop placeholder running (no-op)")
PY'

# sf_brain_kb_build.sh
create_script "sf_brain_kb_build.sh" 'echo "[SF Brain] KB build placeholder – لا يوجد منطق فعلي بعد."
exec "$PYTHON" - <<PY
print("SF Brain KB build placeholder running (no-op)")
PY'

# sf_brain_fts_maint.sh
create_script "sf_brain_fts_maint.sh" 'echo "[SF Brain] FTS maintenance placeholder – لا يوجد منطق فعلي بعد."
exec "$PYTHON" - <<PY
print("SF Brain FTS maintenance placeholder running (no-op)")
PY'

log "اكتمل إصلاح سكربتات Brain (placeholders جاهزة تحت $SCRIPTS_DIR)."
