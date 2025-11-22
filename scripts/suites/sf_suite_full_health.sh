#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

APP_ROOT="/opt/smartfriend-suite"
APP_SCRIPTS="$APP_ROOT/scripts"
APP_VENV_LINK="$APP_ROOT/venv"

FF_ROOT="/opt/ffactory"
FF_SCRIPTS="$FF_ROOT/scripts"

log "=== SmartFriend Suite / FFactory - Full Health & Autoheal ==="

############################################
# 1) Users & Permissions
############################################
ensure_user_smartfriend_suite() {
  local u="smartfriend-suite"
  if ! id "$u" >/dev/null 2>&1; then
    log "إنشاء مستخدم سيستيم ${u}..."
    useradd --system \
      --home-dir "$APP_ROOT" \
      --shell /usr/sbin/nologin \
      "$u"
  else
    log "المستخدم ${u} موجود بالفعل."
  fi

  for d in "$APP_ROOT/var" "$APP_ROOT/logs" "$APP_ROOT/data"; do
    if [ -d "$d" ]; then
      chown -R "$u:$u" "$d" || true
    fi
  done
}

ensure_user_ffactory() {
  local u="ffactory" g="ffactory"
  if ! getent group "$g" >/dev/null 2>&1; then
    log "إنشاء المجموعة ${g}..."
    groupadd --system "$g"
  else
    log "المجموعة ${g} موجودة بالفعل."
  fi

  if ! id "$u" >/dev/null 2>&1; then
    log "إنشاء مستخدم سيستيم ${u}..."
    useradd --system \
      --home-dir "$FF_ROOT" \
      --shell /usr/sbin/nologin \
      --gid "$g" \
      "$u"
  else
    log "المستخدم ${u} موجود بالفعل."
  fi

  mkdir -p "$FF_ROOT" "$FF_SCRIPTS"
  chown -R "$u:$g" "$FF_ROOT" || true
}

############################################
# 2) VENV Link Detection (/opt/smartfriend-suite/venv)
############################################
ensure_venv_link() {
  if [ -x "$APP_VENV_LINK/bin/python" ]; then
    log "تم العثور على venv في $APP_VENV_LINK."
    return 0
  fi

  local candidate=""
  if [ -x "$APP_ROOT/smartfriend/venv/bin/python" ]; then
    candidate="$APP_ROOT/smartfriend/venv"
  elif [ -x "$APP_ROOT/smartfrind/venv/bin/python" ]; then
    candidate="$APP_ROOT/smartfrind/venv"
  fi

  if [ -n "$candidate" ]; then
    log "لم يتم العثور على venv link، إنشاء رابط رمزي من $candidate إلى $APP_VENV_LINK..."
    if [ -e "$APP_VENV_LINK" ] && [ ! -L "$APP_VENV_LINK" ]; then
      log "تحذير: يوجد شيء باسم $APP_VENV_LINK وليس symlink – لن ألمسه."
    else
      ln -sfn "$candidate" "$APP_VENV_LINK"
      log "تم إنشاء الرابط الرمزي: $APP_VENV_LINK -> $candidate"
    fi
  else
    log "تحذير: لم أجد أي venv في smartfriend/venv أو smartfrind/venv. خدمات Brain ستظل مكسورة حتى إنشاء venv."
  fi
}

############################################
# 3) Brain Scripts under /opt/smartfriend-suite/scripts
############################################
ensure_brain_scripts() {
  mkdir -p "$APP_SCRIPTS"

  local py="$APP_VENV_LINK/bin/python"
  if [ ! -x "$py" ]; then
    log "تحذير: $py غير موجود أو غير قابل للتنفيذ. سيتم إنشاء السكربتات لكن قد تفشل وقت التشغيل."
  fi

  # sf_brain_ingest.sh => spider_core.py
  cat > "$APP_SCRIPTS/sf_brain_ingest.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/smartfriend-suite"
PY="$APP_ROOT/venv/bin/python"
SPIDER="$APP_ROOT/packages/ingest/spider_core.py"

echo "[$(date '+%F %T')] [sf_brain_ingest] بدء Ingest..."
if [ -x "$PY" ] && [ -f "$SPIDER" ]; then
  exec "$PY" "$SPIDER"
else
  echo "[$(date '+%F %T')] [sf_brain_ingest] تحذير: Python أو spider_core.py غير موجودين، خروج هادئ."
  exit 0
fi
EOS

  # sf_brain_learn.sh => learn_from_curriculum.py
  cat > "$APP_SCRIPTS/sf_brain_learn.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/smartfriend-suite"
PY="$APP_ROOT/venv/bin/python"
CURR="$APP_ROOT/bots/learn_from_curriculum.py"

echo "[$(date '+%F %T')] [sf_brain_learn] بدء Learn from curriculum..."
if [ -x "$PY" ] && [ -f "$CURR" ]; then
  exec "$PY" "$CURR"
else
  echo "[$(date '+%F %T')] [sf_brain_learn] تحذير: Python أو learn_from_curriculum.py غير موجودين، خروج هادئ."
  exit 0
fi
EOS

  # sf_brain_learning_loop.sh => loop unify_memory.py
  cat > "$APP_SCRIPTS/sf_brain_learning_loop.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/smartfriend-suite"
PY="$APP_ROOT/venv/bin/python"
UNIFY="$APP_ROOT/scripts/unify_memory.py"

echo "[$(date '+%F %T')] [sf_brain_learning_loop] بدء حلقة التعلم المستمر..."
if [ ! -x "$PY" ] || [ ! -f "$UNIFY" ]; then
  echo "[$(date '+%F %T')] [sf_brain_learning_loop] تحذير: Python أو unify_memory.py غير موجودين – خروج."
  exit 0
fi

trap 'echo "[$(date "+%F %T")] [sf_brain_learning_loop] تم استلام إشارة إيقاف، إنهاء..."; exit 0' INT TERM

while true; do
  echo "[$(date '+%F %T')] [sf_brain_learning_loop] تشغيل unify_memory..."
  "$PY" "$UNIFY" || echo "[$(date '+%F %T')] [sf_brain_learning_loop] تحذير: unify_memory.py فشل."
  echo "[$(date '+%F %T')] [sf_brain_learning_loop] نوم 900 ثانية..."
  sleep 900
done
EOS

  # sf_brain_kb_build.sh => build_knowledge_base.py
  cat > "$APP_SCRIPTS/sf_brain_kb_build.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/smartfriend-suite"
PY="$APP_ROOT/venv/bin/python"
BUILDER="$APP_ROOT/bots/build_knowledge_base.py"

echo "[$(date '+%F %T')] [sf_brain_kb_build] بدء بناء الـ Knowledge Base..."
if [ -x "$PY" ] && [ -f "$BUILDER" ]; then
  exec "$PY" "$BUILDER"
else
  echo "[$(date '+%F %T')] [sf_brain_kb_build] تحذير: Python أو build_knowledge_base.py غير موجودين، خروج هادئ."
  exit 0
fi
EOS

  # sf_brain_fts_maint.sh => unify_memory.py (صيانة FTS / دمج)
  cat > "$APP_SCRIPTS/sf_brain_fts_maint.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/smartfriend-suite"
PY="$APP_ROOT/venv/bin/python"
UNIFY="$APP_ROOT/scripts/unify_memory.py"

echo "[$(date '+%F %T')] [sf_brain_fts_maint] بدء صيانة FTS / توحيد الذاكرة..."
if [ -x "$PY" ] && [ -f "$UNIFY" ]; then
  exec "$PY" "$UNIFY"
else
  echo "[$(date '+%F %T')] [sf_brain_fts_maint] تحذير: Python أو unify_memory.py غير موجودين، خروج هادئ."
  exit 0
fi
EOS

  chmod +x "$APP_SCRIPTS"/sf_brain_*.sh || true

  if id smartfriend-suite >/dev/null 2>&1; then
    chown smartfriend-suite:smartfriend-suite "$APP_SCRIPTS"/sf_brain_*.sh || true
  fi

  log "تم إنشاء/تحديث سكربتات Brain تحت $APP_SCRIPTS."
}

############################################
# 4) ff-doctor minimal wrapper
############################################
ensure_ff_doctor_wrapper() {
  mkdir -p "$FF_SCRIPTS"

  cat > "$FF_SCRIPTS/ff_doctor_enhanced.sh" <<'EOS'
#!/usr/bin/env bash
set -Eeuo pipefail
log(){ echo "[$(date '+%F %T')] [ff_doctor] $*"; }

log "بدء فحص ffactory (placeholder بسيط)..."

BASE="/opt/smartfriend-suite"
REP="$BASE/factory/reports"
LOGD="$BASE/factory/logs"

log "تأكيد وجود مجلدات التقارير واللوج..."
mkdir -p "$REP" "$LOGD"

if [ -x "$BASE/factory/scripts/ff_core_diag.sh" ]; then
  log "تشغيل ff_core_diag.sh..."
  bash "$BASE/factory/scripts/ff_core_diag.sh" || log "تحذير: ff_core_diag.sh رجع كود خطأ."
else
  log "تحذير: لم أجد ff_core_diag.sh – تشغيل فحص بسيط للحاويات فقط."
  if command -v docker >/dev/null 2>&1; then
    docker ps --format 'table {{.Names}}\t{{.Status}}' | sed '1,10p' || true
  fi
fi

log "انتهاء ff_doctor_enhanced (خروج بكود 0 حتى لا يعلّق الـ timer)."
exit 0
EOS

  chmod +x "$FF_SCRIPTS/ff_doctor_enhanced.sh" || true

  if id ffactory >/dev/null 2>&1; then
    chown ffactory:ffactory "$FF_SCRIPTS/ff_doctor_enhanced.sh" || true
  fi

  log "تم إنشاء/تحديث ff_doctor_enhanced.sh تحت $FF_SCRIPTS."
}

############################################
# 5) systemd reload + restart key services
############################################
restart_services() {
  log "إعادة تحميل systemd daemon..."
  systemctl daemon-reload

  log "إعادة تشغيل خدمات Brain الرئيسية..."
  systemctl restart sf-ingest.service sf-learn.service sf-learning.service sf-kb-build.service sf-fts-maint.service 2>/dev/null || true

  log "إعادة تشغيل خدمات SmartFriend الأساسية..."
  systemctl restart sf-memory.service sf-unified.service sf-health.service sf-web.service 2>/dev/null || true

  log "إعادة تشغيل خدمات SmartFrind الأساسية (QA/Gateway إن وجدت)..."
  systemctl restart smartfrind-qa.service smartfrind-gateway.service 2>/dev/null || true

  log "إعادة تشغيل ff-doctor..."
  systemctl restart ff-doctor.service 2>/dev/null || true
}

############################################
# 6) Status summary
############################################
status_summary() {
  echo
  log "=== ملخص حالة الخدمات الحرجة (short) ==="
  systemctl --no-pager --failed | sed -n '1,40p' || true

  echo
  log "--- حالة Brain ---"
  systemctl --no-pager -l status sf-ingest.service sf-learn.service sf-learning.service sf-kb-build.service sf-fts-maint.service 2>/dev/null | sed -n '1,80p' || true

  echo
  log "--- حالة Unified / Memory / Web ---"
  systemctl --no-pager -l status sf-memory.service sf-unified.service sf-health.service sf-web.service 2>/dev/null | sed -n '1,80p' || true

  echo
  log "--- حالة ff-doctor ---"
  systemctl --no-pager -l status ff-doctor.service 2>/dev/null | sed -n '1,40p' || true
}

############################################
# Execution
############################################
ensure_user_smartfriend_suite
ensure_user_ffactory
ensure_venv_link
ensure_brain_scripts
ensure_ff_doctor_wrapper
restart_services
status_summary

log "=== انتهى sf_suite_full_health ==="
