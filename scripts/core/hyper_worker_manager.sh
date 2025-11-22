#!/bin/bash
echo "👷 HyperFactory Worker Manager - تسجيل العمال الأساسيين"

# المسارات
DB_DIR="/root/HyperFFactory/db"
IDENTITY_DB="$DB_DIR/identity/identity.db"
TASKS_DB="$DB_DIR/tasks/tasks.db"

# إنشاء جدول العمال إذا لم يكن موجوداً
sqlite3 "$IDENTITY_DB" "
CREATE TABLE IF NOT EXISTS entities (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT,
    capabilities TEXT,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);"

# تسجيل العمال الأساسيين
sqlite3 "$IDENTITY_DB" "
INSERT OR IGNORE INTO entities (id, name, type, capabilities) VALUES 
('hyper_brain_1', 'Hyper Brain Controller', 'worker', 'management,coordination,decision_making'),
('hyper_ai_1', 'AI Learning Agent', 'worker', 'learning,training,ai_models'),
('hyper_maintenance_1', 'Maintenance Supervisor', 'worker', 'repair,cleanup,health_check'),
('hyper_memory_1', 'Memory Manager', 'worker', 'memory,storage,knowledge'),
('hyper_integration_1', 'Integration Coordinator', 'worker', 'integration,api,communication');
"

# تأكيد التسجيل
worker_count=$(sqlite3 "$IDENTITY_DB" "SELECT COUNT(*) FROM entities WHERE type='worker';")
echo "✅ تم تسجيل $worker_count عامل في نظام الهوية"
