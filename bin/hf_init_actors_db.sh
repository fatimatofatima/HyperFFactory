#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
DB_DIR="$ROOT/db/meta"
DB_PATH="$DB_DIR/hf_actors.db"

mkdir -p "$DB_DIR"

echo "📂 تهيئة قاعدة بيانات المدراء/العمال: $DB_PATH"

sqlite3 "$DB_PATH" <<'SQL'
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS hf_actors (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT,           -- اسم العامل/المدير (من التاج أو من اسم الملف)
    role_type   TEXT,           -- MANAGER / WORKER / UNKNOWN
    source_root TEXT,           -- hyperffactory / smartfriend-suite / ffactory / external
    source_path TEXT,           -- المسار الكامل للملف
    tag_marker  TEXT,           -- الرمز المستخدم في البحث (HF_MARKER)
    tag_payload TEXT,           -- النص بعد الرمز (سطر التاج كامل بعد العلامة)
    created_at  TEXT DEFAULT (datetime('now','localtime')),
    updated_at  TEXT
);

CREATE TABLE IF NOT EXISTS hf_actor_tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    actor_id    INTEGER,
    key         TEXT,
    value       TEXT,
    created_at  TEXT DEFAULT (datetime('now','localtime')),
    FOREIGN KEY(actor_id) REFERENCES hf_actors(id)
);

CREATE TABLE IF NOT EXISTS hf_actor_links (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    actor_id    INTEGER,
    link_type   TEXT,         -- TASK / QUALITY / MEMORY / AWARENESS / OTHER
    target      TEXT,         -- اسم المهمة / الخدمة / الجدول المرتبط
    meta        TEXT,         -- JSON أو نص حر لوصف الربط
    created_at  TEXT DEFAULT (datetime('now','localtime')),
    FOREIGN KEY(actor_id) REFERENCES hf_actors(id)
);
SQL

echo "✅ hf_actors.db جاهزة تحت $DB_PATH"
