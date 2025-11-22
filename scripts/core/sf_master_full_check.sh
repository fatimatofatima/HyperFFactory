#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="/root/sf_master_full_check_${TS}.txt"

APP_ROOT="/opt/smartfriend-suite"
VAR_DIR="${APP_ROOT}/var"
DB_DIR="${VAR_DIR}/db"
KNOW_DIR="${VAR_DIR}/knowledge"
LOG_DIR="${VAR_DIR}/logs"
APPS_DIR="${APP_ROOT}/apps"
SPIDER_DIR="${APPS_DIR}/harvester/spider"

LEGACY_DB="/var/lib/smartfrind/smart_memory.db"

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok()   { echo "   [OK]  $*";   OK_COUNT=$((OK_COUNT+1)); }
warn() { echo "   [WARN] $*";  WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo "   [FAIL] $*";  FAIL_COUNT=$((FAIL_COUNT+1)); }

section() {
    echo
    echo "================================================"
    echo " $*"
    echo "================================================"
}

check_dir() {
    local path="$1"
    local label="$2"
    if [ -d "$path" ]; then
        ok "المجلد موجود: $label ($path)"
    else
        warn "المجلد غير موجود: $label ($path)"
    fi
}

check_service() {
    local svc="$1"
    local label="$2"

    if ! systemctl list-unit-files "$svc" >/dev/null 2>&1; then
        warn "service $svc ($label): غير مُسجّل في systemd"
        return
    fi

    local enabled state
    enabled="$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")"
    state="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"

    echo " - $svc ($label): enabled=$enabled, active=$state"
    if [ "$state" = "active" ]; then
        ok "الخدمة $svc ($label) نشطة"
    elif [ "$enabled" = "enabled" ] && [ "$state" != "active" ]; then
        warn "الخدمة $svc ($label) مُمكّنة لكنها غير نشطة حالياً (Standby)"
    else
        warn "الخدمة $svc ($label) ليست نشطة (enabled=$enabled, active=$state)"
    fi
}

check_port() {
    local port="$1"
    local label="$2"
    if ss -tulpn 2>/dev/null | grep -q ":$port "; then
        ok "البورت $port ($label) يستمع"
    else
        warn "البورت $port ($label) لا يظهر كـ LISTEN"
    fi
}

check_http() {
    local url="$1"
    local label="$2"
    if command -v curl >/dev/null 2>&1; then
        local code
        code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo "000")"
        if [ "$code" = "200" ] || [ "$code" = "302" ] || [ "$code" = "307" ]; then
            ok "HTTP $label ($url) استجابة ناجحة (code=$code)"
        elif [ "$code" = "404" ]; then
            warn "HTTP $label ($url) يعمل لكن يرجع 404 (code=404) – قد تكون المسارات مختلفة"
        elif [ "$code" = "000" ]; then
            warn "HTTP $label ($url) لم يرد (code=000)"
        else
            warn "HTTP $label ($url) استجابة غير متوقعة (code=$code)"
        fi
    else
        warn "curl غير مثبت – تخطي فحص HTTP لـ $label"
    fi
}

check_sqlite_db() {
    local path="$1"
    local label="$2"
    shift 2
    local tables=("$@")

    if [ ! -f "$path" ]; then
        warn "قاعدة البيانات ($label) غير موجودة: $path"
        return
    fi

    echo ">>> DB: $label"
    echo "    المسار : $path"
    echo "    الحجم  : $(du -h "$path" | awk '{print $1}')"

    if ! command -v sqlite3 >/dev/null 2>&1; then
        warn "sqlite3 غير مثبت – لن يتم تنفيذ integrity_check على $label"
        return
    fi

    local integrity
    integrity="$(sqlite3 "$path" 'PRAGMA integrity_check;' 2>/dev/null || echo "error")"
    if [ "$integrity" = "ok" ]; then
        ok "integrity_check: ok لـ $label"
    else
        fail "integrity_check فشل لـ $label (نتيجة: $integrity)"
    fi

    for t in "${tables[@]}"; do
        local cnt
        cnt="$(sqlite3 "$path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='$t';" 2>/dev/null || echo 0)"
        if [ "$cnt" -eq 1 ]; then
            local rows
            rows="$(sqlite3 "$path" "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null || echo 0)"
            ok "الجدول $t موجود في $label – عدد الصفوف: $rows"
        else
            warn "الجدول $t غير موجود في $label"
        fi
    done
}

{
section "🧩 0) معلومات عامة عن النظام"
echo "التاريخ        : $(date)"
echo "المضيف         : $(hostname)"
echo "النواة         : $(uname -sr)"
echo "مدة التشغيل    : $(uptime -p || true)"
echo
echo "📊 الذاكرة:"
free -h || true
echo
echo "💿 القرص (root /):"
df -h / || true

section "1) بنية SmartFriend / SmartFrind / FFactory"

check_dir "$APP_ROOT"           "APP_ROOT (SmartFriend Suite)"
check_dir "$VAR_DIR"            "VAR_DIR (var)"
check_dir "$DB_DIR"             "DB_DIR (var/db)"
check_dir "$KNOW_DIR"           "KNOW_DIR (var/knowledge)"
check_dir "$LOG_DIR"            "LOG_DIR (var/logs)"
check_dir "$APPS_DIR"           "APPS_DIR (apps)"
check_dir "$SPIDER_DIR"         "SPIDER_DIR (apps/harvester/spider)"
check_dir "/opt/ffactory"       "FFactory Root (لو موجود)"
check_dir "/opt/smartfrind"     "SmartFrind Legacy App (لو موجود)"
check_dir "/var/lib/smartfrind" "SmartFrind Legacy Data (لو موجود)"

section "2) فحص قواعد البيانات (Knowledge / Memory / Identity)"

# DBs الموحدة الجديدة
for db in memory.db smart_core_memory.db unified_memory.db smartfriend_unified.db; do
    if [ -f "${DB_DIR}/${db}" ]; then
        check_sqlite_db "${DB_DIR}/${db}" "$db" sessions messages knowledge_items
    else
        warn "قاعدة البيانات غير موجودة: ${DB_DIR}/${db}"
    fi
done

# DB القديمة / الفعلية للمعرفة smart_memory.db
if [ -f "$LEGACY_DB" ]; then
    check_sqlite_db "$LEGACY_DB" "smart_memory.db (legacy knowledge)" \
        ai_memory ai_memory_fts knowledge_base
else
    warn "smart_memory.db (legacy) غير موجودة في $LEGACY_DB"
fi

section "3) الخدمات (systemd) – عقل / معرفة / زحف / بنية"

# خدمات بنية عامة
check_service "nginx.service"        "Nginx Reverse Proxy"
check_service "postgresql.service"   "PostgreSQL"
check_service "docker.service"       "Docker (لو مستخدم للـ FFactory)"

# خدمات SmartFrind / SmartFriend إن وُجدت
SMART_SERVICES=(
  "smartfrind-core.service:Core Brain"
  "smartfrind-local.service:Local Brain"
  "smartfrind-qa.service:QA Brain"
  "smartfrind-guardian.service:Guardian / Safety"
  "smartfrind-trainer.service:Trainer / Learning"
  "smartfrind-runner.service:Runner / Orchestrator"
  "smartfrind-advanced.service:Advanced Brain"
  "smartfrind-ai-gateway.service:AI Gateway"
  "smartfrind-harvest.service:Harvest"
  "smartfrind-ingest.service:Ingest"
  "smartfrind-reflector.service:Reflector"
  "smartfrind-autolearn.service:AutoLearn"
  "smartfrind-learning-agent.service:Learning Agent"
  "smartfrind-envwatch.service:Env Watch"
  "smartfrind-monitor.service:Monitor"
  "smartfrind-raw-clean.service:Raw Clean"
  "sf-spider.service:Spider / Awareness"
)

for item in "${SMART_SERVICES[@]}"; do
    svc="${item%%:*}"
    label="${item#*:}"
    check_service "$svc" "$label"
done

section "4) فحص البورتات الرئيسية"

check_port 80    "HTTP (Nginx)"
check_port 443   "HTTPS (Nginx)"
check_port 8000  "FFactory / Main UI"
check_port 8170  "FFactory Gateway"
check_port 8211  "Smart Core API"
check_port 8214  "Memory API"
check_port 8220  "Unified API"
check_port 8221  "Unified Gateway (Knowledge)"
check_port 8222  "Learning Gateway"
check_port 8223  "Enhanced Gateway (إن وجد)"
check_port 11434 "Ollama"
check_port 5432  "PostgreSQL"

section "5) فحص HTTP للبوابات الأساسية"

check_http "http://127.0.0.1/"                "Nginx Root"
check_http "http://127.0.0.1:8000/"           "FFactory Main"
check_http "http://127.0.0.1:8170/"           "FFactory Gateway"
check_http "http://127.0.0.1:8211/core/health" "Smart Core Health (لو Endpoint موجود)"
check_http "http://127.0.0.1:8214/docs"       "Memory API Docs"
check_http "http://127.0.0.1:8220/docs"       "Unified API Docs"
check_http "http://127.0.0.1:8221/docs"       "Unified Gateway Docs"
check_http "http://127.0.0.1:8222/docs"       "Learning Gateway Docs"

section "6) العمليات النشطة (uvicorn / python3 / ollama)"

ps aux | egrep 'uvicorn|smart_core.app|apps.unified|apps.memory_api|factory.gateway|ollama' | egrep -v 'grep' || echo "لا توجد عمليات uvicorn/ollama ظاهرة في ps aux."

section "7) ملخص سريع لقواعد المعرفة (لو sqlite3 متاح)"

if command -v sqlite3 >/dev/null 2>&1 && [ -f "$LEGACY_DB" ]; then
    echo "📊 إحصائيات knowledge_base من smart_memory.db:"
    sqlite3 "$LEGACY_DB" "
        SELECT 'إجمالي السجلات: ' || COUNT(*) FROM knowledge_base;
        SELECT 'عدد التصنيفات: ' || COUNT(DISTINCT category) FROM knowledge_base;
        SELECT 'أقدم سجل: ' || MIN(created_at) FROM knowledge_base;
        SELECT 'أحدث سجل: ' || MAX(created_at) FROM knowledge_base;
    " || true
else
    warn "لا يمكن قراءة إحصائيات knowledge_base (sqlite3 غير متاح أو smart_memory.db غير موجودة)."
fi

section "8) استدعاء تقارير سابقة (إن وُجدت) كملاحق"

if [ -x /root/sf_unify_final_diag.sh ]; then
    echo ">>> مرفق: sf_unify_final_diag.sh"
    /root/sf_unify_final_diag.sh || warn "sf_unify_final_diag.sh أعاد خطأ."
fi

if [ -x /root/sf_final_unified_audit.sh ]; then
    echo
    echo ">>> مرفق: sf_final_unified_audit.sh"
    /root/sf_final_unified_audit.sh || warn "sf_final_unified_audit.sh أعاد خطأ."
fi

if [ -x /root/sf_complete_health_check.sh ]; then
    echo
    echo ">>> مرفق: sf_complete_health_check.sh"
    /root/sf_complete_health_check.sh || warn "sf_complete_health_check.sh أعاد خطأ."
fi

if [ -x /root/sf_comprehensive_status_check.sh ]; then
    echo
    echo ">>> مرفق: sf_comprehensive_status_check.sh"
    /root/sf_comprehensive_status_check.sh || warn "sf_comprehensive_status_check.sh أعاد خطأ."
fi

if [ -x /root/sf_generate_system_report.sh ]; then
    echo
    echo ">>> مرفق: sf_generate_system_report.sh"
    /root/sf_generate_system_report.sh || warn "sf_generate_system_report.sh أعاد خطأ."
fi

section "9) الملخص النهائي للـ Master Check"

echo "إجمالي OK   : $OK_COUNT"
echo "إجمالي WARN : $WARN_COUNT"
echo "إجمالي FAIL : $FAIL_COUNT"
echo

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "🚨 الحالة العامة: RED – هناك أخطاء يجب معالجتها قبل اعتبار النظام جاهزاً إنتاجياً."
elif [ "$WARN_COUNT" -gt 0 ]; then
    echo "⚠️  الحالة العامة: YELLOW – النظام يعمل، مع تحذيرات (خاصة في الخدمات أو السياسات)."
else
    echo "✅ الحالة العامة: GREEN – كل شيء يبدو متناسقاً وسليماً."
fi

echo
echo "📄 تم إنشاء هذا التقرير في: $REPORT"

} | tee "$REPORT"

