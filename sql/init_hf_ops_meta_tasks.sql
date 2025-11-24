-- HyperFFactory – hf_ops_meta.tasks schema
-- هذا الملف لا يُنفّذ تلقائيًا، بل يُستخدم من سكربتات الإدارة أو يدويًا.
-- يعتمد على SQLite.

CREATE TABLE IF NOT EXISTS tasks (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    code       TEXT UNIQUE,   -- كود البند (مثل HF-003, P2-1)
    stage      TEXT,          -- Stage1 / Stage2 / P2 / إلخ
    title      TEXT,          -- العنوان البشري للبند
    status     TEXT,          -- PLANNED / RUNNING / DONE / ONHOLD
    actor      TEXT,          -- المسؤول الرئيسي (system / human / worker)
    scope      TEXT,          -- HyperFFactory / SmartFriend / Bridge / إلخ
    plan_ref   TEXT,          -- مرجع إضافي من HF_EXEC_PLAN.tsv إن لزم
    created_at TEXT,          -- ISO timestamp
    updated_at TEXT           -- ISO timestamp
);
