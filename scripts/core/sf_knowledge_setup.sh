#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

if ! have sqlite3; then
  error "sqlite3 غير مثبت. نفّذ: apt update && apt install -y sqlite3"
  exit 1
fi

# قواعد البيانات الأساسية للمعرفة/الذاكرة
CORE_DIR="/opt/smartfriend-suite"
DBS=(
  "${CORE_DIR}/memory.db"
  "${CORE_DIR}/smart_core_memory.db"
  "${CORE_DIR}/unified_memory.db"
  "${CORE_DIR}/smartfriend_unified.db"
)

# سكيمـا أساسي للمعرفة
base_schema() {
  cat <<'SQL'
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id TEXT,
  user_id TEXT,
  title TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER,
  role TEXT,
  content TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS knowledge_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source TEXT,
  key TEXT,
  value TEXT,
  score REAL,
  tags TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_source ON knowledge_items(source);
CREATE INDEX IF NOT EXISTS idx_knowledge_created_at ON knowledge_items(created_at);
SQL
}

log "🚀 إعداد طبقة المعرفة والخبرة (SmartFriend Knowledge Plane)"
log "📂 جذر SmartFriend Suite: $CORE_DIR"
echo

for db in "${DBS[@]}"; do
  dir="$(dirname "$db")"
  mkdir -p "$dir"

  if [ ! -f "$db" ]; then
    log "🆕 إنشاء قاعدة بيانات جديدة: $db"
    base_schema | sqlite3 "$db"
    sqlite3 "$db" "INSERT OR REPLACE INTO meta(key,value) VALUES('created_by','sf_knowledge_setup');"
    continue
  fi

  # قاعدة موجودة – نفحص عدد الجداول
  tables_count="$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" || echo "0")"
  if [ "$tables_count" = "0" ]; then
    warn "قاعدة موجودة لكن بدون جداول: $db – سيتم تطبيق سكيمـا المعرفة الأساسية"
    base_schema | sqlite3 "$db"
    sqlite3 "$db" "INSERT OR REPLACE INTO meta(key,value) VALUES('initialized_by','sf_knowledge_setup');"
  else
    log "✅ قاعدة المعرفة جاهزة: $db (عدد الجداول: $tables_count)"
  fi
done

log "✅ انتهى إعداد طبقة المعرفة."
