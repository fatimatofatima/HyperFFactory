#!/usr/bin/env python3
import os
import sqlite3
from datetime import datetime

# مسارات أساسية
ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
DATA_ROOT = "/opt/hyper-factory/var/db"
IDENTITY_DB = os.path.join(DATA_ROOT, "identity", "identity.db")

CANDIDATE_TABLES = [
    "entities",
    "identity_entities",
    "sf_entities",
    "users",
    "agents",
]

def now_iso():
    return datetime.utcnow().isoformat()

def get_identity_sources():
    conn = sqlite3.connect(META_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    # نفترض وجود db_files بنفس الشكل اللي ظهر في الملخص (role / path / file_name / size_mb)
    cur.execute("""
        SELECT file_name, path, role, size_mb
        FROM db_files
        WHERE role = 'identity'
        ORDER BY size_mb DESC
    """)
    rows = cur.fetchall()
    conn.close()
    return rows

def ensure_identity_sources_metadata(sources):
    conn = sqlite3.connect(IDENTITY_DB)
    cur = conn.cursor()
    for r in sources:
        full_path = r["path"]
        # لو path نسبي، نخليه تحت ROOT
        if not full_path.startswith("/"):
            full_path = os.path.join(ROOT, full_path)
        cur.execute("""
            INSERT INTO identity_sources (source_db, source_role, size_mb, notes, created_at)
            VALUES (?, ?, ?, ?, ?)
        """, (
            full_path,
            r["role"],
            r["size_mb"],
            "auto-import from hyper_meta.db",
            now_iso(),
        ))
    conn.commit()
    conn.close()

def table_exists(conn, table_name):
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", (table_name,))
    return cur.fetchone() is not None

def get_columns(conn, table_name):
    cur = conn.cursor()
    cur.execute(f"PRAGMA table_info({table_name});")
    cols = [row[1] for row in cur.fetchall()]
    return cols

def import_from_table(identity_conn, src_conn, source_db_path, table_name):
    cols = get_columns(src_conn, table_name)
    if "name" not in cols:
        # بدون name ما نعرفش نبني كيان واضح
        return 0

    use_type = "type" in cols
    use_status = "status" in cols
    use_created = "created_at" in cols

    src_conn.row_factory = sqlite3.Row
    cur = src_conn.cursor()
    cur.execute(f"SELECT * FROM {table_name};")
    rows = cur.fetchall()

    icur = identity_conn.cursor()
    imported = 0

    for row in rows:
        # حدد primary key محتمل
        legacy_id = None
        for candidate_pk in ("id", "pk", "uid"):
            if candidate_pk in cols:
                legacy_id = row[candidate_pk]
                break
        if legacy_id is None:
            # fallback: لو مفيش id واضح، نستخدم rowid
            # (ممكن يزيد الحمل شوية، بس نضمن uniqueness مع external_ref)
            cur2 = src_conn.cursor()
            cur2.execute(f"SELECT rowid FROM {table_name} LIMIT 1;")
            legacy_id = cur2.fetchone()[0]

        entity_type = row["type"] if use_type and row["type"] is not None else "legacy_entity"
        name = row["name"]
        status = row["status"] if use_status else "unknown"
        created_at = row["created_at"] if use_created else now_iso()
        external_ref = f"{source_db_path}:{table_name}:{legacy_id}"

        meta_json = None  # ممكن لاحقًا نضيف dump جزئي

        icur.execute("""
            INSERT OR IGNORE INTO entities
            (entity_type, name, status, external_ref, meta_json, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            entity_type,
            name,
            status,
            external_ref,
            meta_json,
            created_at,
            None,
        ))
        if icur.rowcount > 0:
            imported += 1

    return imported

def main():
    if not os.path.exists(META_DB):
        raise SystemExit(f"❌ META DB غير موجودة: {META_DB}")

    if not os.path.exists(IDENTITY_DB):
        raise SystemExit(f"❌ IDENTITY DB غير موجودة: {IDENTITY_DB} (شغّل hyper_identity_init.sh أولاً)")

    sources = get_identity_sources()
    if not sources:
        print("⚠️ لا توجد مصادر role='identity' في hyper_meta.db")
    else:
        print(f"📊 عدد قواعد الهوية المرشحة: {len(sources)}")

    # سجل مصادر الهوية في identity_sources
    ensure_identity_sources_metadata(sources)

    id_conn = sqlite3.connect(IDENTITY_DB)

    total_imported = 0
    for r in sources:
        path = r["path"]
        if not path.startswith("/"):
            path = os.path.join(ROOT, path)

        if not os.path.exists(path):
            print(f"⚠️ تخطي، الملف غير موجود: {path}")
            continue

        print(f"🔍 معالجة قاعدة: {path}")
        try:
            src_conn = sqlite3.connect(path)
        except Exception as e:
            print(f"❌ فشل فتح {path}: {e}")
            continue

        imported_for_db = 0
        for tname in CANDIDATE_TABLES:
            if table_exists(src_conn, tname):
                print(f"   → محاولة استيراد من الجدول: {tname}")
                try:
                    n = import_from_table(id_conn, src_conn, path, tname)
                    imported_for_db += n
                    print(f"     ✔ تم استيراد {n} كيان من {tname}")
                except Exception as e:
                    print(f"     ❌ خطأ أثناء الاستيراد من {tname}: {e}")

        # سجل في identity_migrations
        cur = id_conn.cursor()
        cur.execute("""
            INSERT INTO identity_migrations (source_db, source_table, imported_count, run_at)
            VALUES (?, ?, ?, ?)
        """, (
            path,
            ",".join(CANDIDATE_TABLES),
            imported_for_db,
            now_iso(),
        ))
        id_conn.commit()

        total_imported += imported_for_db
        src_conn.close()

    id_conn.close()
    print(f"✅ إجمالي الكيانات المستوردة: {total_imported}")

if __name__ == "__main__":
    main()
