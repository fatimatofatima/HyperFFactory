#!/usr/bin/env python3
import sys
import os
import sqlite3
import csv
import json
from datetime import datetime

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS db_scan_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT,
    source_tsv TEXT NOT NULL,
    created_at TEXT NOT NULL,
    total_files INTEGER,
    total_size_mb REAL
);

CREATE TABLE IF NOT EXISTS db_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_run_id INTEGER NOT NULL,
    file_name TEXT NOT NULL,
    path TEXT NOT NULL,
    role TEXT,
    size_mb REAL,
    is_sqlite INTEGER,
    num_tables INTEGER,
    status TEXT,
    mtime TEXT,
    extra_json TEXT,
    FOREIGN KEY(scan_run_id) REFERENCES db_scan_runs(id)
);

CREATE INDEX IF NOT EXISTS idx_db_files_role ON db_files(role);
CREATE INDEX IF NOT EXISTS idx_db_files_path ON db_files(path);
"""


def load_rows(tsv_path):
    rows = []
    with open(tsv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            rows.append(dict(row))
    return rows


def to_bool_int(v):
    if v is None:
        return None
    s = str(v).strip().lower()
    if s in ("1", "true", "yes", "y", "on"):
        return 1
    if s in ("0", "false", "no", "n", "off"):
        return 0
    return None


def to_float(v):
    try:
        return float(v)
    except Exception:
        return None


def to_int(v):
    try:
        return int(v)
    except Exception:
        return None


def main():
    if len(sys.argv) < 3:
        print("Usage: hyper_meta_import_dbs.py <tsv_path> <meta_db_path> [label]", file=sys.stderr)
        sys.exit(1)

    tsv_path = os.path.abspath(sys.argv[1])
    meta_db = os.path.abspath(sys.argv[2])
    label = sys.argv[3] if len(sys.argv) >= 4 else "auto_import"

    if not os.path.exists(tsv_path):
        print(f"❌ TSV not found: {tsv_path}", file=sys.stderr)
        sys.exit(1)

    print(f"📄 TSV: {tsv_path}")
    print(f"🗄️ META DB: {meta_db}")

    rows = load_rows(tsv_path)
    print(f"🔎 Rows in TSV: {len(rows)}")

    os.makedirs(os.path.dirname(meta_db), exist_ok=True)
    conn = sqlite3.connect(meta_db)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA foreign_keys=ON;")

    cur = conn.cursor()
    cur.executescript(SCHEMA_SQL)

    total_size = 0.0
    for r in rows:
        total_size += to_float(r.get("size_mb")) or 0.0

    created_at = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    cur.execute(
        """
        INSERT INTO db_scan_runs (label, source_tsv, created_at, total_files, total_size_mb)
        VALUES (?, ?, ?, ?, ?)
        """,
        (label, tsv_path, created_at, len(rows), total_size),
    )
    scan_run_id = cur.lastrowid

    for r in rows:
        # نحاول نقرأ الأعمدة لو موجودة، وإلا نعتمد على بدائل
        path = r.get("path") or r.get("full_path") or r.get("db_path") or ""
        file_name = r.get("file_name") or os.path.basename(path) or r.get("name") or "unknown.db"
        role = r.get("role") or r.get("group") or r.get("category")
        size_mb = to_float(r.get("size_mb"))
        is_sqlite = to_bool_int(r.get("is_sqlite"))
        num_tables = to_int(r.get("num_tables"))
        status = r.get("status")
        mtime = r.get("mtime")

        extra_json = json.dumps(r, ensure_ascii=False)

        cur.execute(
            """
            INSERT INTO db_files (
                scan_run_id, file_name, path, role,
                size_mb, is_sqlite, num_tables, status, mtime, extra_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                scan_run_id,
                file_name,
                path,
                role,
                size_mb,
                is_sqlite,
                num_tables,
                status,
                mtime,
                extra_json,
            ),
        )

    conn.commit()
    print(f"✅ Imported {len(rows)} rows into db_files (scan_run_id={scan_run_id})")
    conn.close()


if __name__ == "__main__":
    main()
