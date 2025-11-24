#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="/opt/hyper-factory/var/db"
YEAR="2025"

echo "🧱 تهيئة طبقة العقل + المعرفة في: $RUNTIME_ROOT"

mkdir -p "$RUNTIME_ROOT"/{meta,identity,memory,tasks,skills,knowledge}

IDENTITY_DB="$RUNTIME_ROOT/identity/identity.db"
MEMORY_DB="$RUNTIME_ROOT/memory/memory_core_${YEAR}.db"
TASK_DB="$RUNTIME_ROOT/tasks/tasks.db"
SKILLS_DB="$RUNTIME_ROOT/skills/skills.db"
KNOW_MAIN_DB="$RUNTIME_ROOT/knowledge/knowledge_main.db"
KNOW_FTS_DB="$RUNTIME_ROOT/knowledge/knowledge_fts.db"
KNOW_EMB_DB="$RUNTIME_ROOT/knowledge/knowledge_embeddings.db"

echo "🧱 identity.db         => $IDENTITY_DB"
echo "🧱 memory_core_${YEAR} => $MEMORY_DB"
echo "🧱 tasks.db            => $TASK_DB"
echo "🧱 skills.db           => $SKILLS_DB"
echo "🧱 knowledge_main.db   => $KNOW_MAIN_DB"
echo "🧱 knowledge_fts.db    => $KNOW_FTS_DB"
echo "🧱 knowledge_embeddings.db => $KNOW_EMB_DB"

########################################
# 1) identity.db  (الهوية + الأدوار + القدرات)
########################################

sqlite3 "$IDENTITY_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS entities (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    external_id TEXT,
    entity_type TEXT NOT NULL,        -- user / agent / service / project / device / system
    name        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active',
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_entities_type   ON entities(entity_type);
CREATE INDEX IF NOT EXISTS idx_entities_status ON entities(status);

CREATE TABLE IF NOT EXISTS roles (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,   -- GlobalOrchestrator / ProjectManager / ...
    name        TEXT NOT NULL,
    description TEXT,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS role_assignments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id   INTEGER NOT NULL,
    role_id     INTEGER NOT NULL,
    scope_type  TEXT NOT NULL,          -- system / project / app
    scope_id    TEXT,
    assigned_at TEXT NOT NULL,
    revoked_at  TEXT,
    FOREIGN KEY(entity_id) REFERENCES entities(id),
    FOREIGN KEY(role_id)   REFERENCES roles(id)
);

CREATE INDEX IF NOT EXISTS idx_role_assign_entity ON role_assignments(entity_id);
CREATE INDEX IF NOT EXISTS idx_role_assign_role   ON role_assignments(role_id);

CREATE TABLE IF NOT EXISTS capabilities_profile (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id       INTEGER NOT NULL,
    capability_code TEXT NOT NULL,      -- read_knowledge / manage_tasks / ...
    level           INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    FOREIGN KEY(entity_id) REFERENCES entities(id)
);

CREATE INDEX IF NOT EXISTS idx_capabilities_entity ON capabilities_profile(entity_id);
CREATE INDEX IF NOT EXISTS idx_capabilities_code   ON capabilities_profile(capability_code);
SQL

echo "✅ identity.db جاهزة (مع الحفاظ على أي جداول موجودة سابقًا)"

########################################
# 2) memory_core_YYYY.db  (الذاكرة الزمنية)
########################################

sqlite3 "$MEMORY_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS events (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp        TEXT NOT NULL,
    source_entity_id INTEGER,
    event_type       TEXT NOT NULL,
    severity         TEXT,
    payload_json     TEXT NOT NULL,
    correlation_id   TEXT,
    created_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_events_time   ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_type   ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_entity ON events(source_entity_id);

CREATE TABLE IF NOT EXISTS sessions (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    session_key      TEXT NOT NULL UNIQUE,
    owner_entity_id  INTEGER,
    started_at       TEXT NOT NULL,
    ended_at         TEXT,
    status           TEXT NOT NULL DEFAULT 'open',
    meta_json        TEXT,
    FOREIGN KEY(owner_entity_id) REFERENCES entities(id)
);

CREATE TABLE IF NOT EXISTS state_snapshots (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_key     TEXT NOT NULL,
    taken_at         TEXT NOT NULL,
    source_entity_id INTEGER,
    scope_type       TEXT NOT NULL,
    scope_id         TEXT,
    summary          TEXT,
    state_json       TEXT NOT NULL,
    FOREIGN KEY(source_entity_id) REFERENCES entities(id)
);

CREATE INDEX IF NOT EXISTS idx_snapshots_time  ON state_snapshots(taken_at);
CREATE INDEX IF NOT EXISTS idx_snapshots_scope ON state_snapshots(scope_type, scope_id);
SQL

echo "✅ memory_core_${YEAR}.db جاهزة"

########################################
# 3) tasks.db  (مدير العمليات / الـ Workflow)
########################################

sqlite3 "$TASK_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS job_types (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    code             TEXT NOT NULL UNIQUE,   -- ScanBackups / BuildServiceMatrix / ...
    name             TEXT NOT NULL,
    description      TEXT,
    default_priority INTEGER NOT NULL DEFAULT 5,
    created_at       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    job_type_id    INTEGER NOT NULL,
    name           TEXT NOT NULL,
    status         TEXT NOT NULL,       -- pending / running / done / failed / cancelled
    priority       INTEGER NOT NULL,
    created_at     TEXT NOT NULL,
    started_at     TEXT,
    finished_at    TEXT,
    requested_by   INTEGER,            -- entity_id
    payload_json   TEXT,
    result_json    TEXT,
    FOREIGN KEY(job_type_id)  REFERENCES job_types(id),
    FOREIGN KEY(requested_by) REFERENCES entities(id)
);

CREATE INDEX IF NOT EXISTS idx_jobs_status   ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_type     ON jobs(job_type_id);
CREATE INDEX IF NOT EXISTS idx_jobs_created  ON jobs(created_at);

CREATE TABLE IF NOT EXISTS job_dependencies (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id      INTEGER NOT NULL,
    depends_on  INTEGER NOT NULL,
    FOREIGN KEY(job_id)     REFERENCES jobs(id),
    FOREIGN KEY(depends_on) REFERENCES jobs(id)
);

CREATE INDEX IF NOT EXISTS idx_job_dep_job ON job_dependencies(job_id);

CREATE TABLE IF NOT EXISTS job_assignments (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id         INTEGER NOT NULL,
    assignee_id    INTEGER NOT NULL,    -- entity_id
    assigned_at    TEXT NOT NULL,
    started_at     TEXT,
    finished_at    TEXT,
    status         TEXT NOT NULL DEFAULT 'assigned',
    notes          TEXT,
    FOREIGN KEY(job_id)      REFERENCES jobs(id),
    FOREIGN KEY(assignee_id) REFERENCES entities(id)
);

CREATE INDEX IF NOT EXISTS idx_job_assign_job   ON job_assignments(job_id);
CREATE INDEX IF NOT EXISTS idx_job_assign_agent ON job_assignments(assignee_id);

CREATE TABLE IF NOT EXISTS schedules (
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

echo "✅ tasks.db جاهزة"

########################################
# 4) skills.db  (المهارات والخبرات)
########################################

sqlite3 "$SKILLS_DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS skills (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,   -- OCR.ImageResultClassifier / Knowledge.FTS.Search / ...
    name        TEXT NOT NULL,
    category    TEXT,
    description TEXT,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS skill_versions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    skill_id    INTEGER NOT NULL,
    version     TEXT NOT NULL,
    meta_json   TEXT,
    created_at  TEXT NOT NULL,
    UNIQUE(skill_id, version),
    FOREIGN KEY(skill_id) REFERENCES skills(id)
);

CREATE TABLE IF NOT EXISTS entity_skills (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id         INTEGER NOT NULL,
    skill_id          INTEGER NOT NULL,
    current_version_id INTEGER,
    level             INTEGER NOT NULL DEFAULT 1,
    confidence        REAL,
    enabled           INTEGER NOT NULL DEFAULT 1,
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL,
    FOREIGN KEY(entity_id)         REFERENCES entities(id),
    FOREIGN KEY(skill_id)          REFERENCES skills(id),
    FOREIGN KEY(current_version_id) REFERENCES skill_versions(id)
);

CREATE INDEX IF NOT EXISTS idx_entity_skills_entity ON entity_skills(entity_id);
CREATE INDEX IF NOT EXISTS idx_entity_skills_skill  ON entity_skills(skill_id);

CREATE TABLE IF NOT EXISTS experience_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id       INTEGER NOT NULL,
    skill_id        INTEGER NOT NULL,
    job_id          INTEGER,
    used_version_id INTEGER,
    started_at      TEXT NOT NULL,
    finished_at     TEXT,
    success         INTEGER,
    cost_ms         INTEGER,
    meta_json       TEXT,
    FOREIGN KEY(entity_id)       REFERENCES entities(id),
    FOREIGN KEY(skill_id)        REFERENCES skills(id),
    FOREIGN KEY(used_version_id) REFERENCES skill_versions(id)
);

CREATE INDEX IF NOT EXISTS idx_experience_entity ON experience_log(entity_id);
CREATE INDEX IF NOT EXISTS idx_experience_skill  ON experience_log(skill_id);
CREATE INDEX IF NOT EXISTS idx_experience_time   ON experience_log(started_at);
SQL

echo "✅ skills.db جاهزة"

########################################
# 5) knowledge_main.db  (محتوى المعرفة فقط)
########################################

sqlite3 "$KNOW_MAIN_DB" <<'SQL'
PRAGMA journal_mode=WAL;

-- المستندات
CREATE TABLE IF NOT EXISTS documents (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    external_id   TEXT,
    source_type   TEXT NOT NULL,   -- telegram / file / web / image_ocr / ...
    source_ref    TEXT,
    title         TEXT,
    lang          TEXT,
    created_at    TEXT NOT NULL,
    indexed_at    TEXT,
    meta_json     TEXT
);

-- أجزاء المحتوى
CREATE TABLE IF NOT EXISTS chunks (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id   INTEGER NOT NULL,
    seq           INTEGER NOT NULL,
    content       TEXT NOT NULL,
    token_count   INTEGER,
    meta_json     TEXT,
    created_at    TEXT NOT NULL,
    FOREIGN KEY(document_id) REFERENCES documents(id)
);

CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(document_id);

-- الوسوم
CREATE TABLE IF NOT EXISTS tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,
    name        TEXT,
    description TEXT
);

CREATE TABLE IF NOT EXISTS document_tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL,
    tag_id      INTEGER NOT NULL,
    FOREIGN KEY(document_id) REFERENCES documents(id),
    FOREIGN KEY(tag_id)      REFERENCES tags(id)
);

-- مصادر عامة
CREATE TABLE IF NOT EXISTS sources (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    code        TEXT NOT NULL UNIQUE,
    name        TEXT,
    meta_json   TEXT
);

-- الروابط بين الأجزاء (Graph)
CREATE TABLE IF NOT EXISTS knowledge_links (
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

echo "✅ knowledge_main.db جاهزة (كمستودع محتوى فقط؛ منفصل عن هوية/مهام/مهارات)"

########################################
# 6) knowledge_fts.db  (بحث نصي)
########################################

if [ ! -f "$KNOW_FTS_DB" ]; then
  sqlite3 "$KNOW_FTS_DB" <<'SQL'
PRAGMA journal_mode=WAL;
CREATE VIRTUAL TABLE chunks_fts USING fts5(
    content,
    tokenize='unicode61'
);
SQL
  echo "✅ knowledge_fts.db تم إنشاؤه لأول مرة"
else
  echo "ℹ️ knowledge_fts.db موجود مسبقًا – لم يتم تغييره"
fi

########################################
# 7) knowledge_embeddings.db  (Embeddings)
########################################

if [ ! -f "$KNOW_EMB_DB" ]; then
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
  echo "✅ knowledge_embeddings.db تم إنشاؤه لأول مرة"
else
  echo "ℹ️ knowledge_embeddings.db موجود مسبقًا – لم يتم تغييره"
fi

echo "=================================================="
echo "✅ انتهت تهيئة طبقة العقل + المعرفة (بدون حذف أي قواعد قديمة)"
echo "=================================================="
