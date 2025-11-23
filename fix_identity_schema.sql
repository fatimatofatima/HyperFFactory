-- إضافة الأعمدة المفقودة فقط (بدون التكرار)
ALTER TABLE entities ADD COLUMN external_id TEXT;
ALTER TABLE entities ADD COLUMN external_source TEXT;

-- تحديث جدول identity_migrations الموجود
CREATE TABLE IF NOT EXISTS identity_migrations_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    migration_name TEXT UNIQUE NOT NULL,
    applied_at TEXT DEFAULT (datetime('now'))
);

-- نسخ البيانات من الجدول القديم إن وجدت
INSERT OR IGNORE INTO identity_migrations_new (migration_name, applied_at)
SELECT 'migration_fix_v1', datetime('now')
WHERE NOT EXISTS (SELECT 1 FROM identity_migrations_new WHERE migration_name = 'migration_fix_v1');

-- إضافة فهرس للأعمدة الجديدة
CREATE INDEX IF NOT EXISTS idx_entities_external ON entities(external_id, external_source);
