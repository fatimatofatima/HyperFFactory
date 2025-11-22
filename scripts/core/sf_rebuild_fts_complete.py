#!/usr/bin/env python3
"""
إعادة بناء كاملة لـ FTS للتأكد من التزامن
"""
import sqlite3

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

def rebuild_fts_completely():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        print("🔄 إعادة بناء FTS بالكامل...")
        
        # 1. حذف FTS الحالية
        cursor.execute("DROP TABLE IF EXISTS ai_memory_fts")
        
        # 2. إنشاء FTS جديدة
        cursor.execute("""
            CREATE VIRTUAL TABLE ai_memory_fts USING fts5(
                question,
                answer, 
                category,
                content='ai_memory',
                content_rowid='id'
            )
        """)
        
        # 3. إعادة تعبئة البيانات
        cursor.execute("""
            INSERT INTO ai_memory_fts(rowid, question, answer, category)
            SELECT id, question, answer, category FROM ai_memory
        """)
        
        # 4. إعادة إنشاء التريجرز
        cursor.execute("DROP TRIGGER IF EXISTS ai_memory_ai")
        cursor.execute("DROP TRIGGER IF EXISTS ai_memory_au")
        cursor.execute("DROP TRIGGER IF EXISTS ai_memory_ad")
        
        cursor.execute("""
            CREATE TRIGGER ai_memory_ai AFTER INSERT ON ai_memory BEGIN
                INSERT INTO ai_memory_fts(rowid, question, answer, category)
                VALUES (new.id, new.question, new.answer, new.category);
            END
        """)
        
        cursor.execute("""
            CREATE TRIGGER ai_memory_au AFTER UPDATE ON ai_memory BEGIN
                UPDATE ai_memory_fts
                SET question = new.question, answer = new.answer, category = new.category
                WHERE rowid = new.id;
            END
        """)
        
        cursor.execute("""
            CREATE TRIGGER ai_memory_ad AFTER DELETE ON ai_memory BEGIN
                DELETE FROM ai_memory_fts WHERE rowid = old.id;
            END
        """)
        
        conn.commit()
        
        # التحقق
        cursor.execute("SELECT COUNT(*) FROM ai_memory_fts")
        fts_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM ai_memory")
        ai_count = cursor.fetchone()[0]
        
        print(f"✅ إعادة البناء اكتملت: ai_memory={ai_count}, ai_memory_fts={fts_count}")
        
        return ai_count == fts_count
        
    except Exception as e:
        print(f"❌ خطأ في إعادة البناء: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

if __name__ == "__main__":
    rebuild_fts_completely()
