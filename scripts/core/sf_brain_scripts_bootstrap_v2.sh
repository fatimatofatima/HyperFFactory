#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

APP_ROOT="/opt/smartfriend-suite"
SCRIPTS_DIR="$APP_ROOT/scripts"

log "إنشاء مجلد السكربتات إن لم يكن موجودًا..."
mkdir -p "$SCRIPTS_DIR"

############################################
# دالة مشتركة تُكتب داخل كل سكربت Brain
############################################
COMMON_HEADER='#!/usr/bin/env bash
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
elif command -v python3 >/dev/null 2>&1; then
  PYTHON="$(command -v python3)"
else
  echo "[$(date '+%F %T')] [Brain] لا يوجد Python مناسب (venv أو python3)." >&2
  exit 1
fi
'

############################################
# 1) sf_brain_ingest.sh
############################################
log "كتابة: $SCRIPTS_DIR/sf_brain_ingest.sh"
cat > "$SCRIPTS_DIR/sf_brain_ingest.sh" <<'EOS'
__COMMON__
echo "[$(date '+%F %T')] [sf_brain_ingest] بدء عملية Ingest/Spider..." >&2

# المحاولة الأولى مع مود ingest، لو غير مدعوم نستخدم الاستدعاء الافتراضي
if "$PYTHON" "$APP_ROOT/scripts/unify_memory.py" --mode ingest; then
  exit 0
fi

echo "[$(date '+%F %T')] [sf_brain_ingest] fallback بدون mode..." >&2
exec "$PYTHON" "$APP_ROOT/scripts/unify_memory.py"
EOS

############################################
# 2) sf_brain_learn.sh
############################################
log "كتابة: $SCRIPTS_DIR/sf_brain_learn.sh"
cat > "$SCRIPTS_DIR/sf_brain_learn.sh" <<'EOS'
__COMMON__
echo "[$(date '+%F %T')] [sf_brain_learn] بدء عملية التعلم..." >&2

if "$PYTHON" "$APP_ROOT/scripts/unify_memory.py" --mode learn; then
  exit 0
fi

echo "[$(date '+%F %T')] [sf_brain_learn] fallback بدون mode..." >&2
exec "$PYTHON" "$APP_ROOT/scripts/unify_memory.py"
EOS

############################################
# 3) sf_brain_learning_loop.sh
############################################
log "كتابة: $SCRIPTS_DIR/sf_brain_learning_loop.sh"
cat > "$SCRIPTS_DIR/sf_brain_learning_loop.sh" <<'EOS'
__COMMON__
echo "[$(date '+%F %T')] [sf_brain_learning_loop] تشغيل حلقة التعلم المستمر..." >&2

while true; do
  if ! "$PYTHON" "$APP_ROOT/scripts/unify_memory.py" --mode learn; then
    echo "[$(date '+%F %T')] [sf_brain_learning_loop] فشل learn بالمود، محاولة fallback..." >&2
    "$PYTHON" "$APP_ROOT/scripts/unify_memory.py" || true
  fi
  # نوم بين دورات التعلم (يمكن ضبطه لاحقًا)
  sleep 300
done
EOS

############################################
# 4) sf_brain_kb_build.sh
############################################
log "كتابة: $SCRIPTS_DIR/sf_brain_kb_build.sh"
cat > "$SCRIPTS_DIR/sf_brain_kb_build.sh" <<'EOS'
__COMMON__
echo "[$(date '+%F %T')] [sf_brain_kb_build] بناء/تحديث الـ Knowledge Base..." >&2

if "$PYTHON" "$APP_ROOT/scripts/unify_memory.py" --mode kb_build; then
  exit 0
fi

echo "[$(date '+%F %T')] [sf_brain_kb_build] fallback بدون mode..." >&2
exec "$PYTHON" "$APP_ROOT/scripts/unify_memory.py"
EOS

############################################
# 5) sf_brain_fts_maint.sh
############################################
log "كتابة: $SCRIPTS_DIR/sf_brain_fts_maint.sh"
cat > "$SCRIPTS_DIR/sf_brain_fts_maint.sh" <<'EOS'
__COMMON__
echo "[$(date '+%F %T')] [sf_brain_fts_maint] صيانة فهارس FTS..." >&2

if "$PYTHON" "$APP_ROOT/scripts/unify_memory.py" --mode fts_maint; then
  exit 0
fi

echo "[$(date '+%F %T')] [sf_brain_fts_maint] fallback بدون mode..." >&2
exec "$PYTHON" "$APP_ROOT/scripts/unify_memory.py"
EOS

############################################
# حقن الـ COMMON_HEADER داخل كل سكربت
############################################
log "حقن الهيدر المشترك داخل سكربتات Brain..."
for f in sf_brain_ingest.sh sf_brain_learn.sh sf_brain_learning_loop.sh sf_brain_kb_build.sh sf_brain_fts_maint.sh; do
  target="$SCRIPTS_DIR/$f"
  if [ -f "$target" ]; then
    sed -i "s#__COMMON__#$COMMON_HEADER#" "$target"
  else
    log "تحذير: لم أجد $target أثناء حقن الهيدر."
  fi
done

############################################
# صلاحيات وملكية
############################################
log "ضبط التصاريح والملكية لليوزر smartfriend-suite..."
chown smartfriend-suite:smartfriend-suite "$SCRIPTS_DIR"/sf_brain_*.sh || true
chmod 750 "$SCRIPTS_DIR"/sf_brain_*.sh

log "اكتمل إنشاء سكربتات Brain داخل السويت فقط."
