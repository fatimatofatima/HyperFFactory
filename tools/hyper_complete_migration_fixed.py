#!/usr/bin/env python3
import os
import sqlite3
from datetime import datetime

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
IDENTITY_DB = "/opt/hyper-factory/var/db/identity/identity.db"
MEMORY_DB = "/opt/hyper-factory/var/db/memory/memory_core_2025.db"
KNOWLEDGE_DB = "/opt/hyper-factory/var/db/knowledge/knowledge_main.db"

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

def open_db(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn

def setup_knowledge_schema():
    """Ensure knowledge_main has documents + chunks with correct columns/indexes."""
    print("📚 إعداد سكيما قاعدة المعرفة...")
    os.makedirs(os.path.dirname(KNOWLEDGE_DB), exist_ok=True)
    conn = open_db(KNOWLEDGE_DB)
    cur = conn.cursor()

    # إنشاء جدول documents إن لم يكن موجودًا (مع external_source)
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            external_id TEXT,
            source_db TEXT,
            source_table TEXT,
            source_row_id TEXT,
            title TEXT,
            content TEXT,
            meta_json TEXT,
            external_source TEXT,
            created_at TEXT
        )
        """
    )

    # التأكد من وجود العمود external_source حتى لو أنشئ الجدول سابقًا بدونه
    cur.execute("PRAGMA table_info(documents)")
    cols = [r["name"] for r in cur.fetchall()]
    if "external_source" not in cols:
        print("   ℹ️ إضافة العمود المفقود documents.external_source ...")
        cur.execute("ALTER TABLE documents ADD COLUMN external_source TEXT")

    # إنشاء جدول chunks إن لم يكن موجودًا
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER NOT NULL,
            chunk_index INTEGER NOT NULL,
            text TEXT,
            meta_json TEXT,
            created_at TEXT,
            FOREIGN KEY(document_id) REFERENCES documents(id)
        )
        """
    )

    # فهارس
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_documents_source "
        "ON documents(external_source)"
    )
    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_chunks_doc "
        "ON chunks(document_id, chunk_index)"
    )

    conn.commit()

    cur.execute("SELECT COUNT(*) AS c FROM documents")
    docs_count = cur.fetchone()["c"]
    cur.execute("SELECT COUNT(*) AS c FROM chunks")
    chunks_count = cur.fetchone()["c"]
    conn.close()

    print(f"📊 إجمالي documents في knowledge_main.documents = {docs_count}")
    print(f"📊 إجمالي chunks في knowledge_main.chunks       = {chunks_count}")

def main():
    print("🚀 بدء الهجرة الكاملة للبيانات...")
    print("=================================")
    setup_knowledge_schema()
    print("✅ انتهاء ضبط سكيما المعرفة.")
    print("ℹ️ لا توجد هجرة محتوى حاليًا لأن قواعد legacy لا تحتوي على الجداول documents/chunks.")

if __name__ == "__main__":
    main()
