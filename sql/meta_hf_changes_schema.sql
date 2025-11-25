-- HyperFFactory – تعريف قاعدة hf_changes.db
-- هدفها: دفتر تغييرات مركزي لتتبع كل العمليات المهمة.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS hf_changes (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    ts           TEXT    NOT NULL,      -- طابع زمني ISO8601
    actor        TEXT    NOT NULL,      -- من نفّذ (سكربت / خدمة / عامل)
    change_type  TEXT    NOT NULL,      -- نوع التغيير (INIT, MIGRATE, FIX, SYNC, CHECK, IMPORT, BOOTSTRAP, INTEGRATION, ...)
    target       TEXT,                  -- العنصر المستهدف (DB, FILE, SERVICE, PLAN, STACK, ...)
    details      TEXT,                  -- وصف نصي مختصر لما حدث
    meta         TEXT                   -- JSON (اختياري) لمعلومات إضافية
);

CREATE INDEX IF NOT EXISTS idx_hf_changes_ts
    ON hf_changes(ts);

CREATE INDEX IF NOT EXISTS idx_hf_changes_actor
    ON hf_changes(actor);

CREATE INDEX IF NOT EXISTS idx_hf_changes_type
    ON hf_changes(change_type);

CREATE INDEX IF NOT EXISTS idx_hf_changes_target
    ON hf_changes(target);
