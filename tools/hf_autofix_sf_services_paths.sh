#!/usr/bin/env bash
# HyperFFactory – Auto-fix sf-core/sf-health/sf-memory/sf-web Python roots & WD

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_autofix_sf_services_paths_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

create_dropin() {
  local unit="$1"
  local content="$2"
  local dir="/etc/systemd/system/${unit}.service.d"
  mkdir -p "$dir"
  local file="${dir}/70-hf-autopath.conf"
  printf '%s\n' "$content" > "$file"
  log "✅ كتبنا $file"
}

find_module_root() {
  local label="$1"    # وصف للخدمة
  local pattern="$2"  # مثال: services/ffactory/simple_api.py
  local file="${pattern##*/}"   # simple_api.py

  log "▶️ البحث عن ${label}: pattern=${pattern}"

  local search_roots=(
    "/root/HyperFFactory"
    "/root/HyperFFactory/opt"
    "/root/HyperFFactory/opt/smartfriend-suite"
    "/opt/smartfriend-suite"
    "/opt/smartfriend-suite/smartfriend"
    "/opt/smartfriend-suite/smartfriend/app"
    "/opt/ffactory"
    "/opt/ffactory/app"
  )

  local matches=()
  for base in "${search_roots[@]}"; do
    [ -d "$base" ] || continue
    while IFS= read -r p; do
      matches+=( "$p" )
    done < <(find "$base" -maxdepth 7 -type f -name "$file" 2>/dev/null || true)
  done

  if [ "${#matches[@]}" -eq 0 ]; then
    log "⚠️ لم يتم العثور على أي ملف باسم $file في المسارات المتوقعة"
    return 1
  fi

  log "ℹ️ تم العثور على ${#matches[@]} مسار(ات) لـ $file:"
  for p in "${matches[@]}"; do
    log "   - $p"
  done

  local chosen=""
  for p in "${matches[@]}"; do
    case "$p" in
      *"/${pattern}") chosen="$p"; break ;;
    esac
  done

  if [ -z "$chosen" ]; then
    chosen="${matches[0]}"
    log "⚠️ لم نجد مسارًا يطابق pattern بالكامل؛ سنستخدم أول مسار: $chosen"
  else
    log "✅ اختيار المسار المطابق: $chosen"
  fi

  local root="${chosen%/$pattern}"
  echo "$root"
  return 0
}

log "====================================================="
log "HyperFFactory – Auto-fix sf-* Python roots (core/health/memory/web)"
log "ROOT : $ROOT"
log "TIME : $TS"
log "====================================================="

CORE_ROOT="$(find_module_root 'sf-core (services.ffactory.simple_api)' 'services/ffactory/simple_api.py' || true)"
MEM_ROOT="$(find_module_root 'sf-memory (apps.memory_api)' 'apps/memory_api.py' || true)"
HEALTH_ROOT="$(find_module_root 'sf-health (ops.health_gate)' 'ops/health_gate.py' || true)"

if [ -n "$CORE_ROOT" ]; then
  create_dropin "sf-core" "[Service]
WorkingDirectory=${CORE_ROOT}
Environment=PYTHONPATH=${CORE_ROOT}"
else
  log "⚠️ لن نعدل sf-core (لم نحدد ROOT)"
fi

if [ -n "$MEM_ROOT" ]; then
  create_dropin "sf-memory" "[Service]
WorkingDirectory=${MEM_ROOT}
Environment=PYTHONPATH=${MEM_ROOT}"
else
  log "⚠️ لن نعدل sf-memory (لم نحدد ROOT)"
fi

if [ -n "$HEALTH_ROOT" ]; then
  create_dropin "sf-health" "[Service]
WorkingDirectory=${HEALTH_ROOT}
Environment=PYTHONPATH=${HEALTH_ROOT}"
else
  log "⚠️ لن نعدل sf-health (لم نحدد ROOT)"
fi

# sf-web: WorkingDirectory = /opt/smartfriend-suite
if [ -f "/etc/systemd/system/sf-web.service" ]; then
  WEB_ROOT="/opt/smartfriend-suite"
  if [ -d "$WEB_ROOT" ]; then
    create_dropin "sf-web" "[Service]
WorkingDirectory=${WEB_ROOT}
Environment=PYTHONPATH=${WEB_ROOT}"
  else
    log "⚠️ /opt/smartfriend-suite غير موجود – لن نعدل sf-web"
  fi
else
  log "ℹ️ sf-web.service غير موجود (تخطي)"
fi

log "▶️ systemctl daemon-reload"
systemctl daemon-reload

for unit in sf-core sf-health sf-memory sf-web; do
  if systemctl list-unit-files | grep -q "^${unit}.service"; then
    log "▶️ إعادة تشغيل ${unit}.service"
    if systemctl restart "${unit}.service"; then
      log "✅ ${unit}.service تم إعادة تشغيله"
    else
      log "⚠️ فشل في إعادة تشغيل ${unit}.service – راجع journalctl -u ${unit}.service"
    fi
  fi
done

log "▶️ systemctl --no-pager -l status sf-core sf-health sf-memory sf-web | sed -n '1,200p'"
systemctl --no-pager -l status sf-core sf-health sf-memory sf-web | sed -n '1,200p' | tee -a "$LOG" || true

log "▶️ اختبار /health (ذاكرة / هيلث / ويب)"
{
  echo "---- curl 8214 (memory) ----"
  curl -s http://127.0.0.1:8214/health || echo "❌ Memory API غير متاح"
  echo
  echo "---- curl 8215 (health) ----"
  curl -s http://127.0.0.1:8215/health || echo "❌ Health API غير متاح"
  echo
  echo "---- curl 8390 (web) ----"
  curl -s http://127.0.0.1:8390/health || echo "❌ Web UI غير متاح"
  echo
} | tee -a "$LOG" || true

log "====================================================="
log "✅ انتهى hf_autofix_sf_services_paths – راجع $LOG"
log "====================================================="
