#!/usr/bin/env python3
import os
import re
import sqlite3
import json
from datetime import datetime
from typing import Dict, Any, List, Tuple, Optional

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
MEMORY_DB = "/opt/hyper-factory/var/db/memory/memory_core_2025.db"
IDENTITY_DB = "/opt/hyper-factory/var/db/identity/identity.db"

BASE_ALLOW = {
    "active_memory",
    "neural_memory",
    "memory",
    "identity",
    "backup_20251107_051105",
    "backup_before_cleanup",
    "smart_core_memory",
    "unified_memory",
    "shared",
    "data_home",
    "smartfriend_os",
    "analysis",
    "smartfrind",
}

def now_utc() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"

def open_sqlite(path: str, label: str) -> sqlite3.Connection:
    if not os.path.exists(path):
        raise RuntimeError(f"{label} DB not found: {path}")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn

def parse_base_ver(file_name: str) -> Optional[Tuple[str, int]]:
    """
    يحلل اسم الملف مثل:
      identity.v12.db  -> (identity, 12)
      identity.db      -> (identity, 0)
      backup_2025...v6.db -> (backup_2025..., 6)
    """
    m = re.match(r"^(?P<base>.+?)(?:\.v(?P<ver>\d+))?\.db$", file_name)
    if not m:
        return None
    base = m.group("base")
    ver_str = m.group("ver")
    ver = int(ver_str) if ver_str is not None else 0
    return base, ver

def load_db_files(conn_meta: sqlite3.Connection) -> List[Tuple[str, str, str]]:
    cur = conn_meta.cursor()
    cur.execute("""
        SELECT file_path, file_name, role
        FROM db_files
        WHERE engine = 'sqlite'
    """)
    rows = cur.fetchall()
    return [(r["file_path"], r["file_name"], r["role"]) for r in rows]

def select_best_per_base(db_files: List[Tuple[str, str, str]]) -> Dict[str, Tuple[str, str, str, int]]:
    """
    يرجع لكل base (لو في allow list) أفضل ملف (أعلى version).
    يعيد dict: base -> (file_path, file_name, role, ver)
    """
    best: Dict[str, Tuple[str, str, str, int]] = {}
    for file_path, file_name, role in db_files:
        parsed = parse_base_ver(file_name)
        if not parsed:
            continue
        base, ver = parsed
        if base not in BASE_ALLOW:
            continue
        prev = best.get(base)
        if prev is None or ver > prev[3]:
            best[base] = (file_path, file_name, role, ver)
    return best

def get_tables(conn: sqlite3.Connection) -> List[str]:
    cur = conn.cursor()
    cur.execute("""
        SELECT name FROM sqlite_master
        WHERE type='table' AND name NOT LIKE 'sqlite_%'
    """)
    return [r[0] for r in cur.fetchall()]

def pick_timestamp(row: Dict[str, Any]) -> str:
    for key in ("created_at", "ts", "timestamp", "last_used", "last_update", "last_update_at"):
        val = row.get(key)
        if val:
            return str(val)
    return now_utc()

def get_pk_label(row: Dict[str, Any]) -> str:
    if "id" in row and row["id"] is not None:
        return f"id={row['id']}"
    if "key" in row and row["key"] is not None:
        return f"key={row['key']}"
    if "name" in row and row["name"] is not None:
        return f"name={row['name']}"
    return "row=unknown"

def get_meta_entity_id() -> Optional[int]:
    if not os.path.exists(IDENTITY_DB):
        return None
    try:
        conn_id = open_sqlite(IDENTITY_DB, "IDENTITY")
    except Exception:
        return None
    try:
        cur = conn_id.cursor()
        cur.execute("SELECT id FROM entities WHERE name = 'HyperMeta Inventory' LIMIT 1;")
        row = cur.fetchone()
        return int(row[0]) if row else None
    except Exception:
        return None
    finally:
        conn_id.close()

def event_exists(conn_mem: sqlite3.Connection, correlation_id: str) -> bool:
    cur = conn_mem.cursor()
    cur.execute(
        "SELECT 1 FROM events WHERE correlation_id = ? LIMIT 1;",
        (correlation_id,)
    )
    return cur.fetchone() is not None

def import_db_file(
    conn_mem: sqlite3.Connection,
    source_entity_id: Optional[int],
    file_path: str,
    file_name: str,
    base: str,
    role: str,
    stats: Dict[str, int]
) -> None:
    print(f"🔎 استيراد قاعدة: {file_name} (base={base}, role={role})")
    if not os.path.exists(file_path):
        print(f"   ⚠️ ملف غير موجود على القرص: {file_path} (تخطّي)")
        return

    try:
        conn_src = open_sqlite(file_path, f"{file_name}")
    except Exception as e:
        print(f"   ❌ تعذر فتح {file_name}: {e}")
        return

    try:
        tables = get_tables(conn_src)
        print(f"   📋 الجداول: {', '.join(tables) if tables else 'لا يوجد جداول'}")
        for table in tables:
            import_table(conn_mem, conn_src, source_entity_id, file_name, file_path, base, role, table, stats)
    finally:
        conn_src.close()

def import_table(
    conn_mem: sqlite3.Connection,
    conn_src: sqlite3.Connection,
    source_entity_id: Optional[int],
    file_name: str,
    file_path: str,
    base: str,
    role: str,
    table: str,
    stats: Dict[str, int]
) -> None:
    cur_src = conn_src.cursor()
    try:
        cur_src.execute(f"SELECT * FROM {table};")
    except Exception as e:
        print(f"   ⚠️ خطأ في قراءة جدول {table} من {file_name}: {e}")
        return

    cols = [d[0] for d in cur_src.description] if cur_src.description else []
    print(f"   🔁 استيراد جدول {table} ({len(cols)} أعمدة)...")

    cur_mem = conn_mem.cursor()
    imported_rows = 0
    row_index = 0

    for row in cur_src:
        row_index += 1
        row_dict = {cols[i]: row[i] for i in range(len(cols))}
        # نبني correlation_id فريد للصف
        pk_label = get_pk_label(row_dict)
        correlation_id = f"legacy::{base}.{table}::{pk_label}"

        if event_exists(conn_mem, correlation_id):
            continue

        # نبني payload_json مع meta عن المصدر
        payload = {
            "source_db_file": file_name,
            "source_db_path": file_path,
            "source_role": role,
            "base_name": base,
            "table": table,
            "row": row_dict,
        }
        payload_json = json.dumps(payload, ensure_ascii=False, default=str)

        ts = pick_timestamp(row_dict)
        created_at = now_utc()
        event_type = f"legacy.{base}.{table}"
        severity = "info"

        cur_mem.execute(
            """
            INSERT INTO events
                (timestamp, source_entity_id, event_type,
                 severity, payload_json, correlation_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            (ts, source_entity_id, event_type, severity, payload_json, correlation_id, created_at)
        )
        imported_rows += 1
        stats["events"] += 1

        if imported_rows % 500 == 0:
            conn_mem.commit()
            print(f"      ... {imported_rows} صف من {table} حتى الآن")

    conn_mem.commit()
    print(f"   ✅ جدول {table}: تم استيراد {imported_rows} صف جديد.")

def main():
    print("🚀 استيراد ذكريات/هويات صغيرة من قواعد legacy إلى memory_core_2025.events")
    print("======================================================================")
    print(f"  META_DB    = {META_DB}")
    print(f"  MEMORY_DB  = {MEMORY_DB}")
    print(f"  IDENTITY_DB= {IDENTITY_DB}")
    print("----------------------------------------------------------------------")

    conn_meta = open_sqlite(META_DB, "META")
    conn_mem = open_sqlite(MEMORY_DB, "MEMORY")

    # إعدادات أداء بسيطة
    conn_mem.execute("PRAGMA journal_mode=WAL;")
    conn_mem.execute("PRAGMA synchronous=NORMAL;")

    print("🔎 تحميل قائمة قواعد البيانات من hyper_meta.db...")
    db_files = load_db_files(conn_meta)
    print(f"   ✅ عدد الملفات (sqlite) = {len(db_files)}")

    best_map = select_best_per_base(db_files)
    if not best_map:
        print("   ⚠️ لم يتم العثور على أي قاعدة ضمن BASE_ALLOW.")
        return

    print("📁 القواعد المختارة لكل base (أحدث نسخة لكل عائلة):")
    for base, (file_path, file_name, role, ver) in best_map.items():
        print(f"   - base={base}, ver={ver}, file={file_name}, role={role}")

    source_entity_id = get_meta_entity_id()
    print(f"🔗 source_entity_id لـ HyperMeta Inventory = {source_entity_id}")

    stats: Dict[str, int] = {"events": 0}

    for base, (file_path, file_name, role, ver) in best_map.items():
        import_db_file(conn_mem, source_entity_id, file_path, file_name, base, role, stats)

    print("----------------------------------------------------------------------")
    print(f"✅ إجمالي الأحداث المستوردة الجديدة: {stats['events']}")
    print("ℹ️ السكربت idempotent: يستخدم correlation_id لضمان عدم تكرار نفس الصف عند تشغيله مرة أخرى.")
    print("======================================================================")

if __name__ == "__main__":
    main()
