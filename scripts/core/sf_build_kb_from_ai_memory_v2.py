#!/usr/bin/env python3
import sqlite3
import hashlib

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

def build_kb():
    print("🔧 إعادة بناء knowledge_base من ai_memory (نسخة v2)...")

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # 1) فحص أعمدة ai_memory
    cur.execute("PRAGMA table_info(ai_memory)")
    cols = [c[1] for c in cur.fetchall()]
    print("📋 أعمدة ai_memory:", cols)

    required = ["id", "question", "answer", "category", "created_at", "user_input", "ai_response", "source"]
    for c in required:
        if c not in cols:
            raise SystemExit(f"❌ العمود {c} غير موجود في ai_memory، الإيقاف.")

    # 2) إسقاط knowledge_base القديم وإنشاء واحد جديد
    print("🧨 إسقاط knowledge_base (لو موجود)...")
    cur.execute("DROP TABLE IF EXISTS knowledge_base")

    print("🧱 إنشاء knowledge_base بالـ schema الجديد...")
    cur.execute("""
        CREATE TABLE knowledge_base(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ai_id INTEGER NOT NULL,
            question TEXT,
            answer  TEXT,
            category TEXT,
            created_at TEXT,
            source TEXT,
            tags   TEXT DEFAULT '[]',
            knowledge_hash TEXT,
            UNIQUE(ai_id)
        );
    """)

    # 3) تحميل البيانات من ai_memory
    print("📊 تحميل البيانات من ai_memory...")
    cur.execute("""
        SELECT id, question, answer, category, created_at, user_input, ai_response, source
        FROM ai_memory
    """)
    rows = cur.fetchall()
    print(f"📈 تم العثور على {len(rows)} سجل في ai_memory")

    inserted = 0
    skipped  = 0

    for row in rows:
        (ai_id, q, a, cat, created_at, u_in, a_res, source) = row

        q_text = (q or "").strip()
        a_text = (a or "").strip()

        if not q_text and u_in:
            q_text = u_in.strip()
        if not a_text and a_res:
            a_text = a_res.strip()

        cat_text = (cat or "general").strip() or "general"
        src_text = (source or "ai_memory_import").strip() or "ai_memory_import"

        # حتى لو السؤال/الإجابة فاضيين، نحتفظ بالسجل (لتوافق كامل)
        base = (q_text + "||" + a_text + "||" + cat_text).strip()
        if not base:
            base = f"row:{ai_id}"

        k_hash = hashlib.sha256(base.encode("utf-8")).hexdigest()

        try:
            cur.execute("""
                INSERT OR IGNORE INTO knowledge_base
                (ai_id, question, answer, category, created_at, source, tags, knowledge_hash)
                VALUES (?, ?, ?, ?, ?, ?, '[]', ?)
            """, (ai_id, q_text, a_text, cat_text, created_at, src_text, k_hash))
            if cur.rowcount > 0:
                inserted += 1
            else:
                skipped += 1
        except sqlite3.IntegrityError:
            skipped += 1

    conn.commit()
    conn.close()

    print(f"✅ تم إدخال {inserted} سجل في knowledge_base")
    print(f"⏭️ تم تخطي {skipped} سجل (مكرر حسب ai_id أو hash)")

if __name__ == "__main__":
    build_kb()
