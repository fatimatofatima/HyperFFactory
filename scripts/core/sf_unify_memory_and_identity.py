#!/usr/bin/env python3
import os
import shutil
import sqlite3
from datetime import datetime

BASE_DIR = "/opt/smartfriend-suite/var/db"
ACTIVE_DB = os.path.join(BASE_DIR, "active_memory.db")

SOURCE_MEMORY_DBS = [
    os.path.join(BASE_DIR, "memory.db"),
    os.path.join(BASE_DIR, "smart_core_memory.db"),
    os.path.join(BASE_DIR, "unified_memory.db"),
]

def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")

def backup_if_exists(path: str) -> None:
    if os.path.exists(path):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup = f"{path}.bak_{ts}"
        shutil.copy2(path, backup)
        log(f"Backup created: {backup}")

def ensure_active_db() -> None:
    """
    إنشاء/تهيئة active_memory.db:
    - لو موجود: نأخذ نسخة احتياطية ونستخدمه كما هو.
    - لو غير موجود:
      - لو unified_memory.db موجودة: ننسخها كنقطة بداية.
      - غير ذلك: لو في أي DB مصدر موجودة: ننسخ أول واحدة.
      - غير ذلك: نكتفي بإنشاء قاعدة فارغة (بدون schema).
    """
    if os.path.exists(ACTIVE_DB):
        log(f"active_memory.db already exists: {ACTIVE_DB}")
        backup_if_exists(ACTIVE_DB)
        return

    log("active_memory.db does not exist. Initializing...")
    # ترتيب تفضيل المصدر
    preferred = os.path.join(BASE_DIR, "unified_memory.db")
    src = None

    if os.path.exists(preferred):
        src = preferred
    else:
        for db in SOURCE_MEMORY_DBS:
            if os.path.exists(db):
                src = db
                break

    if src:
        shutil.copy2(src, ACTIVE_DB)
        log(f"active_memory.db initialized from {src}")
    else:
        # إنشاء ملف فارغ – سيتم إضافة schema لاحقًا لو احتجنا
        open(ACTIVE_DB, "wb").close()
        log("active_memory.db created as empty file (no schema yet).")

def table_exists(conn: sqlite3.Connection, table: str, schema: str = "main") -> bool:
    cur = conn.cursor()
    cur.execute(
        "SELECT COUNT(*) FROM {}.sqlite_master WHERE type='table' AND name=?".format(schema),
        (table,),
    )
    return cur.fetchone()[0] > 0

def unify_memory_data() -> None:
    """
    دمج بيانات الجداول (meta, sessions, messages, knowledge_items)
    من قواعد الذاكرة القديمة إلى active_memory.db
    بافتراض أن الـ schema متطابق أو متوافق.
    """
    if not os.path.exists(ACTIVE_DB):
        log("ERROR: active_memory.db does not exist. Call ensure_active_db() first.")
        return

    conn = sqlite3.connect(ACTIVE_DB)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    cur = conn.cursor()

    # إعداد ATTACH لكل قاعدة ذاكرة مصدر
    aliases = {}
    alias_index = 1
    for path in SOURCE_MEMORY_DBS:
        if os.path.exists(path) and os.path.realpath(path) != os.path.realpath(ACTIVE_DB):
            alias = f"mem{alias_index}"
            alias_index += 1
            log(f"ATTACH {path} AS {alias}")
            conn.execute(f"ATTACH DATABASE ? AS {alias}", (path,))
            aliases[alias] = path

    target_tables = ["meta", "sessions", "messages", "knowledge_items"]

    for tbl in target_tables:
        if not table_exists(conn, tbl, "main"):
            log(f"[SKIP] Table '{tbl}' not found in active_memory (main).")
            continue

        for alias, path in aliases.items():
            if not table_exists(conn, tbl, alias):
                log(f"[SKIP] Table '{tbl}' not found in {path} (alias={alias}).")
                continue

            log(f"Merging table '{tbl}' from {path} -> active_memory.db")
            try:
                # محاولة دمج مباشرة بافتراض أن الأعمدة متطابقة
                conn.execute(
                    f'INSERT OR IGNORE INTO "{tbl}" SELECT * FROM {alias}."{tbl}"'
                )
                conn.commit()
            except sqlite3.Error as e:
                log(f"ERROR merging table {tbl} from {path}: {e}")

    # DETACH
    for alias in aliases.keys():
        try:
            conn.execute(f"DETACH DATABASE {alias}")
        except sqlite3.Error as e:
            log(f"ERROR detaching {alias}: {e}")

    conn.close()
    log("Memory data unification finished.")

def seed_identity_into_meta() -> None:
    """
    حقن هوية النظام في جدول meta داخل active_memory.db.
    يدعم schema من نوع:
      - meta(key TEXT, value TEXT, ...)
      - meta(name TEXT, value TEXT, ...)
    بدون افتراضات إضافية.
    """
    if not os.path.exists(ACTIVE_DB):
        log("ERROR: active_memory.db does not exist. Cannot seed identity.")
        return

    conn = sqlite3.connect(ACTIVE_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    if not table_exists(conn, "meta", "main"):
        log("WARNING: meta table does not exist in active_memory.db. Skipping identity seed.")
        conn.close()
        return

    cur.execute("PRAGMA table_info(meta);")
    cols_info = cur.fetchall()
    col_names = [row["name"] for row in cols_info]

    key_col = None
    value_col = None

    if "key" in col_names:
        key_col = "key"
    elif "name" in col_names:
        key_col = "name"

    if "value" in col_names:
        value_col = "value"
    elif "val" in col_names:
        value_col = "val"

    if not key_col or not value_col:
        log(f"WARNING: meta table columns do not match expected pattern. cols={col_names}")
        log("Skipping identity seed to avoid corrupting data.")
        conn.close()
        return

    now_iso = datetime.now().isoformat(timespec="seconds")
    identity_pairs = {
        "identity_name": "SmartFriend Brain v2.0",
        "identity_role": "Multilayer Smart Assistant (Identity/Memory/Knowledge/Learning)",
        "schema_version": "2.0",
        "learning_policy": "continuous+curated",
        "origin": "smartfriend-suite / Contabo VPS (Asia/Kuwait, UTC+3)",
        "last_seed_timestamp": now_iso,
    }

    log(f"Seeding identity into meta (columns: {key_col}, {value_col})")

    for k, v in identity_pairs.items():
        # حذف أي سطر قديم بنفس المفتاح ثم إدخال السطر الجديد
        delete_sql = f'DELETE FROM meta WHERE {key_col} = ?'
        insert_sql = f'INSERT INTO meta ({key_col}, {value_col}) VALUES (?, ?)'

        try:
            cur.execute(delete_sql, (k,))
            cur.execute(insert_sql, (k, v))
            log(f"UPSERT meta[{k}] = {v}")
        except sqlite3.Error as e:
            log(f"ERROR seeding meta key={k}: {e}")

    conn.commit()
    conn.close()
    log("Identity seed into meta finished.")

def main():
    log("=== SmartFriend Memory Unify + Identity Seed ===")
    log(f"BASE_DIR = {BASE_DIR}")
    log(f"ACTIVE_DB = {ACTIVE_DB}")

    backup_if_exists(ACTIVE_DB)
    ensure_active_db()
    unify_memory_data()
    seed_identity_into_meta()
    log("=== DONE ===")

if __name__ == "__main__":
    main()
