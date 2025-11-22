#!/usr/bin/env bash
set -Eeuo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }
err(){ echo -e "${RED}[✗]${NC} $*"; }

echo "==========================================="
echo "   🛠️  SmartFriend - Schema Fix (Phase A)"
echo "   🔒 READ/WRITE WITH BACKUP"
echo "==========================================="
echo

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/var/lib/smartfrind/backup"
mkdir -p "$BACKUP_DIR"

DB_MAIN="/var/lib/smartfrind/smart_memory.db"
DB_CORE="/opt/smartfrind/data/smartfrind.db"

# 1) Backup أولاً
info "1. 📦 Creating backups..."
cp "$DB_MAIN" "$BACKUP_DIR/smart_memory_${TS}.db"
cp "$DB_CORE" "$BACKUP_DIR/smartfrind_${TS}.db"
ok "   Backup created: $BACKUP_DIR/smart_memory_${TS}.db"
ok "   Backup created: $BACKUP_DIR/smartfrind_${TS}.db"

# 2) إصلاح smart_memory.db - user_long_term_memory
info "2. 🔧 Fixing smart_memory.db schema..."
sqlite3 "$DB_MAIN" "
-- إنشاء user_long_term_memory إذا لم يكن موجوداً
CREATE TABLE IF NOT EXISTS user_long_term_memory(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT,
  raw_text TEXT,
  summary TEXT,
  category TEXT,
  tags TEXT,
  importance INTEGER,
  personal_level INTEGER,
  embedding BLOB,
  is_active INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- إضافة أعمدة إذا كانت ناقصة (باستخدام try/catch في SQLite)
BEGIN;
ALTER TABLE user_long_term_memory ADD COLUMN session_id TEXT;
ALTER TABLE user_long_term_memory ADD COLUMN memory_type TEXT DEFAULT 'general';
COMMIT;
" 2>/dev/null && ok "   smart_memory.db schema updated" || warn "   Some columns may already exist"

# 3) إصلاح smartfrind.db - conscious_memory
info "3. 🔧 Fixing smartfrind.db schema..."
sqlite3 "$DB_CORE" "
-- إنشاء conscious_memory من DDL في app/core.py
CREATE TABLE IF NOT EXISTS conscious_memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  memory_type TEXT NOT NULL,
  content TEXT NOT NULL,
  embedding BLOB,
  importance REAL DEFAULT 0.5,
  confidence REAL DEFAULT 0.5,
  sentiment REAL DEFAULT 0.0,
  urgency REAL DEFAULT 0.0,
  category TEXT,
  tags_json TEXT,
  entities_json TEXT,
  metadata_json TEXT,
  accessed_count INTEGER DEFAULT 0,
  last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- إنشاء indexes لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_conscious_user ON conscious_memory(user_id);
CREATE INDEX IF NOT EXISTS idx_conscious_type ON conscious_memory(memory_type);
CREATE INDEX IF NOT EXISTS idx_conscious_category ON conscious_memory(category);
"

ok "   smartfrind.db schema updated with conscious_memory"

# 4) التحقق من الإصلاح
info "4. 🔍 Verifying fixes..."
echo "   Tables in smart_memory.db:"
sqlite3 "$DB_MAIN" ".tables" | grep -E "user_long_term_memory|knowledge_base" | while read table; do
    count=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
    ok "      $table: $count rows"
done

echo "   Tables in smartfrind.db:"
sqlite3 "$DB_CORE" ".tables" | grep -E "conscious_memory|knowledge_base" | while read table; do
    count=$(sqlite3 "$DB_CORE" "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "0")
    ok "      $table: $count rows"
done

echo
ok "✅ Phase A completed - Schema fixed with backups"
echo "   Next: Run Phase B to fill knowledge_base"
