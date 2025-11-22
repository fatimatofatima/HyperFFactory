#!/usr/bin/env bash
# ==============================================
# SmartFriend Suite - Dev & Integration Check
# نسخة: 1.0 (dev-integration unified)
# ==============================================
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
REPORT_ROOT="/root/sf_suite_reports"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${REPORT_ROOT}/dev_integration_${TS}"
LOG="${OUT}/sf_dev_integration_${TS}.log"

mkdir -p "$OUT"

# ألوان
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$LOG"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}" | tee -a "$LOG"; }
error() { echo -e "${RED}[❌] $*${NC}" | tee -a "$LOG" >&2; }
info()  { echo -e "${BLUE}[ℹ] $*${NC}" | tee -a "$LOG"; }

section() {
    echo | tee -a "$LOG"
    echo "============================================================" | tee -a "$LOG"
    echo "== $1" | tee -a "$LOG"
    echo "============================================================" | tee -a "$LOG"
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------
# فحص المنافذ بدقة
# ------------------------------------------------
check_service_port() {
  local port="$1"
  if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$"; then
    return 0
  else
    return 1
  fi
}

# ------------------------------------------------
# فحص استخدام الذاكرة
# ------------------------------------------------
check_memory_usage() {
  if ! have free; then
    warn "أمر free غير موجود - تخطي فحص الذاكرة"
    return 0
  fi
  local mem_usage
  mem_usage=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
  info "استخدام الذاكرة الحالي: ${mem_usage}%"
  if (( mem_usage > 90 )); then
    warn "الذاكرة ممتلئة تقريباً (${mem_usage}%) - قد يؤثر على أداء SmartFriend"
  fi
}

# ------------------------------------------------
# فحص صلاحيات الملفات الهامة
# ------------------------------------------------
check_permissions() {
  local important_files=(
    "$APP_ROOT/ENV/identity.env"
    "$APP_ROOT/data"
  )
  info "فحص صلاحيات الملفات الهامة..."
  for path in "${important_files[@]}"; do
    if [[ -f "$path" || -d "$path" ]]; then
      local perm
      perm=$(stat -c "%a" "$path" 2>/dev/null || echo "N/A")
      if [[ "$perm" != "N/A" ]]; then
        # لو الآخرين عندهم صلاحيات كتابة/قراءة واسعة
        if [[ "${perm:2:1}" != "0" ]]; then
          warn "صلاحيات عالمية محتملة على $path (perm=$perm) - يفضّل تضييقها (مثلاً 600 أو 700)"
        else
          log "صلاحيات مناسبة لـ $path (perm=$perm)"
        fi
      else
        warn "تعذر قراءة صلاحيات $path"
      fi
    else
      warn "المسار غير موجود (تخطي فحص البرمشن): $path"
    fi
  done
}

# ------------------------------------------------
# التحقق من المسار الرئيسي
# ------------------------------------------------
if [ ! -d "$APP_ROOT" ]; then
    error "المسار الرئيسي غير موجود: $APP_ROOT"
    exit 1
fi

echo -e "${BLUE}"
echo "============================================================"
echo "   SmartFriend Suite - Dev & Integration Diagnostic"
echo "============================================================"
echo -e "${NC}"
log "بدء فحص التطوير والتكامل لـ SmartFriend Suite"
log "APP_ROOT = $APP_ROOT"
log "تقرير الفحص: $OUT"
log "ملف اللوج: $LOG"

# ------------------------------------------------
# 1) معلومات النظام والموارد
# ------------------------------------------------
section "System Info / Resources"

if have hostnamectl; then
  echo "\$ hostnamectl" | tee -a "$LOG"
  hostnamectl 2>&1 | tee -a "$LOG"
fi

echo "\$ uname -a" | tee -a "$LOG"
uname -a 2>&1 | tee -a "$LOG"

echo "\$ uptime" | tee -a "$LOG"
uptime 2>&1 | tee -a "$LOG"

if have free; then
  echo "\$ free -h" | tee -a "$LOG"
  free -h 2>&1 | tee -a "$LOG"
fi

if have df; then
  echo "\$ df -h /" | tee -a "$LOG"
  df -h / 2>&1 | tee -a "$LOG"
fi

check_memory_usage

# ------------------------------------------------
# 2) الشبكات والمنافذ
# ------------------------------------------------
section "Network / Ports"

if have ip; then
  echo "\$ ip -4 addr show" | tee -a "$LOG"
  ip -4 addr show 2>&1 | tee -a "$LOG"
fi

echo "\$ ss -tlnp | head -40" | tee -a "$LOG"
if have ss; then
  ss -tlnp 2>&1 | head -40 | tee -a "$LOG"
else
  warn "أمر ss غير متوفر - تخطي فحص التفاصيل الدقيقة للمنافذ"
fi

echo | tee -a "$LOG"
echo "== Ports of interest (8211, 8214, 8220, 8000, 8170, 5432) ==" | tee -a "$LOG"
declare -A PORT_LABELS=(
  [8211]="Smart Core"
  [8214]="Memory API"
  [8220]="Unified API"
  [8000]="FFactory Main"
  [8170]="FFactory Gateway"
  [5432]="PostgreSQL"
)

for p in 8211 8214 8220 8000 8170 5432; do
  if check_service_port "$p"; then
    log "✅ ${PORT_LABELS[$p]} (port $p) - LISTEN"
  else
    warn "❌ ${PORT_LABELS[$p]} (port $p) - لا يوجد LISTEN"
  fi
done

# ------------------------------------------------
# 3) فحص العمليات الأساسية
# ------------------------------------------------
section "Core Processes"

echo "\$ ps aux | grep -E 'uvicorn.*smart_core.app:app'" | tee -a "$LOG"
ps aux | grep -E 'uvicorn.*smart_core.app:app' | grep -v grep 2>&1 | tee -a "$LOG" || warn "لا توجد عملية uvicorn لـ smart_core.app"

echo "\$ ps aux | grep -E 'python3.*(8170|8220|8214)'" | tee -a "$LOG"
ps aux | grep -E 'python3.*(8170|8220|8214)' | grep -v grep 2>&1 | tee -a "$LOG" || warn "لم يتم العثور على عمليات python3 المتوقعة (8170/8220/8214)"

# ------------------------------------------------
# 4) فحص Smart Core HTTP / التكامل
# ------------------------------------------------
section "Smart Core HTTP / Integration"

if ! have curl; then
  warn "curl غير متوفر - تخطي فحص HTTP"
else
  info "Testing Smart Core base endpoint (/)..."
  echo "\$ curl -s http://127.0.0.1:8211/" | tee -a "$LOG"
  curl -s http://127.0.0.1:8211/ 2>&1 | tee -a "$LOG" || warn "GET / فشل"

  info "Testing Smart Core health (/health)..."
  echo "\$ curl -s http://127.0.0.1:8211/health" | tee -a "$LOG"
  curl -s http://127.0.0.1:8211/health 2>&1 | tee -a "$LOG" || warn "GET /health فشل"

  info "Testing Smart Core /api/v1/ask..."
  curl -s -X POST http://127.0.0.1:8211/api/v1/ask \
    -H 'Content-Type: application/json' \
    -d '{"persona":"developer","user_id":"dev-integration","input":"Ping من سكربت dev-integration."}' \
    2>&1 | tee -a "$LOG" || warn "POST /api/v1/ask فشل"
fi

# ------------------------------------------------
# 5) هيكل مشروع SmartFriend Suite
# ------------------------------------------------
section "SmartFriend Suite Structure"

echo "\$ ls -la '$APP_ROOT'" | tee -a "$LOG"
ls -la "$APP_ROOT" 2>&1 | tee -a "$LOG"

echo "\$ find '$APP_ROOT' -maxdepth 2 -type d | sort" | tee -a "$LOG"
find "$APP_ROOT" -maxdepth 2 -type d 2>/dev/null | sort | tee -a "$LOG"

# ملفات / مجلدات أساسية متوقعة
declare -a CORE_PATHS=(
  "$APP_ROOT/smart_core"
  "$APP_ROOT/apps"
  "$APP_ROOT/factory"
  "$APP_ROOT/bots"
  "$APP_ROOT/data"
  "$APP_ROOT/ENV/identity.env"
)

for p in "${CORE_PATHS[@]}"; do
  if [ -d "$p" ]; then
    log "✅ المجلد موجود: $p"
  elif [ -f "$p" ]; then
    log "✅ الملف موجود: $p"
  else
    warn "❌ مفقود: $p"
  fi
done

# ------------------------------------------------
# 6) قواعد بيانات SQLite
# ------------------------------------------------
section "SQLite Databases"

if ! have sqlite3; then
  warn "sqlite3 غير متوفر - تخطي فحص قواعد البيانات"
else
  mapfile -t dbs < <(find "$APP_ROOT/data" -maxdepth 1 -name "*.db" 2>/dev/null || true)
  if [ "${#dbs[@]}" -eq 0 ]; then
    warn "لم يتم العثور على أي قاعدة بيانات *.db تحت $APP_ROOT/data"
  else
    for db in "${dbs[@]}"; do
      echo "---- DB: $db ----" | tee -a "$LOG"
      echo "\$ sqlite3 '$db' '.tables'" | tee -a "$LOG"
      sqlite3 "$db" '.tables' 2>&1 | tee -a "$LOG"
      echo "\$ sqlite3 '$db' 'SELECT name, COUNT(*) FROM sqlite_master WHERE type=\"table\";'" | tee -a "$LOG"
      sqlite3 "$db" 'SELECT name, COUNT(*) FROM sqlite_master WHERE type="table";' 2>&1 | tee -a "$LOG"
      echo | tee -a "$LOG"
    done
  fi
fi

# ------------------------------------------------
# 7) التبعيات (Python)
# ------------------------------------------------
section "Python Dependencies"

if ! have python3; then
  error "python3 غير مثبت - هذا ضروري لتشغيل الأنظمة"
else
  info "فحص الحزم الأساسية (dotenv, fastapi, uvicorn, requests, pydantic)"
  python3 - << 'PYEOF' 2>&1
import importlib

pkgs = ["dotenv", "fastapi", "uvicorn", "requests", "pydantic", "sqlalchemy"]
for name in pkgs:
    try:
        m = importlib.import_module(name)
        ver = getattr(m, "__version__", "no-version-attr")
        print(f"[✅] {name} - موجود ({ver})")
    except ImportError:
        print(f"[❌] {name} - غير موجود")
PYEOF
fi | tee -a "$LOG"

# ------------------------------------------------
# 8) فحص صلاحيات الملفات الحساسة
# ------------------------------------------------
section "Permissions & Security"

check_permissions

# ------------------------------------------------
# 9) ملخص نهائي
# ------------------------------------------------
section "Summary"

log "تم إنشاء تقرير الفحص في: $OUT"
log "ملف اللوج الرئيسي: $LOG"
log "انتهى فحص dev-integration لـ SmartFriend Suite."

echo
echo "Report directory: $OUT"
echo "Main log file   : $LOG"
echo
