#!/usr/bin/env python3
import sqlite3

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

def main():
    print("🔧 إعادة بناء ai_memory_fts + triggers...")

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # 1) حذف أي FTS قديم مرتبط بـ ai_memory_fts
    print("🧨 إسقاط جداول FTS القديمة (لو موجودة)...")
    drop_names = [
        "ai_memory_fts",
        "ai_memory_fts_data",
        "ai_memory_fts_idx",
        "ai_memory_fts_docsize",
        "ai_memory_fts_config",
        "ai_memory_fts_content",
    ]
    for name in drop_names:
        cur.execute(f"DROP TABLE IF EXISTS {name}")

    # 2) حذف أي triggers قديمة مرتبطة بـ ai_memory
    print("🧨 إسقاط التريجرز القديمة...")
    for trg in ["ai_memory_ai", "ai_memory_au", "ai_memory_ad"]:
        cur.execute(f"DROP TRIGGER IF EXISTS {trg}")

    # 3) إنشاء FTS جديد
    print("🧱 إنشاء ai_memory_fts جديد...")
    cur.execute("""
        CREATE VIRTUAL TABLE ai_memory_fts USING fts5(
            question,
            answer,
            category,
            content='ai_memory',
            content_rowid='id'
        );
    """)

    # 4) تحميل البيانات من ai_memory وبناء الفهرس
    print("📊 تحميل البيانات من ai_memory...")
    cur.execute("""
        SELECT id, question, answer, category, user_input, ai_response
        FROM ai_memory
    """)
    rows = cur.fetchall()
    print(f"📈 عدد السجلات في ai_memory: {len(rows)}")

    inserted = 0
    for row in rows:
        rid, q, a, cat, u_in, a_res = row
        q_text = (q or "").strip()
        a_text = (a or "").strip()
        if not q_text and u_in:
            q_text = u_in.strip()
        if not a_text and a_res:
            a_text = a_res.strip()
        cat_text = (cat or "general").strip() or "general"

        cur.execute(
            "INSERT INTO ai_memory_fts(rowid, question, answer, category) VALUES (?,?,?,?)",
            (rid, q_text, a_text, cat_text),
        )
        inserted += 1

    print(f"✅ تم إدخال {inserted} سجل في ai_memory_fts")

    # 5) إنشاء التريجرز الجديدة
    print("⚙️ إنشاء التريجرز الجديدة...")

    cur.execute("""
        CREATE TRIGGER ai_memory_ai AFTER INSERT ON ai_memory BEGIN
            INSERT INTO ai_memory_fts(rowid, question, answer, category)
            VALUES (
                new.id,
                COALESCE(NULLIF(new.question,''), new.user_input),
                COALESCE(NULLIF(new.answer,''),  new.ai_response),
                COALESCE(NULLIF(new.category,''), 'general')
            );
        END;
    """)

    cur.execute("""
        CREATE TRIGGER ai_memory_au AFTER UPDATE ON ai_memory BEGIN
            UPDATE ai_memory_fts
            SET
                question = COALESCE(NULLIF(new.question,''), new.user_input),
                answer   = COALESCE(NULLIF(new.answer,''),  new.ai_response),
                category = COALESCE(NULLIF(new.category,''), 'general')
            WHERE rowid = new.id;
        END;
    """)

    cur.execute("""
        CREATE TRIGGER ai_memory_ad AFTER DELETE ON ai_memory BEGIN
            DELETE FROM ai_memory_fts WHERE rowid = old.id;
        END;
    """)

    conn.commit()
    conn.close()
    print("🎯 تم إصلاح ai_memory_fts والتريجرز بنجاح.")

if __name__ == "__main__":
    main()
