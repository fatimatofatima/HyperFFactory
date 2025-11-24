#!/usr/bin/env python3
# HyperFFactory – Sync HF_EXEC_PLAN.tsv → hf_ops_meta.tasks
# بدون ON CONFLICT – استخدام SELECT ثم UPDATE/INSERT يدوي

import csv
import sqlite3
from datetime import datetime
from pathlib import Path

ROOT = Path("/root/HyperFFactory").resolve()
PLAN_PATH = ROOT / "plans" / "HF_EXEC_PLAN.tsv"
DB_PATH = ROOT / "db" / "meta" / "hf_ops_meta.db"
REPORTS_DIR = ROOT / "reports"

REPORTS_DIR.mkdir(parents=True, exist_ok=True)
TS = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_PATH = REPORTS_DIR / f"hf_sync_plan_to_tasks_{TS}.log"

def log(line: str) -> None:
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    msg = f"[{ts}] {line}"
    print(msg)
    with LOG_PATH.open("a", encoding="utf-8") as f:
        f.write(msg + "\n")

def main() -> None:
    log("=====================================================")
    log("HyperFFactory – Sync HF_EXEC_PLAN.tsv → hf_ops_meta.tasks")
    log(f"ROOT : {ROOT}")
    log(f"PLAN : {PLAN_PATH}")
    log(f"DB   : {DB_PATH}")
    log("=====================================================")

    if not PLAN_PATH.exists():
        log(f"[ERROR] لم يتم العثور على ملف الخطة: {PLAN_PATH}")
        log("=====================================================")
        return

    # فتح قاعدة البيانات
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    # التأكد من وجود جدول tasks (نفس الأعمدة التي جهزناها بالسكربت bash)
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';")
    row = cur.fetchone()
    if row is None:
        log("[WARN] جدول tasks غير موجود – سيتم إنشاؤه الآن بشكل كامل.")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                actor      TEXT,
                scope      TEXT,
                status     TEXT,
                priority   INTEGER,
                created_at TEXT,
                updated_at TEXT,
                code       TEXT,
                title      TEXT,
                stage      TEXT,
                category   TEXT,
                task       TEXT,
                owner      TEXT,
                last_note  TEXT,
                plan_ref   TEXT
            );
        """)
        conn.commit()
    else:
        log("[INFO] جدول tasks موجود – سيتم استخدامه كما هو (مع الأعمدة التي أضفناها بالسكربت).")

    # قراءة HF_EXEC_PLAN.tsv
    log("[INFO] فتح HF_EXEC_PLAN.tsv وقراءة العناوين...")
    with PLAN_PATH.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        fieldnames = reader.fieldnames or []
        log(f"[INFO] الأعمدة الموجودة في الخطة: {fieldnames}")

        synced = 0
        inserted = 0
        updated = 0

        for row in reader:
            # تنظيف القيم الأساسية
            raw_id       = (row.get("ID") or "").strip()
            stage        = (row.get("STAGE") or "").strip()
            category     = (row.get("CATEGORY") or "").strip()
            code         = (row.get("CODE") or "").strip()
            title        = (row.get("TITLE") or "").strip()
            task_txt     = (row.get("TASK") or "").strip()
            status       = (row.get("STATUS") or "").strip()
            owner        = (row.get("OWNER") or "").strip()
            last_note    = (row.get("LAST_NOTE") or "").strip()

            # plan_ref: مرجع الخطة – نستخدم CODE إن وجد، وإلا ID، وإلا نتخطى السطر
            if code:
                plan_ref = f"PLAN:{code}"
            elif raw_id:
                plan_ref = f"PLAN-ID:{raw_id}"
            else:
                # لا يوجد identifier واضح – نتخطى السطر لكن نسجله في اللوج
                log(f"[WARN] تخطي صف بدون CODE/ID صالح: {row}")
                continue

            actor = "HF_EXECUTOR"
            scope = category or "GENERAL"
            priority = 1

            now = datetime.now().isoformat(timespec="seconds")

            # فحص إن كان هناك سجل موجود بنفس plan_ref
            cur.execute("SELECT id FROM tasks WHERE plan_ref = ?", (plan_ref,))
            existing = cur.fetchone()

            if existing:
                # UPDATE للسجل الحالي
                cur.execute(
                    """
                    UPDATE tasks
                    SET actor      = ?,
                        scope      = ?,
                        stage      = ?,
                        category   = ?,
                        code       = ?,
                        title      = ?,
                        task       = ?,
                        status     = ?,
                        owner      = ?,
                        priority   = ?,
                        last_note  = ?,
                        updated_at = ?
                    WHERE plan_ref = ?
                    """,
                    (
                        actor,
                        scope,
                        stage,
                        category,
                        code,
                        title,
                        task_txt,
                        status,
                        owner,
                        priority,
                        last_note,
                        now,
                        plan_ref,
                    ),
                )
                updated += 1
            else:
                # INSERT سجل جديد
                cur.execute(
                    """
                    INSERT INTO tasks (
                        actor, scope, stage, category, code, title,
                        task, status, owner, priority,
                        last_note, plan_ref,
                        created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        actor,
                        scope,
                        stage,
                        category,
                        code,
                        title,
                        task_txt,
                        status,
                        owner,
                        priority,
                        last_note,
                        plan_ref,
                        now,
                        now,
                    ),
                )
                inserted += 1

            synced += 1

    conn.commit()
    conn.close()

    log(f"[INFO] عدد الصفوف المزامَنة من الخطة: {synced}")
    log(f"[INFO] عدد السجلات الجديدة (INSERT): {inserted}")
    log(f"[INFO] عدد السجلات المحدّثة (UPDATE): {updated}")
    log("[DONE] Sync finished.")
    log("=====================================================")

if __name__ == "__main__":
    main()
