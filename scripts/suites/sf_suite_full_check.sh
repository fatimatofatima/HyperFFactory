#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="/opt/smartfriend-suite"
REPORT_ROOT="/root/sf_suite_reports"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${REPORT_ROOT}/diag_${TS}"
LOG="${OUT_DIR}/sf_suite_diag_${TS}.log"

mkdir -p "$OUT_DIR"

sec() {
  echo -e "\n============================================================" | tee -a "$LOG"
  echo "== $1" | tee -a "$LOG"
  echo "============================================================" | tee -a "$LOG"
}

run() {
  echo "\$ $*" | tee -a "$LOG"
  eval "$@" 2>&1 | tee -a "$LOG"
}

echo "[*] SmartFriend Suite Full Diagnostic @ $TS" | tee -a "$LOG"

# 1) معلومات النظام الأساسية
sec "System Info"
run "hostnamectl"
run "uname -a"
run "uptime"
run "date"

sec "CPU / Memory / Disk"
run "lscpu | egrep 'Model name|CPU\(s\)'"
run "free -h"
run "df -h /"
run "df -hi /"

# 2) الشبكة والبورتات
sec "Network / Ports"
run "ip -4 addr show"
run "ss -tlnp | head -40"
echo | tee -a "$LOG"
echo "== Ports of interest (8211, 80, 443, 5432, 6379) ==" | tee -a "$LOG"
run "ss -tlnp | egrep '(:8211|:80 |:443 |:5432|:6379)' || echo 'no critical ports matched'"

# 3) العمليات والخدمات المرتبطة بالمشروع
sec "Smart Core Process Check"
run "ps aux | grep -E 'uvicorn.*smart_core.app:app' | grep -v grep || echo 'no uvicorn smart_core process'"

sec "Systemd units (smartfriend / smart_core / ffactory)"
run "systemctl list-units --type=service | egrep 'smart|ffactory' || echo 'no smart/ffactory units found'"

# 4) هيكل مشروع SmartFriend Suite
sec "Project Root Structure"
if [ -d "$APP_ROOT" ]; then
  run "ls -la '$APP_ROOT'"
  echo | tee -a "$LOG"
  run "find '$APP_ROOT' -maxdepth 2 -type d | sort"
else
  echo "!! APP_ROOT not found: $APP_ROOT" | tee -a "$LOG"
fi

# 5) Python / venv / المتطلبات
sec "Python / Virtualenv"
run "command -v python3 || echo 'python3 not found'"
if [ -d "$APP_ROOT/venv" ]; then
  echo "[+] venv detected at $APP_ROOT/venv" | tee -a "$LOG"
  source "$APP_ROOT/venv/bin/activate"
  run "python3 -V"
  run "pip list | head -40"
  deactivate || true
else
  echo "[-] no venv directory at $APP_ROOT/venv" | tee -a "$LOG"
fi

# 6) إعدادات الهوية (بدون طباعة التوكنات)
sec "Identity / ENV Summary (safe)"
ENV_FILE="$APP_ROOT/ENV/identity.env"
if [ -f "$ENV_FILE" ]; then
  echo "[+] identity file: $ENV_FILE" | tee -a "$LOG"
  run "ls -l '$ENV_FILE'"
  echo "[*] SMART_CORE settings:" | tee -a "$LOG"
  run "grep -E '^SMART_CORE_(PROVIDER|MODEL|API_KEY)' '$ENV_FILE' | sed 's/=.*/=***HIDDEN***/'"
  echo "[*] Telegram bots (names only):" | tee -a "$LOG"
  run "grep -E '^(DEV_BOT_TOKEN|FORENSIC_BOT_TOKEN|ASSISTANT_BOT_TOKEN)' '$ENV_FILE' | sed 's/=.*/=***HIDDEN***/'"
else
  echo "!! identity.env not found: $ENV_FILE" | tee -a "$LOG"
fi

# 7) فحص Smart Core API فعلياً
sec "Smart Core HTTP Checks"
SMART_CORE_URL="http://127.0.0.1:8211"
run "curl -s ${SMART_CORE_URL}/ || echo 'GET / failed'"
run "curl -s ${SMART_CORE_URL}/health || echo 'GET /health failed'"
echo | tee -a "$LOG"
echo "[*] Test /api/v1/ask (short ping)" | tee -a "$LOG"
run "curl -s -X POST ${SMART_CORE_URL}/api/v1/ask -H 'Content-Type: application/json' -d '{\"persona\":\"developer\",\"user_id\":\"diag-test\",\"input\":\"Ping من سكربت الفحص.\"}'"

# 8) قواعد البيانات داخل المشروع
sec "SQLite Databases under APP_ROOT"
DB_LIST=$(find "$APP_ROOT" -type f -name '*.db' 2>/dev/null || true)
if [ -z "$DB_LIST" ]; then
  echo "no .db files under $APP_ROOT" | tee -a "$LOG"
else
  echo "$DB_LIST" | tee -a "$LOG"
  for db in $DB_LIST; do
    echo | tee -a "$LOG"
    echo "---- DB: $db ----" | tee -a "$LOG"
    if command -v sqlite3 >/dev/null 2>&1; then
      run "sqlite3 '$db' '.tables'"
      run "sqlite3 '$db' 'SELECT name, COUNT(*) FROM sqlite_master WHERE type=\"table\";'"
    else
      echo "sqlite3 not installed, skipping introspection" | tee -a "$LOG"
    fi
  done
fi

# 9) لوجات Smart Core الأخيرة
sec "Smart Core Logs"
for f in /tmp/smart_core_*.log; do
  if [ -f "$f" ]; then
    echo "---- tail -40 $f ----" | tee -a "$LOG"
    run "tail -40 '$f'"
  fi
done

# 10) ملخص نهائي
sec "Summary"
echo "Report directory: $OUT_DIR" | tee -a "$LOG"
echo "Main log file   : $LOG" | tee -a "$LOG"
echo "[*] Diagnostic completed." | tee -a "$LOG"
