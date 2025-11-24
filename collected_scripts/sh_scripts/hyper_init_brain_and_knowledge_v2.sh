#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="/opt/hyper-factory/var/db"
YEAR="2025"

echo "🧱 تهيئة طبقة العقل + المعرفة (v2 – بدون لمس identity/memory) في: $RUNTIME_ROOT"

mkdir -p "$RUNTIME_ROOT"/{meta,identity,memory,tasks,skills,knowledge}

IDENTITY_DB="$RUNTIME_ROOT/identity/identity.db"
MEMORY_DB="$RUNTIME_ROOT/memory/memory_core_${YEAR}.db"
TASK_DB="$RUNTIME_ROOT/tasks/tasks.db"
SKILLS_DB="$RUNTIME_ROOT/skills/skills.db"
KNOW_MAIN_DB="$RUNTIME_ROOT/knowledge/knowledge_main.db"
KNOW_FTS_DB="$RUNTIME_ROOT/knowledge/knowledge_fts.db"
KNOW_EMB_DB="$RUNTIME_ROOT/knowledge/knowledge_embeddings.db"

echo "ℹ️ identity.db   موجود – لن يتم تعديل سكيمته: $IDENTITY_DB"
echo "ℹ️ memory_core   موجود – لن يتم تعديل سكيمته: $MEMORY_DB"

# دالة مساعدة: هل القاعدة بلا جداول؟
has_tables() {
  local db="$1"
  if [[ ! -f "$db" ]]; then
    echo 0
    return
  fi
  local cnt
  cnt="$(sqlite3 "$db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo 0)"
  echo "$cnt"
}

############################
# 1) tasks.db – المهام / الـ Workflow
############################
TABLES_TASKS="$(has_tables "$TASK_DB")"
if [[ "$TABLES_TASKS" -eq 0 ]]; then
  echo "🧱 إنشاء سكيمة tasks.db في: $TASK_DB"
  mkdir -p "$(dirname "$TASK_DB")"
  sqlite3 "$TASK_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE job_types (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    code             TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    description      TEXT,
    default_priority INTEGER NOT NULL DEFAULT 5,
    created_at       TEXT NOT NULL
);

CREATE TABLE jobs (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    job_type_id    INTEGER NOT NULL,
    name           TEXT NOT NULL,
    status         TEXT NOT NULL,        -- pending / running / done / failed / cancelled
    priority       INTEGER NOT NULL,     -- 1 (أعلى) .. 10 (أقل)
    created_at     TEXT NOT NULL,
    started_at     TEXT,
    finished_at    TEXT,
    requested_by   INTEGER,              -- entity_id من identity.entities
    payload_json   TEXT,
    result_json    TEXT,
    FOREIGN KEY(job_type_id)  REFERENCES job_types(id)
);

CREATE INDEX idx_jobs_status   ON jobs(status);
CREATE INDEX idx_jobs_type     ON jobs(job_type_id);
CREATE INDEX idx_jobs_created  ON jobs(created_at);

CREATE TABLE job_dependencies (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id      INTEGER NOT NULL,
    depends_on  INTEGER NOT NULL,
    FOREIGN KEY(job_id)     REFERENCES jobs(id),
    FOREIGN KEY(depends_on) REFERENCES jobs(id)
);

CREATE INDEX idx_job_dep_job ON job_dependencies(job_id);

CREATE TABLE job_assignments (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id         INTEGER NOT NULL,
    assignee_id    INTEGER NOT NULL,     -- entity_id (عامل / خدمة)
    assigned_at    TEXT NOT NULL,
    started_at     TEXT,
    finished_at    TEXT,
    status         TEXT NOT NULL DEFAULT 'assigned', -- assigned / in_progress / completed / failed
    notes          TEXT
);

CREATE INDEX idx_job_assign_job    ON job_assignments(job_id);
CREATE INDEX idx_job_assign_agent  ON job_assignments(assignee_id);

CREATE TABLE schedules (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    job_type_id     INTEGER NOT NULL,
    schedule_code   TEXT NOT NULL UNIQUE,
    cron_expr       TEXT NOT NULL,
    enabled         INTEGER NOT NULL DEFAULT 1,
    last_run_at     TEXT,
    next_run_at     TEXT,
    config_json     TEXT,
    created_at      TEXT NOT NULL,
    FOREIGN KEY(job_type_id) REFERENCES job_types(id)
);
SQL
else
  echo "✅ تخطي tasks.db – يحتوي بالفعل على جداول ($TABLES_TASKS)."
fi

############################
# 2) skills.db – المهارات / الخبرات
############################
TABLES_SKILLS="$(has_tables "$SKILLS_DB")"
if [[ "$TABLES_SKILLS" -eq 0 ]]; then
  echo "🧱 إنشاء سكيمة skills.db في: $SKILLS_DB"
  mkdir -p "$(dirname "$SKILLS_DB")"
  sqlite3 "$SKILLS_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE skills (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,   -- OCR.ImageResultClassifier / Knowledge.FTS.Search / ...
    name        TEXT NOT NULL,
    category    TEXT,
    description TEXT,
    created_at  TEXT NOT NULL
);

CREATE TABLE skill_versions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_id    INTEGER NOT NULL,
    version     TEXT NOT NULL,
    meta_json   TEXT,
    created_at  TEXT NOT NULL,
    UNIQUE(skill_id, version),
    FOREIGN KEY(skill_id) REFERENCES skills(id)
);

CREATE TABLE entity_skills (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id          INTEGER NOT NULL,
    skill_id           INTEGER NOT NULL,
    current_version_id INTEGER,
    level              INTEGER NOT NULL DEFAULT 1,  -- 1..5
    confidence         REAL,
    enabled            INTEGER NOT NULL DEFAULT 1,
    created_at         TEXT NOT NULL,
    updated_at         TEXT NOT NULL
);

CREATE INDEX idx_entity_skills_entity ON entity_skills(entity_id);
CREATE INDEX idx_entity_skills_skill  ON entity_skills(skill_id);

CREATE TABLE experience_log (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id        INTEGER NOT NULL,
    skill_id         INTEGER NOT NULL,
    job_id           INTEGER,
    used_version_id  INTEGER,
    started_at       TEXT NOT NULL,
    finished_at      TEXT,
    success          INTEGER,
    cost_ms          INTEGER,
    meta_json        TEXT
);

CREATE INDEX idx_experience_entity ON experience_log(entity_id);
CREATE INDEX idx_experience_skill  ON experience_log(skill_id);
CREATE INDEX idx_experience_time   ON experience_log(started_at);
SQL
else
  echo "✅ تخطي skills.db – يحتوي بالفعل على جداول ($TABLES_SKILLS)."
fi

############################
# 3) knowledge_main.db – المستندات والمعرفة الأساسية
############################
TABLES_KMAIN="$(has_tables "$KNOW_MAIN_DB")"
if [[ "$TABLES_KMAIN" -eq 0 ]]; then
  echo "🧱 إنشاء سكيمة knowledge_main.db في: $KNOW_MAIN_DB"
  mkdir -p "$(dirname "$KNOW_MAIN_DB")"
  sqlite3 "$KNOW_MAIN_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE documents (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    external_id   TEXT,
    source_type   TEXT NOT NULL,   -- telegram / file / web / log / image_ocr / ...
    source_ref    TEXT,
    title         TEXT,
    lang          TEXT,
    created_at    TEXT NOT NULL,
    indexed_at    TEXT,
    meta_json     TEXT
);

CREATE TABLE chunks (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id   INTEGER NOT NULL,
    seq           INTEGER NOT NULL,
    content       TEXT NOT NULL,
    token_count   INTEGER,
    meta_json     TEXT,
    created_at    TEXT NOT NULL,
    FOREIGN KEY(document_id) REFERENCES documents(id)
);

CREATE INDEX idx_chunks_doc ON chunks(document_id);

CREATE TABLE tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,
    name        TEXT,
    description TEXT
);

CREATE TABLE document_tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    tag_id      INTEGER NOT NULL,
    FOREIGN KEY(document_id) REFERENCES documents(id),
    FOREIGN KEY(tag_id)      REFERENCES tags(id)
);

CREATE TABLE sources (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,
    name        TEXT,
    meta_json   TEXT
);

CREATE TABLE knowledge_links (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    from_chunk_id   INTEGER NOT NULL,
    to_chunk_id     INTEGER NOT NULL,
    link_type       TEXT NOT NULL,
    weight          REAL,
    meta_json       TEXT,
    FOREIGN KEY(from_chunk_id) REFERENCES chunks(id),
    FOREIGN KEY(to_chunk_id)   REFERENCES chunks(id)
);
SQL
else
  echo "✅ تخطي knowledge_main.db – يحتوي بالفعل على جداول ($TABLES_KMAIN)."
fi

############################
# 4) knowledge_fts.db – فهرس全文 منفصل
############################
TABLES_KFTS="$(has_tables "$KNOW_FTS_DB")"
if [[ "$TABLES_KFTS" -eq 0 ]]; then
  echo "🧱 إنشاء سكيمة knowledge_fts.db في: $KNOW_FTS_DB"
  mkdir -p "$(dirname "$KNOW_FTS_DB")"
  sqlite3 "$KNOW_FTS_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE VIRTUAL TABLE chunks_fts USING fts5(
    content,
    tokenize = 'unicode61'
);
SQL
else
  echo "✅ تخطي knowledge_fts.db – يحتوي بالفعل على جداول ($TABLES_KFTS)."
fi

############################
# 5) knowledge_embeddings.db – المتجهات
############################
TABLES_KEMB="$(has_tables "$KNOW_EMB_DB")"
if [[ "$TABLES_KEMB" -eq 0 ]]; then
  echo "🧱 إنشاء سكيمة knowledge_embeddings.db في: $KNOW_EMB_DB"
  mkdir -p "$(dirname "$KNOW_EMB_DB")"
  sqlite3 "$KNOW_EMB_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE chunk_embeddings (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    chunk_id    INTEGER NOT NULL,
    model       TEXT NOT NULL,
    dim         INTEGER NOT NULL,
    vector      BLOB NOT NULL,
    created_at  TEXT NOT NULL
);

CREATE INDEX idx_chunk_embeddings_chunk ON chunk_embeddings(chunk_id);
SQL
else
  echo "✅ تخطي knowledge_embeddings.db – يحتوي بالفعل على جداول ($TABLES_KEMB)."
fi

echo "✅ انتهت تهيئة طبقة العقل + المعرفة (v2) بدون لمس identity.db أو memory_core."
