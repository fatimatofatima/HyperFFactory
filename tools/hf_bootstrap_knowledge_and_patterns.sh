#!/usr/bin/env bash
# HyperFFactory – Bootstrap Knowledge & Patterns layer (Phase 3 – جزء 1)

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_DIR="$ROOT/reports"
LOG="$LOG_DIR/hf_bootstrap_knowledge_and_patterns_${TS}.log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d_%H:%M:%S')] $*" | tee -a "$LOG"
}

log "=================================================="
log "🧩 HyperFFactory – Bootstrap Knowledge & Patterns"
log "ROOT : $ROOT"
log "TIME : $TS"
log "LOG  : $LOG"
log "=================================================="

# 1) مجلدات المعرفة الخام والنهائية
KNOW_DIR="$ROOT/knowledge"
KNOW_RAW="$ROOT/data/knowledge_raw"
DB_DIR="$ROOT/db/meta"

mkdir -p "$KNOW_DIR" "$KNOW_RAW" "$DB_DIR"

log "✅ مجلدات المعرفة:"
log "   - $KNOW_DIR"
log "   - $KNOW_RAW"
log "   - $DB_DIR"

KNOW_DB="$DB_DIR/hf_knowledge.db"
PAT_DB="$DB_DIR/hf_patterns.db"

# 2) إنشاء hf_knowledge.db (جداول أساسية)
log "ℹ️ تهيئة قاعدة المعرفة: $KNOW_DB"

sqlite3 "$KNOW_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS knowledge_items (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  source_system TEXT,
  kind          TEXT,
  item_key      TEXT,
  content       TEXT,
  tags          TEXT,
  meta_json     TEXT,
  created_at    TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_knowledge_items_key
  ON knowledge_items(item_key);

CREATE INDEX IF NOT EXISTS idx_knowledge_items_kind
  ON knowledge_items(kind);
SQL

log "✅ إنشاء/تأكيد جداول knowledge_items في $KNOW_DB"

# 3) إنشاء hf_patterns.db (جداول الأنماط)
log "ℹ️ تهيئة قاعدة الأنماط: $PAT_DB"

sqlite3 "$PAT_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS patterns (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  name         TEXT,
  pattern_type TEXT,
  description  TEXT,
  score        REAL,
  meta_json    TEXT,
  created_at   TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_patterns_name
  ON patterns(name);
SQL

log "✅ إنشاء/تأكيد جدول patterns في $PAT_DB"

# 4) Spider PoC – إدخال ملفات نصية من data/knowledge_raw إلى hf_knowledge.db
SPIDER_DIR="$ROOT/scripts/spiders"
SPIDER="$SPIDER_DIR/hf_spider_knowledge_poc.sh"

mkdir -p "$SPIDER_DIR"

if [[ -f "$SPIDER" ]]; then
  log "ℹ️ Spider PoC موجود مسبقاً: $SPIDER"
else
  cat > "$SPIDER" <<'SPIDER_EOF'
#!/usr/bin/env bash
# HyperFFactory – Spider PoC للمعرفة
# يأخذ كل ملف *.txt من data/knowledge_raw ويضيفه إلى knowledge_items.

set -euo pipefail

ROOT="/root/HyperFFactory"
KNOW_RAW="$ROOT/data/knowledge_raw"
KNOW_DB="$ROOT/db/meta/hf_knowledge.db"

cd "$ROOT"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير متوفر في PATH."
  exit 1
fi

echo "🕷 تشغيل Spider PoC – مصدر البيانات: $KNOW_RAW"

shopt -s nullglob
files=("$KNOW_RAW"/*.txt)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ℹ️ لا يوجد ملفات *.txt في $KNOW_RAW – لا يوجد شيء لإدخاله."
  exit 0
fi

for f in "${files[@]}"; do
  base="$(basename "$f")"
  key="${base%.*}"
  # قراءة المحتوى مع استبدال ' بـ '' لتفادي كسر SQL
  content_raw="$(cat "$f")"
  content_escaped="${content_raw//\'/''}"

  sqlite3 "$KNOW_DB" <<SQL
INSERT INTO knowledge_items (source_system, kind, item_key, content, tags, meta_json)
VALUES (
  'local_spider',
  'text_file',
  '$key',
  '$content_escaped',
  NULL,
  NULL
);
SQL

  echo "✅ تم إدخال ملف: $base (key=$key)"
done

echo "✅ Spider PoC انتهى بنجاح."
SPIDER_EOF

  chmod +x "$SPIDER"
  log "✅ إنشاء Spider PoC: $SPIDER"
fi

log "=================================================="
log "✅ Bootstrap Knowledge & Patterns اكتمل."
log "   - KNOW_DB : $KNOW_DB"
log "   - PAT_DB  : $PAT_DB"
log "   - SPIDER  : $SPIDER"
log "=================================================="

echo "✅ تم تنفيذ hf_bootstrap_knowledge_and_patterns بنجاح."
echo "🔎 راجع التقرير: $LOG"
