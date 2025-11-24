#!/usr/bin/env bash
set -euo pipefail

# 1) تعريف مسارات الـ Data Home الجديدة
DATA_ROOT="/opt/hyper-factory/var/db"
IDENTITY_DIR="$DATA_ROOT/identity"
IDENTITY_DB="$IDENTITY_DIR/identity.db"

echo "📁 DATA_ROOT: $DATA_ROOT"
echo "📁 IDENTITY_DIR: $IDENTITY_DIR"
echo "🗄️ IDENTITY_DB: $IDENTITY_DB"

# 2) إنشاء الشجرة كاملة (بدون لمس أي مشاريع تانية)
mkdir -p "$DATA_ROOT"/{meta,identity,memory,tasks,skills,knowledge}

# 3) إنشاء/تحديث سكيما identity.db
sqlite3 "$IDENTITY_DB" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- الكيانات الأساسية في النظام (مستخدم، Agent، خدمة، سيرفر، مشروع...)
CREATE TABLE IF NOT EXISTS entities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,            -- user / agent / service / project / device ...
    name TEXT NOT NULL,                   -- اسم الكيان
    status TEXT,                          -- active / disabled / legacy / unknown
    external_ref TEXT UNIQUE,             -- مرجع (db:table:pk) من قواعد قديمة
    meta_json TEXT,                       -- مساحة مفتوحة لأي ميتا إضافي
    created_at TEXT NOT NULL,
    updated_at TEXT
);

-- تعريف الأدوار القياسية
CREATE TABLE IF NOT EXISTS roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,            -- GlobalOrchestrator / MemoryManager / KnowledgeManager / ...
    description TEXT,
    scope TEXT                            -- system / project / app / service
);

-- ربط الكيانات بالأدوار
CREATE TABLE IF NOT EXISTS role_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    scope TEXT,                           -- نفس فكرة scope في roles، لكن per assignment
    scope_ref TEXT,                       -- project_id أو service_name ... إلخ
    assigned_at TEXT NOT NULL,
    assigned_by TEXT,
    FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

-- القدرات (Capabilities) على مستوى النظام
CREATE TABLE IF NOT EXISTS capabilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,            -- مثل: "memory.read", "memory.write", "tasks.schedule", ...
    description TEXT
);

-- ربط الكيانات بالقدرات
CREATE TABLE IF NOT EXISTS entity_capabilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_id INTEGER NOT NULL,
    capability_id INTEGER NOT NULL,
    level INTEGER,                        -- 1..5 أو NULL
    granted_at TEXT NOT NULL,
    granted_by TEXT,
    UNIQUE (entity_id, capability_id),
    FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE,
    FOREIGN KEY (capability_id) REFERENCES capabilities(id) ON DELETE CASCADE
);

-- لوج لعمليات الاستيراد من قواعد قديمة
CREATE TABLE IF NOT EXISTS identity_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_db TEXT NOT NULL,
    source_table TEXT NOT NULL,
    imported_count INTEGER NOT NULL,
    run_at TEXT NOT NULL
);

-- جدول مساعد لتسجيل مصادر الهوية القديمة
CREATE TABLE IF NOT EXISTS identity_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_db TEXT NOT NULL,
    source_role TEXT,
    size_mb REAL,
    notes TEXT,
    created_at TEXT NOT NULL
);

SQL

echo "✅ تم تجهيز identity.db في: $IDENTITY_DB"

# 4) عرض جداول الـ identity للتأكيد
sqlite3 "$IDENTITY_DB" '.tables'

