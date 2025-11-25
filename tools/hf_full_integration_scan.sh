#!/usr/bin/env bash
# HF Full Integration Scan
# فحص تكامل HyperFFactory + SmartFriend Suite + ffactory + أنظمة التحليل/الأنماط
set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="$HYPER_ROOT/reports"
REPORT="$REPORT_DIR/hf_full_integration_scan_${TS}.log"

mkdir -p "$REPORT_DIR"

# ألوان بسيطة (اختيارية)
RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
BLUE="$(printf '\033[34m')"
NC="$(printf '\033[0m')"

log() {
  echo -e "$@" | tee -a "$REPORT"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

SUMMARY=()

add_summary() {
  SUMMARY+=("$1")
}

section() {
  log ""
  log "====================================================="
  log "$1"
  log "====================================================="
}

log "====================================================="
log "HyperFFactory – Full Integration Scan"
log "ROOT   : $HYPER_ROOT"
log "TIME   : $TS"
log "REPORT : $REPORT"
log "====================================================="

########################################
# 1) فحص قواعد البيانات الميتا (META DBs)
########################################
section "1) META DBs (hf_ops_meta / hf_quality / hf_learning / hf_errors)"

META_DIR="$HYPER_ROOT/db/meta"
if [ -d "$META_DIR" ]; then
  if ! have_cmd sqlite3; then
    log "${YELLOW}[WARN] sqlite3 غير موجود؛ سيتم الاكتفاء بفحص وجود الملفات فقط.${NC}"
    ls -1 "$META_DIR"/*.db 2>/dev/null | sed 's/^/  - /' | tee -a "$REPORT" || true
    add_summary "META DBs: موجودة لكن بدون sqlite3 (فحص سطحي فقط)."
  else
    for DB in "$META_DIR"/*.db; do
      [ -e "$DB" ] || continue
      DB_NAME="$(basename "$DB")"
      log ""
      log "---- DB: $DB_NAME ----"
      # جداول
      TABLES="$(sqlite3 "$DB" ".tables" 2>/dev/null || echo "")"
      if [ -z "$TABLES" ]; then
        log "  ${YELLOW}No tables or DB empty.${NC}"
      else
        log "  Tables:"
        echo "$TABLES" | sed 's/^/    - /' | tee -a "$REPORT"
        # نحاول عد الجداول المهمة لو موجودة
        for T in tasks quality errors learning changes workers; do
          if echo "$TABLES" | grep -qw "$T"; then
            COUNT="$(sqlite3 "$DB" "SELECT COUNT(*) FROM $T;" 2>/dev/null || echo "ERR")"
            log "    * $T: $COUNT rows"
          fi
        done
      fi
    done
    add_summary "META DBs: تم فحص hf_ops_meta / hf_quality / hf_learning / hf_errors بنجاح."
  fi
else
  log "${RED}[ERR] مجلد META DB غير موجود: $META_DIR${NC}"
  add_summary "META DBs: مفقودة (db/meta غير موجودة)."
fi

########################################
# 2) فحص SmartFriend Suite (systemd + HTTP)
########################################
section "2) SmartFriend Suite – Services & HTTP Health"

SF_ROOT="/opt/smartfriend-suite"
if [ -d "$SF_ROOT" ]; then
  log "Root: $SF_ROOT (exists: YES)"
else
  log "${YELLOW}[WARN] لم أجد /opt/smartfriend-suite – سيتم الفحص من زاوية الخدمات فقط.${NC}"
fi

if have_cmd systemctl; then
  SF_SERVICES=(
    sf-core.service
    sf-web.service
    sf-health.service
    sf-memory.service
    sf-bot.service
    sf-bot-assistant.service
    sf-bot-pro.service
    sf-bot-mod.service
  )

  log "---- حالة خدمات sf-* (systemd) ----"
  for SVC in "${SF_SERVICES[@]}"; do
    STATE="$(systemctl is-active "$SVC" 2>/dev/null || echo "not-found")"
    case "$STATE" in
      active)
        log "  ${GREEN}$SVC : active${NC}"
        ;;
      inactive|failed)
        log "  ${YELLOW}$SVC : $STATE${NC}"
        ;;
      not-found)
        log "  ${YELLOW}$SVC : not defined on this server${NC}"
        ;;
      *)
        log "  ${YELLOW}$SVC : $STATE${NC}"
        ;;
    esac
  done
else
  log "${YELLOW}[WARN] systemctl غير متوفر – تخطي فحص خدمات sf-*${NC}"
fi

# HTTP health checks
if have_cmd curl; then
  http_check() {
    local name="$1"
    local url="$2"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo "000")"
    if [ "$code" = "200" ]; then
      log "  ${GREEN}$name → $url : HTTP 200 OK${NC}"
    elif [ "$code" = "000" ]; then
      log "  ${YELLOW}$name → $url : لا يوجد رد (connection failed)${NC}"
    else
      log "  ${YELLOW}$name → $url : HTTP $code${NC}"
    fi
  }

  log "---- HTTP Health للـ SmartFriend Suite ----"
  http_check "sf-core"   "http://127.0.0.1:8383/health"
  http_check "sf-memory" "http://127.0.0.1:8214/health"
  http_check "sf-health" "http://127.0.0.1:8215/health"
  http_check "sf-web"    "http://127.0.0.1:8390/health"
  http_check "sf-gateway" "http://127.0.0.1:8220/health"
  add_summary "SmartFriend Suite: تم فحص systemd + HTTP health (8383/8214/8215/8390/8220)."
else
  log "${YELLOW}[WARN] curl غير متوفر – تخطي فحص HTTP.${NC}"
  add_summary "SmartFriend Suite: تم فحص systemd فقط (بدون HTTP)."
fi

########################################
# 3) فحص ffactory (Docker stack + compose reference)
########################################
section "3) ffactory – Docker stack & compose mapping"

FF_ROOT="/opt/ffactory"
if [ -d "$FF_ROOT" ]; then
  log "Root: $FF_ROOT (exists: YES)"
else
  log "${YELLOW}[WARN] لم أجد /opt/ffactory – قد تكون ffactory في مسار آخر.${NC}"
fi

if have_cmd docker; then
  log "---- حاويات تتضمن ffactory / hyper_ffactory / hyper_ai ----"
  docker ps --format '  - {{.Names}} | {{.Image}} | {{.Status}}' \
    | grep -Ei 'ffactory|hyper_ffactory|hyper_ai_gateway|hyper_smartfriend' \
    || echo "  (لا توجد حاويات مطابقة حالياً)" | tee -a "$REPORT"

  # محاولة اكتشاف الـ compose من أول حاوية ffactory لها labels
  FF_CONTAINER="$(docker ps --format '{{.Names}}' | grep -Ei 'ffactory|hyper_ffactory' | head -n1 || true)"
  if [ -n "$FF_CONTAINER" ]; then
    log ""
    log "---- محاولة استنتاج مسار docker-compose من الحاوية: $FF_CONTAINER ----"
    WORKDIR="$(docker inspect "$FF_CONTAINER" \
      --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' 2>/dev/null || true)"
    FILES="$(docker inspect "$FF_CONTAINER" \
      --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}' 2>/dev/null || true)"

    [ -z "$WORKDIR" ] && WORKDIR="<no-label>"
    [ -z "$FILES" ] && FILES="<no-label>"

    log "  compose working_dir label : $WORKDIR"
    log "  compose config_files label: $FILES"

    if [ "$WORKDIR" != "<no-label>" ] && [ "$FILES" != "<no-label>" ]; then
      log "  ملاحظة: يمكنك استخدام هذا المسار كمصدر رسمي ثم نسخه تحت /opt/ffactory/stack/docker-compose.core.yml عند الحاجة."
    else
      log "  ${YELLOW}لم أجد labels كاملة للـ compose؛ قد يكون الـ stack بدأ بطريقة مختلفة.${NC}"
    fi
  else
    log "${YELLOW}[WARN] لم أجد أي حاوية ffactory* حالية لأخذ labels منها.${NC}"
  fi

  # فحص وجود compose تحت /opt/ffactory/stack
  STACK_DIR="$FF_ROOT/stack"
  if [ -d "$STACK_DIR" ]; then
    log ""
    log "---- محتويات /opt/ffactory/stack ----"
    find "$STACK_DIR" -maxdepth 2 -type f -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' 2>/dev/null \
      | sed 's/^/  - /' | tee -a "$REPORT" || echo "  (لا توجد ملفات docker-compose تحت stack)"
  else
    log "${YELLOW}[WARN] /opt/ffactory/stack غير موجود حالياً.${NC}"
  fi

  add_summary "ffactory: تم فحص الحاويات الحالية ومحاولة استنتاج compose + التحقق من /opt/ffactory/stack."
else
  log "${YELLOW}[WARN] docker غير متوفر – تخطي فحص ffactory stack.${NC}"
  add_summary "ffactory: تخطي فحص الحاويات (docker غير متوفر)."
fi

########################################
# 4) فحص أنظمة التحليل / الأنماط / السلوك (Behavioral / Pattern Systems)
########################################
section "4) Behavioral / Pattern / Analytics Systems (الشخصية والسلوك)"

# نحاول رصد أي مكوّنات تحليل/أنماط في شجرة HyperFFactory (ai / factories / patterns / analytics)
SEARCH_DIRS=(
  "$HYPER_ROOT/ai"
  "$HYPER_ROOT/factories"
  "$HYPER_ROOT/data"
  "$HYPER_ROOT/config"
  "$HYPER_ROOT/scripts"
  "$HYPER_ROOT/workers"
)

log "---- مجلدات محتملة لنظام التحليل السلوكي / الأنماط ----"
for D in "${SEARCH_DIRS[@]}"; do
  if [ -d "$D" ]; then
    log "  [OK] $D"
  else
    log "  [..] $D (غير موجود حالياً)"
  fi
done

log ""
log "---- ملفات تشير إلى patterns / behavior / timeline / analytics (عين سريعة) ----"
# نحد عدد النتائج علشان التقرير ما ينفجرش
PATTERN_KEYS='pattern|patterns|behavior|behaviour|timeline|analytics|anomaly|sequence|matrix|falcon|hawk'
grep -RniE "$PATTERN_KEYS" \
  ai factories data config scripts workers 2>/dev/null \
  | head -n 80 \
  | sed 's/^/  /' \
  | tee -a "$REPORT" || echo "  (لا توجد مراجع نصية واضحة في المسارات المحددة)" | tee -a "$REPORT"

add_summary "Behavioral/Pattern Systems: تم مسح ai/factories/data/config/scripts/workers للبحث عن مفاتيح الأنماط والسلوك."

########################################
# 5) فحص جذور أنظمة أخرى (مثل Psmart إن وجد)
########################################
section "5) جذور أنظمة أخرى (مثلاً Psmart) – مجرد كشف هوية"

PSMART_ROOT="/root/Psmart"
if [ -d "$PSMART_ROOT" ]; then
  log "Root: $PSMART_ROOT (exists: YES)"
  log "  بعض المجلدات الأساسية (عمق 1):"
  find "$PSMART_ROOT" -maxdepth 2 -mindepth 1 -type d 2>/dev/null \
    | head -n 20 \
    | sed 's/^/    - /' | tee -a "$REPORT"
  add_summary "Psmart: موجود وتم رصد هيكل أولي (بدون تعديل)."
else
  log "Psmart: لم أجد /root/Psmart (قد يكون في مكان آخر أو غير موجود حالياً)."
  add_summary "Psmart: غير مرصود في /root حالياً."
fi

########################################
# 6) ملخص تنفيذي
########################################
section "6) الملخص التنفيذي (Integration Health Snapshot)"

for LINE in "${SUMMARY[@]}"; do
  log " - $LINE"
done

log ""
log "====================================================="
log "تم الانتهاء من فحص التكامل الكامل."
log "راجع التقرير الكامل في:"
log "  $REPORT"
log "====================================================="
