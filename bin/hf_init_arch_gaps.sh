#!/usr/bin/env bash
# HyperFFactory – Initialize Architecture Gaps (Identity / Knowledge / Memory / Lakehouse / Factories / Agents)
# الاستخدام:
#   bin/hf_init_arch_gaps.sh              # يفترض /root/HyperFFactory
#   bin/hf_init_arch_gaps.sh /path/root   # لو اختلف الجذر

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"

if [ ! -d "$ROOT" ]; then
  echo "❌ ROOT غير موجود: $ROOT"
  exit 1
fi

cd "$ROOT"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

ensure_dir() {
  local d="$1"
  if [ ! -d "$d" ]; then
    mkdir -p "$d"
    log "📁 إنشاء مجلد: $d"
  else
    log "📁 موجود مسبقًا: $d"
  fi
}

ensure_sqlite_schema() {
  local db_path="$1"
  local schema_sql="$2"

  if [ -f "$db_path" ]; then
    log "🗄️ قاعدة موجودة مسبقًا (لن أغيّرها): $db_path"
    return 0
  fi

  log "🗄️ إنشاء قاعدة جديدة: $db_path"
  sqlite3 "$db_path" "$schema_sql"
  log "✅ تم تهيئة المخطط في: $db_path"
}

ensure_file() {
  local path="$1"
  local content="$2"

  if [ -f "$path" ]; then
    log "📄 ملف موجود مسبقًا (لن أعدّل): $path"
    return 0
  fi

  printf "%s\n" "$content" > "$path"
  log "📄 إنشاء ملف جديد: $path"
}

echo "=================================================="
echo "🚀 HyperFFactory – Initialize Architecture Gaps"
echo "ROOT: $ROOT"
echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

# 1) المجلدات الأساسية
log "== 1) إنشاء هياكل المجلدات الأساسية =="

# DB layers
ensure_dir "db"
ensure_dir "db/identity"
ensure_dir "db/knowledge"
ensure_dir "db/memory"

# Lakehouse
ensure_dir "data_lakehouse"
ensure_dir "data_lakehouse/raw"
ensure_dir "data_lakehouse/cleansed"
ensure_dir "data_lakehouse/semantic"
ensure_dir "data_lakehouse/serving"

# Factories
ensure_dir "factories"
ensure_dir "factories/models"
ensure_dir "factories/knowledge"
ensure_dir "factories/quality"

# Agents
ensure_dir "agents"
ensure_dir "agents/debug_expert"
ensure_dir "agents/system_architect"
ensure_dir "agents/knowledge_spider"
ensure_dir "agents/memory_curator"

# 2) تهيئة قواعد الهوية / المعرفة / الذاكرة
log "== 2) تهيئة قواعد الهوية / المعرفة / الذاكرة =="

IDENTITY_DB="db/identity/identity.db"
KNOWLEDGE_DB="db/knowledge/knowledge.db"
MEMORY_DB="db/memory/memory.db"

IDENTITY_SCHEMA="
CREATE TABLE IF NOT EXISTS identity_entities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source      TEXT,
  external_id TEXT,
  kind        TEXT,
  label       TEXT,
  meta_json   TEXT,
  created_at  TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS identity_links (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  from_entity_id INTEGER,
  to_entity_id   INTEGER,
  relation       TEXT,
  weight         REAL,
  meta_json      TEXT,
  created_at     TEXT DEFAULT CURRENT_TIMESTAMP
);
"

KNOWLEDGE_SCHEMA="
CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source      TEXT,
  path        TEXT,
  title       TEXT,
  tags        TEXT,
  meta_json   TEXT,
  created_at  TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id INTEGER,
  chunk_index INTEGER,
  content     TEXT,
  embedding_ref TEXT,
  meta_json   TEXT,
  created_at  TEXT DEFAULT CURRENT_TIMESTAMP
);
"

MEMORY_SCHEMA="
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor       TEXT,
  scope       TEXT,
  kind        TEXT,
  payload_json TEXT,
  created_at  TEXT DEFAULT CURRENT_TIMESTAMP
);
"

ensure_sqlite_schema "$IDENTITY_DB"  "$IDENTITY_SCHEMA"
ensure_sqlite_schema "$KNOWLEDGE_DB" "$KNOWLEDGE_SCHEMA"
ensure_sqlite_schema "$MEMORY_DB"    "$MEMORY_SCHEMA"

# 3) ملفات الإعداد (Config Layer)
log "== 3) إنشاء ملفات Config الأساسية (لو غير موجودة) =="

ensure_dir "config"

ensure_file "config/identity_config.yaml" "$(cat <<'YAML'
# HyperFFactory – Identity Config
root: db/identity/identity.db
role: identity_registry
description: >
  سجل الهوية الرئيسي (entities + links) المستخدم لربط HyperFFactory
  مع SmartFriend Suite و FFactory على مستوى الكيانات.
YAML
)"

ensure_file "config/knowledge_config.yaml" "$(cat <<'YAML'
# HyperFFactory – Knowledge Config
root: db/knowledge/knowledge.db
role: knowledge_store
description: >
  مستودع المعرفة للمستندات والـ chunks الدلالية المرتبطة بالملفات،
  الويب، والتوثيق الداخلي.
YAML
)"

ensure_file "config/memory_config.yaml" "$(cat <<'YAML'
# HyperFFactory – Memory Config
root: db/memory/memory.db
role: operational_memory
description: >
  ذاكرة تشغيلية لتسجيل الأحداث على مستوى HyperFFactory
  (actors, scopes, payload).
YAML
)"

# 4) تهيئة الـ Agents (stubs)
log "== 4) تهيئة Agents Stubs =="

init_agent() {
  local name="$1"
  local desc="$2"

  ensure_dir "agents/$name"

  # run.sh
  if [ ! -f "agents/$name/run.sh" ]; then
    cat > "agents/$name/run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
cd "$ROOT"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Agent stub – not implemented yet."
SH
    chmod +x "agents/$name/run.sh"
    log "🤖 إنشاء agents/$name/run.sh (stub)"
  else
    log "🤖 agents/$name/run.sh موجود مسبقًا"
  fi

  # README
  if [ ! -f "agents/$name/README.md" ]; then
    printf "# Agent: %s\n\n%s\n" "$name" "$desc" > "agents/$name/README.md"
    log "📝 إنشاء agents/$name/README.md"
  else
    log "📝 agents/$name/README.md موجود مسبقًا"
  fi
}

init_agent "debug_expert" "مسؤول تحليل الأعطال واللوج وربطها بقواعد hf_errors/hf_quality."
init_agent "system_architect" "مسؤول مواءمة الخطة المعمارية مع التنفيذ (plans + config + db/meta)."
init_agent "knowledge_spider" "مسؤول جمع المعرفة من الملفات/الويب وتخزينها في db/knowledge."
init_agent "memory_curator" "مسؤول تنظيم أحداث الذاكرة التشغيلية في db/memory وربطها بالهوية."

echo "--------------------------------------------------"
echo "✅ تم تنفيذ hf_init_arch_gaps.sh بدون حذف أي بيانات."
echo "  - DBs: identity / knowledge / memory"
echo "  - Lakehouse dirs: data_lakehouse/{raw,cleansed,semantic,serving}"
echo "  - Factories dirs: factories/{models,knowledge,quality}"
echo "  - Agents stubs: debug_expert, system_architect, knowledge_spider, memory_curator"
echo "=================================================="
