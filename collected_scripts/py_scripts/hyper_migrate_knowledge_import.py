#!/usr/bin/env python3
import os
import sqlite3
import json
import hashlib
from datetime import datetime
from typing import Dict, Any, List, Tuple, Set

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
KNOWLEDGE_DB = "/opt/hyper-factory/var/db/knowledge/knowledge_main.db"

def now_utc() -> str:
    return datetime.utcnow().isoformat(timespec="seconds") + "Z"

def open_sqlite(path: str, label: str) -> sqlite3.Connection:
    if not os.path.exists(path):
        raise RuntimeError(f"{label} DB not found: {path}")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn

def table_exists(conn: sqlite3.Connection, name: str) -> bool:
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", (name,))
    return cur.fetchone() is not None

def get_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.cursor()
    cur.execute(f"PRAGMA table_info('{table}');")
    return [r[1] for r in cur.fetchall()]

def md5_of_text(text: str) -> str:
    if text is None:
        text = ""
    return hashlib.md5(text.encode("utf-8")).hexdigest()

def load_existing_hashes(conn_knowledge: sqlite3.Connection) -> Set[str]:
    cur = conn_knowledge.cursor()
    try:
        cur.execute("SELECT content_hash FROM documents WHERE content_hash IS NOT NULL;")
        rows = cur.fetchall()
        hashes = {r[0] for r in rows if r[0]}
        print(f"   ℹ️ existing content_hash count in documents = {len(hashes)}")
        return hashes
    except sqlite3.OperationalError as e:
        print(f"   ⚠️ لا يمكن قراءة content_hash من documents: {e}")
        return set()

def pick_primary_unified_db(conn_meta: sqlite3.Connection) -> Tuple[str, str, float]:
    cur = conn_meta.cursor()
    # نحاول اختيار أحدث وأكبر smartfriend_unified*.db
    cur.execute("""
        SELECT file_path, file_name, size_mb
        FROM db_files
        WHERE role = 'knowledge_hub'
          AND engine = 'sqlite'
          AND file_name LIKE 'smartfriend_unified%.db'
        ORDER BY size_mb DESC, id DESC
        LIMIT 1;
    """)
    row = cur.fetchone()
    if not row:
        raise RuntimeError("لم يتم العثور على smartfriend_unified*.db في hyper_meta.db")
    file_path, file_name, size_mb = row
    return file_path, file_name, size_mb

def migrate_knowledge_base(src: sqlite3.Connection,
                           dst: sqlite3.Connection,
                           existing_hashes: Set[str],
                           stats: Dict[str, int]) -> None:
    if not table_exists(src, "knowledge_base"):
        print("   ℹ️ جدول knowledge_base غير موجود في المصدر، تخطّي.")
        return

    cols = get_columns(src, "knowledge_base")
    cur_src = src.cursor()
    cur_dst = dst.cursor()

    id_idx = cols.index("id") if "id" in cols else None
    url_idx = cols.index("url") if "url" in cols else None
    title_idx = cols.index("title") if "title" in cols else None
    content_idx = cols.index("content") if "content" in cols else None
    content_hash_idx = cols.index("content_hash") if "content_hash" in cols else None

    print(f"   🔁 هجرة knowledge_base ({len(cols)} أعمدة)...")
    cur_src.execute("SELECT * FROM knowledge_base;")

    batch = 0
    for row in cur_src:
        row = dict(zip(cols, row))

        content = row.get("content") or ""
        if not content.strip():
            continue

        ch = row.get("content_hash") if content_hash_idx is not None else None
        if not ch:
            ch = md5_of_text(content)

        if ch in existing_hashes:
            continue

        kb_id = row.get("id")
        url = row.get("url")
        title = row.get("title")
        source_type = row.get("source_type", "knowledge_base")
        meta = {
            "origin": "smartfriend_unified.knowledge_base",
            "legacy_id": kb_id,
            "url": url,
            "quality_score": row.get("quality_score"),
            "promoted_at": row.get("promoted_at"),
            "source_type": source_type,
            "deleted_at": row.get("deleted_at"),
            "metadata_raw": row.get("metadata"),
        }

        now = now_utc()
        cur_dst.execute("""
            INSERT INTO documents
                (external_id, source_type, source_ref, title,
                 lang, created_at, indexed_at, meta_json,
                 external_source, source_metadata, content_hash,
                 embedding_model, chunk_index, content)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            f"kb:{kb_id}" if kb_id is not None else None,
            "knowledge_base",
            url,
            title,
            None,
            now,
            now,
            json.dumps(meta, ensure_ascii=False),
            "smartfriend_unified.knowledge_base",
            None,
            ch,
            None,
            0,
            content,
        ))
        doc_id = cur_dst.lastrowid

        cur_dst.execute("""
            INSERT INTO chunks
                (document_id, seq, content, token_count,
                 meta_json, created_at, content_hash,
                 embedding_model, embedding)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            doc_id,
            0,
            content,
            None,
            None,
            now,
            ch,
            None,
            None,
        ))

        existing_hashes.add(ch)
        stats["kb_docs"] += 1
        stats["kb_chunks"] += 1
        batch += 1

        if batch % 1000 == 0:
            dst.commit()
            print(f"     ... {batch} rows from knowledge_base migrated so far.")

    dst.commit()
    print(f"   ✅ تم نقل {stats['kb_docs']} document و {stats['kb_chunks']} chunk من knowledge_base.")

def migrate_ai_memory(src: sqlite3.Connection,
                      dst: sqlite3.Connection,
                      existing_hashes: Set[str],
                      stats: Dict[str, int]) -> None:
    if not table_exists(src, "ai_memory"):
        print("   ℹ️ جدول ai_memory غير موجود في المصدر، تخطّي.")
        return

    cols = get_columns(src, "ai_memory")
    cur_src = src.cursor()
    cur_dst = dst.cursor()

    print(f"   🔁 هجرة ai_memory ({len(cols)} أعمدة)...")
    cur_src.execute("SELECT * FROM ai_memory;")

    batch = 0
    for raw in cur_src:
        row = dict(zip(cols, raw))
        user_id = row.get("user_id")
        user_input = (row.get("user_input") or "").strip()
        ai_response = (row.get("ai_response") or "").strip()
        if not user_input and not ai_response:
            continue

        combined = f"Q: {user_input}\n\nA: {ai_response}" if user_input or ai_response else ""
        if not combined.strip():
            continue

        ch = md5_of_text(combined)
        if ch in existing_hashes:
            continue

        aim_id = row.get("id")
        meta = {
            "origin": "smartfriend_unified.ai_memory",
            "legacy_id": aim_id,
            "user_id": user_id,
            "category": row.get("category"),
            "importance": row.get("importance"),
            "created_at_raw": row.get("created_at"),
        }

        now = now_utc()
        cur_dst.execute("""
            INSERT INTO documents
                (external_id, source_type, source_ref, title,
                 lang, created_at, indexed_at, meta_json,
                 external_source, source_metadata, content_hash,
                 embedding_model, chunk_index, content)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            f"aim:{aim_id}" if aim_id is not None else None,
            "ai_memory",
            user_id,
            f"ai_memory entry #{aim_id}" if aim_id is not None else None,
            None,
            now,
            now,
            json.dumps(meta, ensure_ascii=False),
            "smartfriend_unified.ai_memory",
            None,
            ch,
            None,
            0,
            combined,
        ))
        doc_id = cur_dst.lastrowid

        cur_dst.execute("""
            INSERT INTO chunks
                (document_id, seq, content, token_count,
                 meta_json, created_at, content_hash,
                 embedding_model, embedding)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            doc_id,
            0,
            combined,
            None,
            None,
            now,
            ch,
            None,
            None,
        ))

        existing_hashes.add(ch)
        stats["ai_docs"] += 1
        stats["ai_chunks"] += 1
        batch += 1

        if batch % 2000 == 0:
            dst.commit()
            print(f"     ... {batch} rows from ai_memory migrated so far.")

    dst.commit()
    print(f"   ✅ تم نقل {stats['ai_docs']} document و {stats['ai_chunks']} chunk من ai_memory.")

def migrate_memories(src: sqlite3.Connection,
                     dst: sqlite3.Connection,
                     existing_hashes: Set[str],
                     stats: Dict[str, int]) -> None:
    if not table_exists(src, "memories"):
        print("   ℹ️ جدول memories غير موجود في المصدر، تخطّي.")
        return

    cols = get_columns(src, "memories")
    cur_src = src.cursor()
    cur_dst = dst.cursor()

    print(f"   🔁 هجرة memories ({len(cols)} أعمدة)...")
    cur_src.execute("SELECT * FROM memories;")

    batch = 0
    for raw in cur_src:
        row = dict(zip(cols, raw))
        content = (row.get("content") or "").strip()
        if not content:
            continue

        ch = md5_of_text(content)
        if ch in existing_hashes:
            continue

        mem_id = row.get("id")
        meta = {
            "origin": "smartfriend_unified.memories",
            "legacy_id": mem_id,
            "memory_type": row.get("memory_type"),
            "created_at_raw": row.get("created_at"),
            "accessed_at": row.get("accessed_at"),
            "access_count": row.get("access_count"),
            "importance_score": row.get("importance_score"),
        }

        now = now_utc()
        cur_dst.execute("""
            INSERT INTO documents
                (external_id, source_type, source_ref, title,
                 lang, created_at, indexed_at, meta_json,
                 external_source, source_metadata, content_hash,
                 embedding_model, chunk_index, content)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            f"mem:{mem_id}" if mem_id is not None else None,
            "memory",
            None,
            f"memory #{mem_id}" if mem_id is not None else None,
            None,
            now,
            now,
            json.dumps(meta, ensure_ascii=False),
            "smartfriend_unified.memories",
            None,
            ch,
            None,
            0,
            content,
        ))
        doc_id = cur_dst.lastrowid

        cur_dst.execute("""
            INSERT INTO chunks
                (document_id, seq, content, token_count,
                 meta_json, created_at, content_hash,
                 embedding_model, embedding)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            doc_id,
            0,
            content,
            None,
            None,
            now,
            ch,
            None,
            None,
        ))

        existing_hashes.add(ch)
        stats["mem_docs"] += 1
        stats["mem_chunks"] += 1
        batch += 1

        if batch % 500 == 0:
            dst.commit()
            print(f"     ... {batch} rows from memories migrated so far.")

    dst.commit()
    print(f"   ✅ تم نقل {stats['mem_docs']} document و {stats['mem_chunks']} chunk من memories.")

def main():
    print("🚀 بدء هجرة المعرفة الفعلية (بدون تكرار)...")
    print("===========================================")
    print(f"  META_DB      = {META_DB}")
    print(f"  KNOWLEDGE_DB = {KNOWLEDGE_DB}")
    print("-------------------------------------------")

    conn_meta = open_sqlite(META_DB, "META")
    conn_know = open_sqlite(KNOWLEDGE_DB, "KNOWLEDGE")

    # تهيئة إعدادات أداء خفيفة
    conn_know.execute("PRAGMA journal_mode=WAL;")
    conn_know.execute("PRAGMA synchronous=NORMAL;")

    print("🔎 اختيار قاعدة unified الأساسية من hyper_meta.db ...")
    primary_path, primary_name, primary_size = pick_primary_unified_db(conn_meta)
    print(f"   🗄 المصدر الأساسي: {primary_name} ({primary_size} MB)")
    print(f"      المسار: {primary_path}")

    conn_src = open_sqlite(primary_path, "UNIFIED")

    existing_hashes = load_existing_hashes(conn_know)

    stats = {
        "kb_docs": 0,
        "kb_chunks": 0,
        "ai_docs": 0,
        "ai_chunks": 0,
        "mem_docs": 0,
        "mem_chunks": 0,
    }

    migrate_knowledge_base(conn_src, conn_know, existing_hashes, stats)
    migrate_ai_memory(conn_src, conn_know, existing_hashes, stats)
    migrate_memories(conn_src, conn_know, existing_hashes, stats)

    total_docs = stats["kb_docs"] + stats["ai_docs"] + stats["mem_docs"]
    total_chunks = stats["kb_chunks"] + stats["ai_chunks"] + stats["mem_chunks"]

    print("-------------------------------------------")
    print("✅ ملخص الهجرة:")
    print(f"   knowledge_base → {stats['kb_docs']} docs / {stats['kb_chunks']} chunks")
    print(f"   ai_memory      → {stats['ai_docs']} docs / {stats['ai_chunks']} chunks")
    print(f"   memories       → {stats['mem_docs']} docs / {stats['mem_chunks']} chunks")
    print(f"   الإجمالي       → {total_docs} docs / {total_chunks} chunks")
    print("===========================================")
    print("ℹ️ السكربت idempotent: تشغيله مرة أخرى لن يكرر البيانات (يعتمد على content_hash).")

if __name__ == "__main__":
    main()
