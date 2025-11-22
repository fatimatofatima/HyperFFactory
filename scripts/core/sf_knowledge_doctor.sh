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

echo "================================================================"
echo "   🧠 SmartFriend Knowledge Doctor"
echo "================================================================"
echo

for db in "${DBS[@]}"; do
  if [ ! -f "$db" ]; then
    warn "تخطي (DB غير موجودة): $db"
    continue
  fi

  size_bytes=$(stat -c '%s' "$db" 2>/dev/null || echo 0)
  size_human=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null || echo "${size_bytes}B")
  tables_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")"

  echo "------------------------------------------------------------"
  log "قاعدة: $db"
  info "الحجم: $size_human | عدد الجداول: $tables_count"

  # دوال مساعدة محلية
  count_table() {
    local t="$1"
    sqlite3 "$db" "SELECT COUNT(*) FROM $t;" 2>/dev/null || echo "-"
  }

  last_created() {
    local t="$1"
    sqlite3 "$db" "SELECT MAX(created_at) FROM $t;" 2>/dev/null || echo "-"
  }

  # sessions
  s_count=$(count_table "sessions")
  if [ "$s_count" != "-" ]; then
    info "📚 sessions: $s_count (آخر created_at: $(last_created "sessions"))"
  else
    warn "لا توجد sessions (أو جدول sessions غير معرف)"
  fi

  # messages
  m_count=$(count_table "messages")
  if [ "$m_count" != "-" ]; then
    info "💬 messages: $m_count (آخر created_at: $(last_created "messages"))"
  else
    warn "لا توجد messages (أو جدول messages غير معرف)"
  fi

  # knowledge_items
  k_count=$(count_table "knowledge_items")
  if [ "$k_count" != "-" ]; then
    info "🧠 knowledge_items: $k_count (آخر created_at: $(last_created "knowledge_items"))"
  else
    warn "لا توجد knowledge_items (أو جدول knowledge_items غير معرف)"
  fi
done

echo
log "انتهى فحص طبقة المعرفة."
echo "================================================================"
