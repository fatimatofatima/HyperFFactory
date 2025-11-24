#!/usr/bin/env bash
# HyperFFactory – Fix SmartFriend sf-web/sf-bot ExecStart paths and WorkingDirectory

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_fix_smartfriend_exec_paths_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Fix SmartFriend ExecStart (sf-web / sf-bot)"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "====================================================="

# ---- helpers ----

find_single_file() {
  local name="$1"
  # نبحث تحت /opt و /root فقط لتقليل الزمن
  find /opt /root -maxdepth 7 -type f -name "$name" 2>/dev/null | head -n 1 || true
}

find_nearby_venv_python() {
  local base="$1"
  # نبحث عن venv/bin/python قريب من مجلد التطبيق
  find "$base" -maxdepth 4 -type f -path "*/venv/bin/python" 2>/dev/null | head -n 1 || true
}

ensure_dropin_dir() {
  local unit="$1"
  local d="/etc/systemd/system/${unit}.service.d"
  if [ ! -d "$d" ]; then
    mkdir -p "$d"
  fi
  echo "$d"
}

# ---- 1) sf-web.service ----

fix_sf_web() {
  local unit="sf-web"
  log "== Step 1: Fix ${unit}.service =="

  if ! systemctl list-unit-files | grep -q "^${unit}.service"; then
    log "  ℹ️ ${unit}.service غير معرف على هذا السيرفر – تخطي."
    return 0
  fi

  # نبحث عن run_web.py
  local web_file
  web_file=$(find_single_file "run_web.py")
  if [ -z "$web_file" ]; then
    log "  ⚠️ لم يتم العثور على run_web.py في /opt أو /root"
    log "  ⚠️ سيتم إيقاف ${unit}.service وتعطيله مؤقتًا لتجنّب loop 203/EXEC"
    systemctl stop "${unit}.service" || true
    systemctl disable "${unit}.service" || true
    return 0
  fi

  local app_dir
  app_dir="$(dirname "$web_file")"
  log "  ✅ تم العثور على run_web.py في: $web_file"
  log "  ▶️ WorkingDirectory المقترح: $app_dir"

  local venv_py
  venv_py=$(find_nearby_venv_python "$app_dir")
  local py_exec
  if [ -n "$venv_py" ]; then
    py_exec="$venv_py"
    log "  ✅ استخدام venv Python: $py_exec"
  else
    py_exec="/usr/bin/python3"
    log "  ⚠️ لم يتم العثور على venv قريب – سيتم استخدام: $py_exec"
  fi

  local dropdir
  dropdir=$(ensure_dropin_dir "$unit")
  local dropfile="$dropdir/50-autofix-exec.conf"

  cat > "$dropfile" <<CONF
[Service]
WorkingDirectory=$app_dir
ExecStart=
ExecStart=$py_exec $web_file
CONF

  log "  ✅ تم كتابة Drop-in: $dropfile"

  log "  ▶️ systemctl daemon-reload"
  systemctl daemon-reload

  log "  ▶️ إعادة تشغيل ${unit}.service"
  if systemctl restart "${unit}.service"; then
    log "  ✅ ${unit}.service أعيد تشغيله بنجاح (تحقق لاحقًا من health 8390)"
  else
    log "  ⚠️ فشل في إعادة تشغيل ${unit}.service – راجع journalctl -u ${unit}.service"
  fi
}

# ---- 2) sf-bot.service ----

fix_sf_bot() {
  local unit="sf-bot"
  log "== Step 2: Fix ${unit}.service =="

  if ! systemctl list-unit-files | grep -q "^${unit}.service"; then
    log "  ℹ️ ${unit}.service غير معرف على هذا السيرفر – تخطي."
    return 0
  fi

  # نبحث عن main_bot.py
  local bot_file
  bot_file=$(find_single_file "main_bot.py")
  if [ -z "$bot_file" ]; then
    log "  ⚠️ لم يتم العثور على main_bot.py في /opt أو /root"
    log "  ⚠️ سيتم إيقاف ${unit}.service وتعطيله مؤقتًا لتجنّب loop 203/EXEC"
    systemctl stop "${unit}.service" || true
    systemctl disable "${unit}.service" || true
    return 0
  fi

  local app_dir
  app_dir="$(dirname "$bot_file")"
  log "  ✅ تم العثور على main_bot.py في: $bot_file"
  log "  ▶️ WorkingDirectory المقترح: $app_dir"

  local venv_py
  venv_py=$(find_nearby_venv_python "$app_dir")
  local py_exec
  if [ -n "$venv_py" ]; then
    py_exec="$venv_py"
    log "  ✅ استخدام venv Python: $py_exec"
  else
    py_exec="/usr/bin/python3"
    log "  ⚠️ لم يتم العثور على venv قريب – سيتم استخدام: $py_exec"
  fi

  local dropdir
  dropdir=$(ensure_dropin_dir "$unit")
  local dropfile="$dropdir/50-autofix-exec.conf"

  cat > "$dropfile" <<CONF
[Service]
WorkingDirectory=$app_dir
ExecStart=
ExecStart=$py_exec $bot_file
CONF

  log "  ✅ تم كتابة Drop-in: $dropfile"

  log "  ▶️ systemctl daemon-reload"
  systemctl daemon-reload

  log "  ▶️ إعادة تشغيل ${unit}.service"
  if systemctl restart "${unit}.service"; then
    log "  ✅ ${unit}.service أعيد تشغيله بنجاح (تحقق لاحقًا من وضع البوت)"
  else
    log "  ⚠️ فشل في إعادة تشغيل ${unit}.service – راجع journalctl -u ${unit}.service"
  fi
}

# ---- التنفيذ ----

fix_sf_web
fix_sf_bot

log "====================================================="
log "✅ انتهى سكربت تصحيح مسارات sf-web / sf-bot"
log "📄 تقرير التنفيذ في: $LOG"
log "====================================================="
