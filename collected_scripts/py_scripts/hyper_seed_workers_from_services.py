#!/usr/bin/env python3
import sqlite3
import os
import socket
from datetime import datetime
from typing import Dict, Any, List, Tuple

RUNTIME_ROOT = "/opt/hyper-factory/var/db"
IDENTITY_DB = os.path.join(RUNTIME_ROOT, "identity", "identity.db")
TASKS_DB    = os.path.join(RUNTIME_ROOT, "tasks", "tasks.db")

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"
HOSTNAME = socket.gethostname()

# تعريف الأدوار التي سنستخدمها للعمال
ROLE_DEFS = [
    ("TaskWorker",      "Task Worker",      "عامل تشغيل المهام العامة"),
    ("KnowledgeWorker", "Knowledge Worker", "عامل تشغيل مهام المعرفة (بدون لمس DB مباشرة)"),
    ("SpiderWorker",    "Spider Worker",    "عامل تشغيل الزاحف/جمع البيانات"),
    ("OCRWorker",       "OCR Worker",       "عامل تشغيل مهام OCR"),
]

# تعريف العمال المراد Seed لهم
WORKERS = [
    {
        "worker_code": "worker_tasks_local_1",
        "entity_type": "worker",
        "name": "Local Task Worker 1",
        "role_codes": ["TaskWorker"],
        "max_concurrent_jobs": 2,
    },
    {
        "worker_code": "worker_knowledge_local_1",
        "entity_type": "worker",
        "name": "Local Knowledge Worker 1",
        "role_codes": ["KnowledgeWorker"],
        "max_concurrent_jobs": 1,
    },
    {
        "worker_code": "worker_spider_local_1",
        "entity_type": "worker",
        "name": "Local Spider Worker 1",
        "role_codes": ["SpiderWorker"],
        "max_concurrent_jobs": 1,
    },
]

def open_db(path: str) -> sqlite3.Connection:
    if not os.path.exists(path):
        raise RuntimeError(f"DB not found: {path}")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn

def ensure_roles(conn: sqlite3.Connection) -> Dict[str, int]:
    cur = conn.cursor()
    role_ids: Dict[str, int] = {}

    cur.execute("SELECT id, code FROM roles")
    for row in cur.fetchall():
        role_ids[row["code"]] = row["id"]

    for code, name, desc in ROLE_DEFS:
        if code in role_ids:
            continue
        cur.execute(
            "INSERT INTO roles (code, name, description, created_at) VALUES (?,?,?,?)",
            (code, name, desc, NOW),
        )
        role_ids[code] = cur.lastrowid

    conn.commit()
    return role_ids

def ensure_entity(conn: sqlite3.Connection, entity_type: str, name: str) -> int:
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM entities WHERE entity_type=? AND name=?",
        (entity_type, name),
    )
    row = cur.fetchone()
    if row:
        return row["id"]

    cur.execute(
        """
        INSERT INTO entities (entity_type, name, status, external_ref, meta_json, created_at, updated_at)
        VALUES (?, ?, 'active', NULL, NULL, ?, ?)
        """,
        (entity_type, name, NOW, NOW),
    )
    entity_id = cur.lastrowid
    conn.commit()
    return entity_id

def ensure_role_assignments(conn: sqlite3.Connection, entity_id: int, role_ids: List[int]) -> None:
    cur = conn.cursor()
    cur.execute(
        "SELECT role_id FROM role_assignments WHERE entity_id=? AND scope_type='system'",
        (entity_id,),
    )
    existing = {r["role_id"] for r in cur.fetchall()}

    for rid in role_ids:
        if rid in existing:
            continue
        cur.execute(
            """
            INSERT INTO role_assignments (entity_id, role_id, scope_type, scope_id, assigned_at, revoked_at)
            VALUES (?, ?, 'system', NULL, ?, NULL)
            """,
            (entity_id, rid, NOW),
        )

    conn.commit()

def ensure_worker(tasks_conn: sqlite3.Connection,
                  entity_id: int,
                  worker_code: str,
                  max_concurrent_jobs: int) -> int:
    cur = tasks_conn.cursor()
    cur.execute(
        "SELECT id FROM workers WHERE worker_code=?",
        (worker_code,),
    )
    row = cur.fetchone()
    if row:
        worker_id = row["id"]
        # تحديث host و max_concurrent_jobs
        cur.execute(
            """
            UPDATE workers
               SET entity_id=?,
                   host=?,
                   max_concurrent_jobs=?,
                   last_heartbeat=?
             WHERE id=?
            """,
            (entity_id, HOSTNAME, max_concurrent_jobs, NOW, worker_id),
        )
        tasks_conn.commit()
        return worker_id

    cur.execute(
        """
        INSERT INTO workers
        (entity_id, worker_code, host, pid, status,
         max_concurrent_jobs, current_jobs, started_at, last_heartbeat, meta_json)
        VALUES (?, ?, ?, NULL, 'idle', ?, 0, ?, ?, NULL)
        """,
        (entity_id, worker_code, HOSTNAME, max_concurrent_jobs, NOW, NOW),
    )
    worker_id = cur.lastrowid
    tasks_conn.commit()
    return worker_id

def main() -> None:
    print(f"🧠 Seed workers from services/config")
    print(f"  IDENTITY_DB = {IDENTITY_DB}")
    print(f"  TASKS_DB    = {TASKS_DB}")

    id_conn = open_db(IDENTITY_DB)
    tasks_conn = open_db(TASKS_DB)

    # تأكد من وجود جداول الهوية الأساسية
    required_tables = ["entities", "roles", "role_assignments"]
    cur = id_conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    existing_tables = {r["name"] for r in cur.fetchall()}
    for t in required_tables:
        if t not in existing_tables:
            raise RuntimeError(f"Required table '{t}' not found in identity.db")

    # تأكد من وجود جدول العمال
    cur_t = tasks_conn.cursor()
    cur_t.execute("SELECT name FROM sqlite_master WHERE type='table'")
    task_tables = {r["name"] for r in cur_t.fetchall()}
    if "workers" not in task_tables:
        raise RuntimeError("Table 'workers' not found in tasks.db. Run hyper_init_workers_tables.sh first.")

    print("🔎 تأكيد الأدوار الأساسية...")
    role_ids = ensure_roles(id_conn)
    print(f"   roles: {role_ids}")

    created_workers: List[Tuple[str, int, int]] = []

    for w in WORKERS:
        print(f"➡️  معالجة العامل: {w['worker_code']}")
        entity_id = ensure_entity(id_conn, w["entity_type"], w["name"])
        rids = [role_ids[rc] for rc in w["role_codes"] if rc in role_ids]
        ensure_role_assignments(id_conn, entity_id, rids)
        worker_id = ensure_worker(
            tasks_conn,
            entity_id=entity_id,
            worker_code=w["worker_code"],
            max_concurrent_jobs=w["max_concurrent_jobs"],
        )
        created_workers.append((w["worker_code"], entity_id, worker_id))

    print("\n✅ نتيجة الـ Seed:")
    for code, eid, wid in created_workers:
        print(f"  - {code}: entity_id={eid}, worker_id={wid}")

    id_conn.close()
    tasks_conn.close()

if __name__ == "__main__":
    main()
