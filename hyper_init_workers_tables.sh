#!/usr/bin/env bash
set -euo pipefail

TASK_DB="/opt/hyper-factory/var/db/tasks/tasks.db"

echo "🧱 تهيئة جداول العمال داخل tasks.db"
echo "   TASK_DB = $TASK_DB"

if [[ ! -f "$TASK_DB" ]]; then
  echo "❌ tasks.db غير موجود. تأكد من تشغيل hyper_init_brain_and_knowledge.sh أو v2 أولاً."
  exit 1
fi

echo "== .tables قبل التعديل =="
sqlite3 "$TASK_DB" ".tables" || true
echo

sqlite3 "$TASK_DB" <<'SQL'
PRAGMA journal_mode=WAL;

-- جدول تعريف العمال (workers)
CREATE TABLE IF NOT EXISTS workers (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id             INTEGER NOT NULL,          -- id من identity.entities (مرجع منطقي فقط)
    worker_code           TEXT NOT NULL UNIQUE,      -- اسم منطقي: worker_tasks_local_1
    host                  TEXT,                      -- hostname أو IP
    pid                   INTEGER,                   -- PID إن لزم
    status                TEXT NOT NULL DEFAULT 'idle',  -- idle / busy / offline / disabled
    max_concurrent_jobs   INTEGER NOT NULL DEFAULT 1,
    current_jobs          INTEGER NOT NULL DEFAULT 0,
    started_at            TEXT,
    last_heartbeat        TEXT,
    meta_json             TEXT
    -- مفيش FOREIGN KEY هنا لأن identity.entities في DB منفصلة
);

-- جدول نبضات حياة العمال (worker_heartbeats)
CREATE TABLE IF NOT EXISTS worker_heartbeats (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    worker_id      INTEGER NOT NULL,    -- رابط إلى workers.id
    heartbeat_at   TEXT NOT NULL,       -- ISO8601
    status         TEXT NOT NULL,       -- idle / busy / degraded / error
    load_factor    REAL,                -- 0.0 .. 1.0
    meta_json      TEXT,
    FOREIGN KEY(worker_id) REFERENCES workers(id)
);

CREATE INDEX IF NOT EXISTS idx_worker_heartbeats_worker
    ON worker_heartbeats(worker_id);

CREATE INDEX IF NOT EXISTS idx_worker_heartbeats_time
    ON worker_heartbeats(heartbeat_at);
SQL

echo
echo "✅ تم تجهيز جداول العمال في tasks.db"

echo
echo "== .tables بعد التعديل =="
sqlite3 "$TASK_DB" ".tables"

echo
echo "== مخطط workers =="
sqlite3 "$TASK_DB" ".schema workers"

echo
echo "== مخطط worker_heartbeats =="
sqlite3 "$TASK_DB" ".schema worker_heartbeats"
