#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ROOT="/opt/hyper-factory/var/db"
YEAR="2025"

echo "🧱 إنشاء هيكل قواعد بيانات runtime في: $RUNTIME_ROOT"

mkdir -p "$RUNTIME_ROOT"/{meta,identity,memory,tasks,skills,knowledge}

IDENTITY_DB="$RUNTIME_ROOT/identity/identity.db"
MEMORY_DB="$RUNTIME_ROOT/memory/memory_core_${YEAR}.db"

echo "🧱 identity.db  => $IDENTITY_DB"
echo "🧱 memory_core  => $MEMORY_DB"

# -------- identity.db --------
# لو الملف موجود مسبقًا (من HyperFFactory الأصلي) ما نلمسوش
if [[ -f "$IDENTITY_DB" ]]; then
  echo "ℹ️ identity.db موجود مسبقًا – لن يتم تعديل سكيمته."
else
  echo "ℹ️ identity.db غير موجود – إنشاء سكيمة مبسطة للكيانات فقط."
  sqlite3 "$IDENTITY_DB" <<'SQL'
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS entities (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    external_id   TEXT,
    entity_type   TEXT NOT NULL,
    name          TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'active',
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_entities_type   ON entities(entity_type);
CREATE INDEX IF NOT EXISTS idx_entities_status ON entities(status);
SQL
fi

# -------- memory_core_YYYY.db --------
# نبني سكيمة الذاكرة في ملف مستقل، بدون FOREIGN KEY على identity
sqlite3 "$MEMORY_DB" <<'SQL'
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
    meta_json        TEXT
);

CREATE TABLE IF NOT EXISTS state_snapshots (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_key     TEXT NOT NULL,
    taken_at         TEXT NOT NULL,
    source_entity_id INTEGER,
    scope_type       TEXT NOT NULL,
    scope_id         TEXT,
    summary          TEXT,
    state_json       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_snapshots_time  ON state_snapshots(taken_at);
CREATE INDEX IF NOT EXISTS idx_snapshots_scope ON state_snapshots(scope_type, scope_id);
SQL

echo "✅ تم تجهيز memory_core_${YEAR}.db (مع ترك identity.db كما هو)"
