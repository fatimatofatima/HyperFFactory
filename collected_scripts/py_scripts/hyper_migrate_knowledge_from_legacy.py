#!/usr/bin/env python3
import os
import sqlite3
import json
from datetime import datetime
from typing import Dict, Any, List, Tuple

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
RUNTIME_ROOT = "/opt/hyper-factory/var/db"
KNOW_MAIN_DB = os.path.join(RUNTIME_ROOT, "knowledge", "knowledge_main.db")

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

# الأدوار التي نعتبرها مصادر للمعرفة
SOURCE_ROLES = (
    "knowledge_hub",
    "memory_core",
    "smartfriend_legacy",
    "other",
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

def ensure_unique_index(conn: sqlite3.Connection, table: str, column: str, idx_name: str) -> None:
    cur = conn.cursor()
    cur.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS {idx} ON {tbl}({col})".format(
            idx=idx_name, tbl=table, col=column
        )
    )
    conn.commit()

def migrate_knowledge(meta_conn: sqlite3.Connection,
                      dst_conn: sqlite3.Connection) -> None:
    """
    ترحيل documents + chunks من قواعد legacy إلى knowledge_main.
    """

    dst_tables = get_table_names(dst_conn)
    if "documents" not in dst_tables or "chunks" not in dst_tables:
        raise RuntimeError("knowledge_main.db لا يحتوي على documents/chunks – راجع السكيمة أولاً.")

    dst_docs_cols = get_columns(dst_conn, "documents")
    dst_chunks_cols = get_columns(dst_conn, "chunks")

    has_docs_external_ref = "external_ref" in dst_docs_cols
    has_chunks_external_ref = "external_ref" in dst_chunks_cols

    dst_cur = dst_conn.cursor()

    if has_docs_external_ref:
        ensure_unique_index(dst_conn, "documents", "external_ref", "idx_documents_external_ref_unique")
    if has_chunks_external_ref:
        ensure_unique_index(dst_conn, "chunks", "external_ref", "idx_chunks_external_ref_unique")

    meta_cur = meta_conn.cursor()
    meta_cur.execute("""
        SELECT id, file_path, role, engine
        FROM db_files
        WHERE role IN ({roles})
          AND (engine IS NULL OR engine LIKE 'sqlite%')
    """.format(
        roles=",".join("?" for _ in SOURCE_ROLES)
    ), SOURCE_ROLES)

    db_rows = meta_cur.fetchall()
    print(f"🔎 {len(db_rows)} قاعدة بيانات مرشحة لمصدر المعرفة (documents/chunks)")

    total_docs_seen = 0
    total_docs_inserted = 0
    total_chunks_seen = 0
    total_chunks_inserted = 0

    for row in db_rows:
        db_id = row["id"]
        path = row["file_path"]
        role = row["role"]
        engine = row["engine"]

        print(f"\n➡️  فحص DB (meta_id={db_id}, role={role}, engine={engine}): {path}")

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
            if "documents" not in tables or "chunks" not in tables:
                print("   ℹ️ لا يوجد الجدولان documents + chunks هنا، تخطي.")
                src_conn.close()
                continue

            src_docs_cols = get_columns(src_conn, "documents")
            src_chunks_cols = get_columns(src_conn, "chunks")

            print(f"   ✅ وجدنا documents بأعمدة: {src_docs_cols}")
            print(f"   ✅ وجدنا chunks بأعمدة: {src_chunks_cols}")

            src_docs_cur = src_conn.cursor()
            src_docs_cur.execute("SELECT * FROM documents")
            src_docs_rows = src_docs_cur.fetchall()
            print(f"   📦 عدد الصفوف في documents: {len(src_docs_rows)}")

            # خريطة ربط doc القديم بالجديد
            doc_id_map: Dict[Tuple[str, int], int] = {}

            # ============ ترحيل documents ============
            for d in src_docs_rows:
                d_dict = dict(d)
                old_id = d_dict.get("id")
                total_docs_seen += 1

                # نحاول استخدام external_ref الأصلي لو موجود
                legacy_external_ref = d_dict.get("external_ref")
                legacy_external_id = d_dict.get("external_id")

                if legacy_external_ref:
                    external_ref = str(legacy_external_ref)
                elif legacy_external_id:
                    external_ref = f"{path}:doc_ext:{legacy_external_id}"
                else:
                    external_ref = f"{path}:documents:{old_id}"

                # لو عندنا external_ref في الهدف نستخدمه لمنع التكرار
                new_doc_id = None
                if has_docs_external_ref:
                    row_existing = dst_cur.execute(
                        "SELECT id FROM documents WHERE external_ref = ? LIMIT 1",
                        (external_ref,)
                    ).fetchone()
                    if row_existing:
                        new_doc_id = row_existing[0]

                if new_doc_id is None:
                    # بناء meta_payload من الأعمدة الإضافية
                    meta_extra: Dict[str, Any] = {}
                    for k, v in d_dict.items():
                        if k in {
                            "id",
                            "title",
                            "name",
                            "external_ref",
                            "external_id",
                            "created_at",
                            "updated_at",
                            "source_id",
                            "source",
                            "meta_json",
                            "metadata_json",
                            "status",
                            "type",
                        }:
                            continue
                        meta_extra[k] = v

                    meta_payload: Dict[str, Any] = {
                        "source_db_path": path,
                        "source_role": role,
                        "legacy_id": old_id,
                    }
                    src_meta_json = d_dict.get("meta_json")
                    src_metadata_json = d_dict.get("metadata_json")

                    if src_meta_json:
                        try:
                            meta_payload["legacy_meta_json"] = json.loads(src_meta_json)
                        except Exception:
                            meta_payload["legacy_meta_json_raw"] = str(src_meta_json)

                    if src_metadata_json:
                        meta_payload["legacy_metadata_json"] = src_metadata_json

                    if meta_extra:
                        meta_payload["legacy_extra"] = meta_extra

                    meta_json_final = json.dumps(meta_payload, ensure_ascii=False)

                    new_doc: Dict[str, Any] = {}

                    # تحديد عنوان المستند
                    title_val = (
                        d_dict.get("title")
                        or d_dict.get("name")
                        or f"LEGACY_DOCUMENT_{old_id}"
                    )

                    # تعبئة الحقول حسب ما هو متاح في السكيمة الجديدة
                    if "title" in dst_docs_cols:
                        new_doc["title"] = title_val
                    if "name" in dst_docs_cols and "title" not in dst_docs_cols:
                        new_doc["name"] = title_val

                    if has_docs_external_ref:
                        new_doc["external_ref"] = external_ref

                    if "external_id" in dst_docs_cols:
                        new_doc["external_id"] = legacy_external_id

                    if "status" in dst_docs_cols:
                        new_doc["status"] = d_dict.get("status") or "legacy"

                    if "type" in dst_docs_cols:
                        new_doc["type"] = d_dict.get("type") or "legacy"

                    if "source_id" in dst_docs_cols:
                        new_doc["source_id"] = d_dict.get("source_id")
                    if "source" in dst_docs_cols:
                        new_doc["source"] = d_dict.get("source")

                    created_at = d_dict.get("created_at") or NOW
                    updated_at = d_dict.get("updated_at") or None

                    if "created_at" in dst_docs_cols:
                        new_doc["created_at"] = created_at
                    if "updated_at" in dst_docs_cols:
                        new_doc["updated_at"] = updated_at

                    if "meta_json" in dst_docs_cols:
                        new_doc["meta_json"] = meta_json_final
                    if "metadata_json" in dst_docs_cols:
                        # نسخة مسطحة بدون رأس إضافي
                        try:
                            payload_flat = meta_payload.get("legacy_meta_json") or {}
                        except Exception:
                            payload_flat = meta_payload
                        new_doc["metadata_json"] = json.dumps(payload_flat, ensure_ascii=False)

                    insert_cols: List[str] = []
                    insert_vals: List[Any] = []

                    for col in dst_docs_cols:
                        if col == "id":
                            continue
                        if col in new_doc:
                            insert_cols.append(col)
                            insert_vals.append(new_doc[col])

                    if not insert_cols:
                        print(f"   ⚠️ تخطي document id={old_id} – لا توجد أعمدة قابلة للإدراج.")
                        continue

                    placeholders = ",".join("?" for _ in insert_cols)
                    sql = f"INSERT OR IGNORE INTO documents ({','.join(insert_cols)}) VALUES ({placeholders})"

                    dst_cur.execute(sql, insert_vals)
                    if dst_cur.rowcount > 0:
                        total_docs_inserted += 1
                        new_doc_id = dst_cur.lastrowid
                    else:
                        # في حال OR IGNORE مع external_ref موجود مسبقًا – نحاول قراءته
                        if has_docs_external_ref:
                            row_existing = dst_cur.execute(
                                "SELECT id FROM documents WHERE external_ref = ? LIMIT 1",
                                (external_ref,)
                            ).fetchone()
                            if row_existing:
                                new_doc_id = row_existing[0]

                if new_doc_id is not None:
                    doc_id_map[(path, int(old_id))] = int(new_doc_id)

            # ============ ترحيل chunks ============
            src_chunks_cur = src_conn.cursor()
            src_chunks_cur.execute("SELECT * FROM chunks")
            src_chunks_rows = src_chunks_cur.fetchall()
            print(f"   📦 عدد الصفوف في chunks: {len(src_chunks_rows)}")

            for c in src_chunks_rows:
                c_dict = dict(c)
                old_chunk_id = c_dict.get("id")
                total_chunks_seen += 1

                # نحاول معرفة document_id القديم
                old_doc_id = (
                    c_dict.get("document_id")
                    or c_dict.get("doc_id")
                    or c_dict.get("documentId")
                )

                new_doc_id = None
                if old_doc_id is not None:
                    new_doc_id = doc_id_map.get((path, int(old_doc_id)))

                # لو لا يوجد mapping للـ document – ممكن نستخدم مستند افتراضي لاحقًا، الآن نتخطى
                if new_doc_id is None:
                    # نقدر نسجلها في meta فقط أو نتجاهلها الآن
                    # لتفادي بيانات يتيمة، سنتجاهل الآن
                    continue

                # external_ref للـ chunk (إن وجد في الهدف)
                chunk_external_ref = None
                if has_chunks_external_ref:
                    legacy_chunk_ext = c_dict.get("external_ref")
                    if legacy_chunk_ext:
                        chunk_external_ref = str(legacy_chunk_ext)
                    else:
                        chunk_external_ref = f"{path}:chunks:{old_chunk_id}"

                # تحقق من التكرار
                if has_chunks_external_ref and chunk_external_ref is not None:
                    row_existing = dst_cur.execute(
                        "SELECT id FROM chunks WHERE external_ref = ? LIMIT 1",
                        (chunk_external_ref,)
                    ).fetchone()
                    if row_existing:
                        continue  # chunk موجود مسبقًا

                # اختيار حقل النص المشترك
                candidate_text_cols = ["content", "text", "chunk_text", "body"]
                text_col = None
                for col in candidate_text_cols:
                    if col in c_dict and col in dst_chunks_cols:
                        text_col = col
                        break

                text_val = c_dict.get(text_col) if text_col else None

                # meta_extra للأعمدة الإضافية
                meta_extra: Dict[str, Any] = {}
                for k, v in c_dict.items():
                    if k in {
                        "id",
                        "document_id",
                        "doc_id",
                        "documentId",
                        "external_ref",
                        text_col,
                        "meta_json",
                        "metadata_json",
                        "created_at",
                        "updated_at",
                        "order",
                        "index",
                    }:
                        continue
                    meta_extra[k] = v

                meta_payload: Dict[str, Any] = {
                    "source_db_path": path,
                    "source_role": role,
                    "legacy_chunk_id": old_chunk_id,
                    "legacy_document_id": old_doc_id,
                }
                src_meta_json = c_dict.get("meta_json")
                src_metadata_json = c_dict.get("metadata_json")

                if src_meta_json:
                    try:
                        meta_payload["legacy_meta_json"] = json.loads(src_meta_json)
                    except Exception:
                        meta_payload["legacy_meta_json_raw"] = str(src_meta_json)

                if src_metadata_json:
                    meta_payload["legacy_metadata_json"] = src_metadata_json

                if meta_extra:
                    meta_payload["legacy_extra"] = meta_extra

                meta_json_final = json.dumps(meta_payload, ensure_ascii=False)

                new_chunk: Dict[str, Any] = {}

                if "document_id" in dst_chunks_cols:
                    new_chunk["document_id"] = new_doc_id

                if text_col and text_col in dst_chunks_cols:
                    new_chunk[text_col] = text_val
                else:
                    # لو ما فيش عمود نص متطابق – ممكن نحفظ النص داخل meta_json فقط
                    pass

                if has_chunks_external_ref and chunk_external_ref is not None:
                    new_chunk["external_ref"] = chunk_external_ref

                if "created_at" in dst_chunks_cols:
                    new_chunk["created_at"] = c_dict.get("created_at") or NOW
                if "updated_at" in dst_chunks_cols:
                    new_chunk["updated_at"] = c_dict.get("updated_at") or None

                if "meta_json" in dst_chunks_cols:
                    new_chunk["meta_json"] = meta_json_final
                if "metadata_json" in dst_chunks_cols:
                    try:
                        payload_flat = meta_payload.get("legacy_meta_json") or {}
                    except Exception:
                        payload_flat = meta_payload
                    new_chunk["metadata_json"] = json.dumps(payload_flat, ensure_ascii=False)

                if "order" in dst_chunks_cols and "order" in c_dict:
                    new_chunk["order"] = c_dict.get("order")
                if "index" in dst_chunks_cols and "index" in c_dict:
                    new_chunk["index"] = c_dict.get("index")

                insert_cols_c: List[str] = []
                insert_vals_c: List[Any] = []

                for col in dst_chunks_cols:
                    if col == "id":
                        continue
                    if col in new_chunk:
                        insert_cols_c.append(col)
                        insert_vals_c.append(new_chunk[col])

                if not insert_cols_c:
                    # لا توجد أعمدة قابلة للإدراج – نتجاهل
                    continue

                placeholders_c = ",".join("?" for _ in insert_cols_c)
                sql_c = f"INSERT OR IGNORE INTO chunks ({','.join(insert_cols_c)}) VALUES ({placeholders_c})"

                dst_cur.execute(sql_c, insert_vals_c)
                if dst_cur.rowcount > 0:
                    total_chunks_inserted += 1

            src_conn.close()

        except Exception as e:
            print(f"   ❌ خطأ أثناء المعالجة: {e}")
            try:
                src_conn.close()
            except Exception:
                pass
            continue

    dst_conn.commit()
    print("\n✅ هجرة المعرفة من قواعد legacy انتهت.")
    print(f"   مجموع documents المقروءة من المصادر: {total_docs_seen}")
    print(f"   مجموع documents المدرجة فعليًا:       {total_docs_inserted}")
    print(f"   مجموع chunks المقروءة من المصادر:    {total_chunks_seen}")
    print(f"   مجموع chunks المدرجة فعليًا:          {total_chunks_inserted}")

def main():
    print("🧠 HyperFFactory – Knowledge Migration from Legacy DBs")
    print(f"  META_DB       = {META_DB}")
    print(f"  KNOW_MAIN_DB  = {KNOW_MAIN_DB}")
    print("--------------------------------------------------")

    if not os.path.exists(META_DB):
        raise SystemExit(f"❌ meta DB غير موجود: {META_DB}")

    if not os.path.exists(KNOW_MAIN_DB):
        raise SystemExit(f"❌ knowledge_main DB غير موجود: {KNOW_MAIN_DB}")

    meta_conn = open_db(META_DB)
    dst_conn = open_db(KNOW_MAIN_DB)

    try:
        migrate_knowledge(meta_conn, dst_conn)

        cur = dst_conn.cursor()
        cur.execute("SELECT COUNT(*) FROM documents;")
        total_docs = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM chunks;")
        total_chunks = cur.fetchone()[0]

        print(f"\n📊 إجمالي documents الآن في knowledge_main.documents = {total_docs}")
        print(f"📊 إجمالي chunks الآن في knowledge_main.chunks       = {total_chunks}")

        print("\n🔍 عينات من documents بعد الهجرة:")
        for row in cur.execute(
            "SELECT id, "
            + ("external_ref, " if "external_ref" in get_columns(dst_conn, "documents") else "")
            + "title FROM documents ORDER BY id DESC LIMIT 20;"
        ):
            print("  ", "|".join(str(x) if x is not None else "" for x in row))

    finally:
        meta_conn.close()
        dst_conn.close()

if __name__ == "__main__":
    main()
