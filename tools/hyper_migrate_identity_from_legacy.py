#!/usr/bin/env python3
import os
import sqlite3
import json
from datetime import datetime
from typing import Dict, Any, List

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
RUNTIME_ROOT = "/opt/hyper-factory/var/db"
IDENTITY_DB = os.path.join(RUNTIME_ROOT, "identity", "identity.db")

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

# الأدوار التي نعتبرها مصادر للهوية
IDENTITY_ROLES = (
    "identity",
    "smartfriend_legacy",
    "meta_control",
    "factory_ops",
)

def open_db(path: str) -> sqlite3.Connection:
    if not os.path.exists(path):
        raise FileNotFoundError(f"DB not found: {path}")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn

def get_table_names(conn: sqlite3.Connection) -> List[str]:
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    return [r[0] for r in cur.fetchall()]

def get_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.execute(f"PRAGMA table_info({table})")
    return [r[1] for r in cur.fetchall()]

def migrate_entities(meta_conn: sqlite3.Connection,
                     id_conn: sqlite3.Connection) -> None:
    """
    قراءة كل قواعد البيانات ذات الأدوار identity/smartfriend_legacy/...،
    واستخراج جدول entities (إن وجد)، وترحيله إلى identity.entities.
    """

    dst_cols = get_columns(id_conn, "entities")
    dst_cur = id_conn.cursor()

    meta_cur = meta_conn.cursor()
    meta_cur.execute("""
        SELECT id, file_path, role, engine
        FROM db_files
        WHERE role IN ({roles})
          AND (engine IS NULL OR engine LIKE 'sqlite%')
    """.format(
        roles=",".join("?" for _ in IDENTITY_ROLES)
    ), IDENTITY_ROLES)

    db_rows = meta_cur.fetchall()
    print(f"🔎 {len(db_rows)} قاعدة بيانات مرشحة لمصدر الهوية (entities)")

    total_inserted = 0
    total_seen = 0

    for row in db_rows:
        db_id = row["id"]
        path = row["file_path"]
        role = row["role"]

        print(f"\n➡️  فحص DB (meta_id={db_id}, role={role}): {path}")

        if not path or not os.path.isabs(path):
            print(f"   ⚠️ تخطي (مسار غير مطلق): {path!r}")
            continue

        if not os.path.exists(path):
            print(f"   ⚠️ تخطي (ملف غير موجود على الديسك): {path}")
            continue

        try:
            src_conn = open_db(path)
        except Exception as e:
            print(f"   ❌ فشل فتح DB: {e}")
            continue

        try:
            tables = get_table_names(src_conn)
            if "entities" not in tables:
                print("   ℹ️ لا يوجد جدول entities هنا، تخطي.")
                src_conn.close()
                continue

            src_cols = get_columns(src_conn, "entities")
            print(f"   ✅ وجدنا entities بأعمدة: {src_cols}")

            src_cur = src_conn.cursor()
            src_cur.execute("SELECT * FROM entities")
            rows = src_cur.fetchall()

            print(f"   📦 عدد الصفوف في entities: {len(rows)}")
            total_seen += len(rows)

            for r in rows:
                src_dict = dict(r)

                new_entity: Dict[str, Any] = {}

                old_id = src_dict.get("id")
                old_external_ref = src_dict.get("external_ref")

                if old_external_ref:
                    external_ref = str(old_external_ref)
                else:
                    external_ref = f"legacy:{path}:entities:{old_id}"

                entity_type = src_dict.get("entity_type") or "legacy"
                name = src_dict.get("name") or f"LEGACY_ENTITY_{old_id}"
                status = src_dict.get("status") or "legacy"

                created_at = src_dict.get("created_at") or NOW
                updated_at = src_dict.get("updated_at") or None

                external_id = src_dict.get("external_id")
                external_source = src_dict.get("external_source")

                meta_extra: Dict[str, Any] = {}
                for k, v in src_dict.items():
                    if k in {
                        "id",
                        "entity_type",
                        "name",
                        "status",
                        "external_ref",
                        "meta_json",
                        "created_at",
                        "updated_at",
                        "external_id",
                        "external_source",
                        "metadata_json",
                    }:
                        continue
                    meta_extra[k] = v

                meta_json_source = src_dict.get("meta_json")
                metadata_json_source = src_dict.get("metadata_json")

                meta_payload: Dict[str, Any] = {}
                if meta_json_source:
                    try:
                        meta_payload.update(json.loads(meta_json_source))
                    except Exception:
                        meta_payload["meta_json_source_raw"] = str(meta_json_source)

                if metadata_json_source:
                    meta_payload.setdefault("metadata_json_source", metadata_json_source)

                if meta_extra:
                    meta_payload["legacy_extra"] = meta_extra

                meta_json_final = json.dumps(
                    {
                        "source_db_path": path,
                        "source_role": role,
                        "legacy_id": old_id,
                        "payload": meta_payload,
                    },
                    ensure_ascii=False,
                )

                new_entity["entity_type"] = entity_type
                new_entity["name"] = name
                new_entity["status"] = status
                new_entity["external_ref"] = external_ref
                new_entity["meta_json"] = meta_json_final
                new_entity["created_at"] = created_at
                new_entity["updated_at"] = updated_at
                new_entity["external_id"] = external_id
                new_entity["external_source"] = external_source
                if "metadata_json" in dst_cols:
                    new_entity["metadata_json"] = json.dumps(meta_payload, ensure_ascii=False)

                insert_cols: List[str] = []
                insert_vals: List[Any] = []

                for col in [
                    "entity_type",
                    "name",
                    "status",
                    "external_ref",
                    "meta_json",
                    "created_at",
                    "updated_at",
                    "external_id",
                    "external_source",
                    "metadata_json",
                ]:
                    if col in dst_cols and col in new_entity:
                        insert_cols.append(col)
                        insert_vals.append(new_entity[col])

                if not insert_cols:
                    continue

                placeholders = ",".join("?" for _ in insert_cols)
                sql = f"INSERT OR IGNORE INTO entities ({','.join(insert_cols)}) VALUES ({placeholders})"

                try:
                    dst_cur.execute(sql, insert_vals)
                    if dst_cur.rowcount > 0:
                        total_inserted += 1
                except sqlite3.IntegrityError:
                    # غالباً بسبب external_ref فريد -> تكرار قديم، نتجاهله
                    pass

            src_conn.close()

        except Exception as e:
            print(f"   ❌ خطأ أثناء المعالجة: {e}")
            try:
                src_conn.close()
            except Exception:
                pass
            continue

    id_conn.commit()
    print("\n✅ هجرة الهوية من القواعد القديمة انتهت.")
    print(f"   مجموع الصفوف المقروءة من المصادر: {total_seen}")
    print(f"   مجموع الكيانات الجديدة المدرجة (INSERT فعلي): {total_inserted}")

def main():
    print("🧠 HyperFFactory – Identity Migration from Legacy DBs")
    print(f"  META_DB     = {META_DB}")
    print(f"  IDENTITY_DB = {IDENTITY_DB}")
    print("--------------------------------------------------")

    if not os.path.exists(META_DB):
        raise SystemExit(f"❌ meta DB غير موجود: {META_DB}")

    if not os.path.exists(IDENTITY_DB):
        raise SystemExit(f"❌ identity DB غير موجود: {IDENTITY_DB}")

    meta_conn = open_db(META_DB)
    id_conn = open_db(IDENTITY_DB)

    try:
        migrate_entities(meta_conn, id_conn)

        cur = id_conn.cursor()
        cur.execute("SELECT COUNT(*) FROM entities;")
        total_entities = cur.fetchone()[0]
        print(f"\n📊 إجمالي الكيانات الآن في identity.entities = {total_entities}")

        print("\n🔍 عينات من entities بعد الهجرة:")
        for row in cur.execute("SELECT id, entity_type, name, status, external_ref FROM entities ORDER BY id DESC LIMIT 20;"):
            print("  ", "|".join(str(x) if x is not None else "" for x in row))

    finally:
        meta_conn.close()
        id_conn.close()

if __name__ == "__main__":
    main()
