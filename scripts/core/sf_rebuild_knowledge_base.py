#!/usr/bin/env python3
import sqlite3
import json
from datetime import datetime

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

def main():
    print("🔧 إعادة بناء knowledge_base من ai_memory...")

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # 1) فحص أعمدة ai_memory
    cur.execute("PRAGMA table_info(ai_memory)")
    cols = [c[1] for c in cur.fetchall()]
    print("📋 أعمدة ai_memory:", cols)

    required = ["question", "answer", "category", "created_at", "content_hash"]
    for c in required:
        if c not in cols:
            raise SystemExit(f"❌ العمود {c} غير موجود في ai_memory، الإيقاف.")

    # 2) حذف knowledge_base وإنشاؤه من الصفر
    print("🧨 إسقاط knowledge_base (لو موجود)...")
    cur.execute("DROP TABLE IF EXISTS knowledge_base")

    print("🧱 إنشاء knowledge_base بالـ schema الجديد...")
    cur.execute("""
        CREATE TABLE knowledge_base(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash_key TEXT UNIQUE NOT NULL,
            question TEXT NOT NULL,
            answer TEXT NOT NULL,
            category TEXT,
            created_at TEXT,
            source TEXT,
            tags TEXT DEFAULT '[]',
            analysis_summary TEXT,
            confidence_score REAL DEFAULT 1.0
        );
    """)

    # 3) قراءة البيانات من ai_memory
    print("📊 تحميل البيانات من ai_memory...")
    cur.execute("""
        SELECT question, answer, category, created_at, content_hash
        FROM ai_memory
    """)
    rows = cur.fetchall()
    total = len(rows)
    print(f"📈 تم العثور على {total} سجل في ai_memory")

    inserted = 0
    skipped = 0

    for q, a, cat, created_at, content_hash in rows:
        if not content_hash:
            # fallback بسيط لو مفيش content_hash
            content_hash = f"{hash((q or '') + '|' + (a or '')):x}"

        # tags مبدئياً فاضية – ممكن تستخدم category لاحقاً لو حبيت
        tags = json.dumps([])

        try:
            cur.execute("""
                INSERT INTO knowledge_base(
                    hash_key, question, answer, category,
                    created_at, source, tags, analysis_summary, confidence_score
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                content_hash,
                q or "",
                a or "",
                cat or "general",
                created_at or datetime.utcnow().isoformat(),
                "ai_memory_import",
                tags,
                None,
                1.0
            ))
            inserted += 1
        except sqlite3.IntegrityError:
            # hash_key مكرر
            skipped += 1
            continue

    conn.commit()
    print(f"✅ تم إدخال {inserted} سجل في knowledge_base")
    print(f"⏭️  تم تخطي {skipped} سجل (hash مكرر)")
    print("🎯 إعادة البناء اكتملت بنجاح")

if __name__ == "__main__":
    main()
