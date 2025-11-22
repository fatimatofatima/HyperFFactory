#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }
info()  { echo -e "${CYAN}[ℹ] $*${NC}"; }

have() { command -v "$1" >/dev/null 2>&1; }

if [ $# -lt 1 ]; then
  echo "Usage: $0 {vacuum|analyze|compact|daily}"
  exit 1
fi

CMD="$1"

if ! have sqlite3; then
  error "sqlite3 غير مثبت. نفّذ: apt update && apt install -y sqlite3"
  exit 1
fi

CORE_DIR="/opt/smartfriend-suite"
DBS=(
  "${CORE_DIR}/memory.db"
  "${CORE_DIR}/smart_core_memory.db"
  "${CORE_DIR}/unified_memory.db"
  "${CORE_DIR}/smartfriend_unified.db"
)

do_vacuum() {
  log "🧹 VACUUM لقواعد المعرفة"
  for db in "${DBS[@]}"; do
    [ -f "$db" ] || { warn "تخطي (غير موجود): $db"; continue; }
    info "VACUUM: $db"
    sqlite3 "$db" "VACUUM;" || warn "فشل VACUUM على $db"
  done
}

do_analyze() {
  log "📊 ANALYZE لقواعد المعرفة"
  for db in "${DBS[@]}"; do
    [ -f "$db" ] || { warn "تخطي (غير موجود): $db"; continue; }
    info "ANALYZE: $db"
    sqlite3 "$db" "ANALYZE;" || warn "فشل ANALYZE على $db"
  done
}

do_compact() {
  if ! have curl; then
    warn "curl غير مثبت، لن يتم استدعاء Endpoints المعرفة."
    return
  fi

  log "🧠 Nudge لخدمات الذكاء لإعادة بناء/ضغط المعرفة (إن وجدت)"

  # Endpoints افتراضية – لو غير موجودة هتظهر تحذير فقط
  CORE_URL="http://127.0.0.1:8211/admin/knowledge/compact"
  UNIFIED_URL="http://127.0.0.1:8220/admin/knowledge/compact"

  for url in "$CORE_URL" "$UNIFIED_URL"; do
    info "POST $url"
    if ! curl -sS -X POST "$url" -m 10 >/dev/null 2>&1; then
      warn "فشل أو غير مدعوم: $url (لا مشكلة – فقط إعلام)"
    else
      log "✅ نداء ناجح: $url"
    fi
  done
}

case "$CMD" in
  vacuum)
    do_vacuum
    ;;
  analyze)
    do_analyze
    ;;
  compact)
    do_compact
    ;;
  daily)
    log "📅 تشغيل Job يومي كامل (VACUUM + ANALYZE + COMPACT)"
    do_vacuum
    do_analyze
    do_compact
    ;;
  *)
    error "أمر غير معروف: $CMD (استخدم: vacuum | analyze | compact | daily)"
    exit 1
    ;;
esac

log "✅ انتهى sf_knowledge_jobs ($CMD)"
