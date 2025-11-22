#!/usr/bin/env bash
set -euo pipefail

DATA_HOME="/opt/hyper-factory/var/db"

echo "📁 إنشاء شجرة قواعد البيانات في: $DATA_HOME"
mkdir -p \
  "$DATA_HOME/meta" \
  "$DATA_HOME/identity" \
  "$DATA_HOME/memory" \
  "$DATA_HOME/tasks" \
  "$DATA_HOME/skills" \
  "$DATA_HOME/knowledge"

# 1) نسخ hyper_meta.db كمرجع (ميتاداتا فقط)
if [[ -f "/root/HyperFFactory/meta/hyper_meta.db" ]]; then
  cp -n "/root/HyperFFactory/meta/hyper_meta.db" "$DATA_HOME/meta/hyper_meta.db"
  echo "✅ تم نسخ meta/hyper_meta.db إلى $DATA_HOME/meta/"
else
  echo "⚠️ تحذير: لم أجد /root/HyperFFactory/meta/hyper_meta.db – تخطي النسخ."
fi

NOW="$(date +'%Y-%m-%d %H:%M:%S')"

echo "🧬 تهيئة identity.db ..."
sqlite3 "$DATA_HOME/identity/identity.db" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS entities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id TEXT,
  type TEXT NOT NULL,             -- user / agent / service / project / device / server
  name TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_entities_type_status
  ON entities(type, status);

CREATE TABLE IF NOT EXISTS roles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  scope TEXT DEFAULT 'system',    -- system / project / app
  description TEXT
);

CREATE TABLE IF NOT EXISTS role_assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_id INTEGER NOT NULL,
  role_id INTEGER NOT NULL,
  scope TEXT,
  scope_ref TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(entity_id) REFERENCES entities(id),
  FOREIGN KEY(role_id) REFERENCES roles(id)
);

CREATE TABLE IF NOT EXISTS capabilities_profile (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_id INTEGER NOT NULL,
  capability_key TEXT NOT NULL,
  capability_value TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(entity_id, capability_key),
  FOREIGN KEY(entity_id) REFERENCES entities(id)
);
SQL

echo "📋 تهيئة tasks.db ..."
sqlite3 "$DATA_HOME/tasks/tasks.db" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS job_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  default_owner_role TEXT,
  default_priority INTEGER DEFAULT 5,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type_id INTEGER NOT NULL,
  owner_entity_id INTEGER,
  status TEXT NOT NULL DEFAULT 'pending',  -- pending / running / done / failed / cancelled
  priority INTEGER DEFAULT 5,
  created_at TEXT NOT NULL,
  started_at TEXT,
  finished_at TEXT,
  payload_json TEXT,
  result_json TEXT,
  error_message TEXT,
  parent_job_id INTEGER,
  FOREIGN KEY(type_id) REFERENCES job_types(id),
  FOREIGN KEY(owner_entity_id) REFERENCES entities(id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_status_priority
  ON jobs(status, priority);

CREATE TABLE IF NOT EXISTS job_dependencies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  depends_on_job_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY(job_id) REFERENCES jobs(id),
  FOREIGN KEY(depends_on_job_id) REFERENCES jobs(id)
);

CREATE TABLE IF NOT EXISTS job_assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  entity_id INTEGER NOT NULL,
  assigned_at TEXT NOT NULL,
  FOREIGN KEY(job_id) REFERENCES jobs(id),
  FOREIGN KEY(entity_id) REFERENCES entities(id)
);

CREATE TABLE IF NOT EXISTS schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  job_type_id INTEGER NOT NULL,
  cron_expr TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_run_at TEXT,
  next_run_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(job_type_id) REFERENCES job_types(id)
);
SQL

echo "🧠 تهيئة memory_core_2025.db (كأول ملف للذاكرة الزمنية) ..."
sqlite3 "$DATA_HOME/memory/memory_core_2025.db" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  source_entity_id INTEGER,
  event_type TEXT NOT NULL,
  severity TEXT,
  payload_json TEXT,
  FOREIGN KEY(source_entity_id) REFERENCES entities(id)
);

CREATE INDEX IF NOT EXISTS idx_events_type_time
  ON events(event_type, timestamp);

CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  owner_entity_id INTEGER,
  context_json TEXT,
  FOREIGN KEY(owner_entity_id) REFERENCES entities(id)
);

CREATE TABLE IF NOT EXISTS state_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  taken_at TEXT NOT NULL,
  scope TEXT NOT NULL,
  scope_ref TEXT,
  state_hash TEXT,
  summary TEXT,
  state_json TEXT
);
SQL

echo "🎯 تهيئة skills.db ..."
sqlite3 "$DATA_HOME/skills/skills.db" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key TEXT NOT NULL UNIQUE,         -- مثلاً: OCR.ImageResultClassifier
  name TEXT NOT NULL,
  category TEXT,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS skill_versions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  skill_id INTEGER NOT NULL,
  version TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY(skill_id) REFERENCES skills(id)
);

CREATE TABLE IF NOT EXISTS entity_skills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_id INTEGER NOT NULL,
  skill_id INTEGER NOT NULL,
  level INTEGER DEFAULT 1,          -- 1..10 مثلاً
  experience_score REAL DEFAULT 0,
  last_used_at TEXT,
  UNIQUE(entity_id, skill_id),
  FOREIGN KEY(entity_id) REFERENCES entities(id),
  FOREIGN KEY(skill_id) REFERENCES skills(id)
);

CREATE TABLE IF NOT EXISTS experience_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_id INTEGER NOT NULL,
  skill_id INTEGER NOT NULL,
  job_id INTEGER,
  event_time TEXT NOT NULL,
  outcome TEXT,
  details_json TEXT,
  FOREIGN KEY(entity_id) REFERENCES entities(id),
  FOREIGN KEY(skill_id) REFERENCES skills(id),
  FOREIGN KEY(job_id) REFERENCES jobs(id)
);
SQL

echo "📚 تهيئة قواعد بيانات المعرفة (فارغة كهيكل فقط) ..."
sqlite3 "$DATA_HOME/knowledge/knowledge_main.db" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id TEXT,
  source TEXT,
  title TEXT,
  lang TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  meta_json TEXT
);

CREATE TABLE IF NOT EXISTS chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id INTEGER NOT NULL,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  meta_json TEXT,
  FOREIGN KEY(document_id) REFERENCES documents(id)
);

CREATE INDEX IF NOT EXISTS idx_chunks_doc_idx
  ON chunks(document_id, chunk_index);
SQL

sqlite3 "$DATA_HOME/knowledge/knowledge_embeddings.db" <<SQL
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS embeddings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  chunk_id INTEGER NOT NULL,
  model TEXT NOT NULL,
  dim INTEGER,
  vector BLOB,              -- أو TEXT حسب ما تقرر لاحقاً
  created_at TEXT NOT NULL,
  FOREIGN KEY(chunk_id) REFERENCES chunks(id)
);
SQL

echo "✅ تم إنشاء وتهيئة جميع قواعد البيانات الأساسية تحت $DATA_HOME"
