#!/usr/bin/env python3
import os
import sqlite3
import json
from datetime import datetime
from typing import Dict, Any, List, Optional

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
RUNTIME_ROOT = "/opt/hyper-factory/var/db"
IDENTITY_DB = os.path.join(RUNTIME_ROOT, "identity", "identity.db")

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

def open_db_safe(path: str) -> Optional[sqlite3.Connection]:
    """Safely open a sqlite DB, or return None."""
    try:
        if not os.path.exists(path):
            return None
        conn = sqlite3.connect(path)
        conn.row_factory = sqlite3.Row
        return conn
    except Exception:
        return None

def get_or_create_entity(identity_conn,
                         entity_type: str,
                         name: str,
                         external_ref: Optional[str] = None,
                         metadata: Optional[Dict[str, Any]] = None) -> int:
    """Create or get an entity in identity.entities."""
    cur = identity_conn.cursor()

    if external_ref:
        cur.execute("SELECT id FROM entities WHERE external_ref = ?", (external_ref,))
        row = cur.fetchone()
        if row:
            return int(row[0])

    cur.execute(
        """
        INSERT INTO entities (entity_type, name, status, external_ref, meta_json, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            entity_type,
            name,
            "active",
            external_ref,
            json.dumps(metadata, ensure_ascii=False) if metadata else None,
            NOW,
        ),
    )
    identity_conn.commit()
    return int(cur.lastrowid)

def migrate_smartfrind_tables(identity_conn) -> int:
    """
    Migrate smartfrind.db tables as legacy_table entities.
    We store lightweight metadata and a few samples per table.
    """
    db_path = os.path.join(ROOT, "all_legacy_dbs", "smartfrind.db")
    if not os.path.exists(db_path):
        print("ℹ️ smartfrind.db غير موجود، تخطي.")
        return 0

    print("\n🎯 معالجة smartfrind.db (الهوية/الكونشس القديمة)...")
    migrated = 0

    conn = open_db_safe(db_path)
    if not conn:
        print("   ❌ لا يمكن فتح smartfrind.db")
        return 0

    try:
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [r[0] for r in cur.fetchall()]
        print(f"   📊 الجداول في smartfrind.db: {', '.join(tables)}")

        for table in tables:
            try:
                # جداول *_data نتعامل معها كـ BLOB-heavy → ميتاداتا بس
                if table.lower().endswith("_data"):
                    cur.execute(f'SELECT COUNT(*) FROM "{table}"')
                    count = cur.fetchone()[0]
                    print(f"   📋 {table}: {count} سجل (BLOB/FTS data) → ميتاداتا بسيطة فقط")
                    _ = get_or_create_entity(
                        identity_conn,
                        "legacy_table",
                        f"smartfrind_{table}",
                        f"smartfrind:{table}",
                        {
                            "source_db": "smartfrind.db",
                            "table_name": table,
                            "record_count": int(count),
                            "blob_heavy": True,
                        },
                    )
                    migrated += 1
                    continue

                cur.execute(f'SELECT COUNT(*) FROM "{table}"')
                count = cur.fetchone()[0]
                print(f"   📋 {table}: {count} سجل")

                # sample لحد 3 صفوف
                cur.execute(f'SELECT * FROM "{table}" LIMIT 3')
                rows = cur.fetchall()
                columns = [d[0] for d in cur.description] if cur.description else []

                samples: List[Dict[str, Any]] = []
                for row in rows:
                    row_dict: Dict[str, Any] = {}
                    for col, val in zip(columns, row):
                        if isinstance(val, (bytes, bytearray)):
                            row_dict[col] = f"<BLOB {len(val)} bytes>"
                        else:
                            row_dict[col] = val
                    samples.append(row_dict)

                if samples:
                    print(f"     الأعمدة: {columns}")
                    for i, s in enumerate(samples, start=1):
                        print(f"     عينة {i}: {str(s)[:100]}...")

                _ = get_or_create_entity(
                    identity_conn,
                    "legacy_table",
                    f"smartfrind_{table}",
                    f"smartfrind:{table}",
                    {
                        "source_db": "smartfrind.db",
                        "table_name": table,
                        "record_count": int(count),
                        "columns": columns,
                        "sample_data": samples,
                    },
                )
                migrated += 1
            except Exception as e:
                print(f"     ⚠️ خطأ في معالجة {table}: {e}")
    finally:
        conn.close()

    return migrated

def migrate_identity_from_meta() -> None:
    """Main entry to migrate identity-related information from hyper_meta.db."""
    print("🧠 HyperFFactory – الهجرة الذكية للهوية")
    print("========================================")
    print(f"  META_DB     = {META_DB}")
    print(f"  IDENTITY_DB = {IDENTITY_DB}")
    print("----------------------------------------")

    meta_conn = open_db_safe(META_DB)
    identity_conn = open_db_safe(IDENTITY_DB)

    if not meta_conn or not identity_conn:
        print("❌ لا يمكن فتح meta أو identity DB")
        return

    total_migrated = 0

    try:
        # كيان أساسي للنظام
        _ = get_or_create_entity(
            identity_conn,
            "system",
            "HyperMeta Inventory",
            "meta:hyper_meta.db",
            {"description": "HyperFFactory meta DB inventory"},
        )

        # 1) smartfrind.db
        total_migrated += migrate_smartfrind_tables(identity_conn)

        # 2) باقي ملفات الهوية/الـ legacy من hyper_meta.db
        print("\n🔍 البحث في ملفات الهوية الأخرى من hyper_meta.db ...")
        cur = meta_conn.cursor()
        cur.execute(
            """
            SELECT id, file_path, role, size_mb
            FROM db_files
            WHERE role IN ('identity', 'smartfriend_legacy')
            ORDER BY size_mb DESC
            """
        )
        rows = cur.fetchall()

        for r in rows:
            meta_id = r["id"]
            file_path = r["file_path"]
            role = r["role"]
            size_mb = r["size_mb"]

            full_path = file_path
            file_name = os.path.basename(full_path)

            # نتجنب smartfrind.db لأنه اتعالج فوق
            if "smartfrind.db" in file_name:
                continue

            if not os.path.exists(full_path):
                print(f"   ⚠️ ملف مفقود (meta_id={meta_id}): {full_path}")
                continue

            print(f"\n📂 meta_id={meta_id} | role={role} | ملف: {file_name} ({size_mb} MB)")
            print(f"   المسار الكامل: {full_path}")

            _ = get_or_create_entity(
                identity_conn,
                "legacy_identity_db",
                file_name,
                f"legacy_identity:{meta_id}",
                {
                    "meta_id": int(meta_id),
                    "role": role,
                    "path": full_path,
                    "size_mb": float(size_mb) if size_mb is not None else None,
                },
            )
            total_migrated += 1

        print("\n✅ اكتملت الهجرة الذكية للهوية!")
        print(f"📊 إجمالي الكيانات المُضافة/المُحدثة: {total_migrated}")

        cur2 = identity_conn.cursor()
        cur2.execute("SELECT entity_type, COUNT(*) FROM entities GROUP BY entity_type")
        stats = cur2.fetchall()

        print("\n📈 إحصائيات الهوية بعد الهجرة:")
        for etype, count in stats:
            print(f"   {etype}: {count}")
    except Exception as e:
        print(f"❌ خطأ عام في الهجرة: {e}")
    finally:
        meta_conn.close()
        identity_conn.close()

if __name__ == "__main__":
    migrate_identity_from_meta()
