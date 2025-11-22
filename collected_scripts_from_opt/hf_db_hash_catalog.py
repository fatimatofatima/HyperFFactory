import os
import sqlite3
import hashlib
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DB_ROOT = os.path.join(BASE_DIR, "data_lakehouse", "db", "sqlite")
KNOWLEDGE_DB = os.path.join(BASE_DIR, "data", "knowledge", "knowledge.db")

def iter_db_files():
    for name in os.listdir(DB_ROOT):
        if name.endswith(".db") or name.endswith(".sqlite"):
            yield os.path.join(DB_ROOT, name)

def file_hash_and_stats(path: str):
    # وظيفة مستقلة لكل ملف – تستخدم في 6 أنوية
    h = hashlib.sha256()
    size = 0
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            if not chunk:
                break
            h.update(chunk)
            size += len(chunk)
    sha = h.hexdigest()

    # عدد الجداول
    tables_count = 0
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        tables_count = cur.fetchone()[0]
        conn.close()
    except Exception:
        tables_count = -1  # يعني فشل القراءة لكن الملف متسجّل

    return (path, sha, size, tables_count)

def ensure_catalog_schema(conn: sqlite3.Connection):
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS project_merging (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        db_path TEXT UNIQUE,
        sha256 TEXT,
        size_bytes INTEGER,
        tables_count INTEGER,
        last_scan_at TEXT
    )
    """)
    conn.commit()

def main():
    os.makedirs(os.path.dirname(KNOWLEDGE_DB), exist_ok=True)
    conn = sqlite3.connect(KNOWLEDGE_DB)
    ensure_catalog_schema(conn)
    cur = conn.cursor()

    db_files = list(iter_db_files())
    print(f"Found {len(db_files)} DB files under {DB_ROOT}")

    # 6 أنوية
    with ProcessPoolExecutor(max_workers=6) as ex:
        futures = {ex.submit(file_hash_and_stats, p): p for p in db_files}
        for fut in as_completed(futures):
            path, sha, size, tables_count = fut.result()
            now = datetime.utcnow().isoformat(timespec="seconds") + "Z"
            cur.execute("""
            INSERT INTO project_merging (db_path, sha256, size_bytes, tables_count, last_scan_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(db_path) DO UPDATE SET
                sha256=excluded.sha256,
                size_bytes=excluded.size_bytes,
                tables_count=excluded.tables_count,
                last_scan_at=excluded.last_scan_at
            """, (path, sha, size, tables_count, now))
            conn.commit()
            print(f"[OK] {os.path.basename(path)}  size={size}  tables={tables_count}")

    conn.close()
    print("Catalog update completed.")

if __name__ == "__main__":
    main()
