#!/usr/bin/env python3
"""
إصلاح نهائي لـ FTS Triggers - إزالة الإشارات إلى user_input
"""
import sqlite3
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

def fix_fts_triggers():
    """إصلاح التريجرز لاستخدام الحقول الصحيحة فقط"""
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    try:
        # 1. حذف التريجرز القديمة
        logger.info("🗑️ حذف التريجرز القديمة...")
        cursor.execute("DROP TRIGGER IF EXISTS ai_memory_ai")
        cursor.execute("DROP TRIGGER IF EXISTS ai_memory_au") 
        cursor.execute("DROP TRIGGER IF EXISTS ai_memory_ad")
        
        # 2. إنشاء التريجرز الجديدة بدون user_input
        logger.info("🔧 إنشاء التريجرز الجديدة...")
        
        # trigger للإدراج
        cursor.execute("""
            CREATE TRIGGER ai_memory_ai AFTER INSERT ON ai_memory BEGIN
                INSERT INTO ai_memory_fts(rowid, question, answer, category)
                VALUES (new.id, new.question, new.answer, new.category);
            END
        """)
        
        # trigger للتحديث
        cursor.execute("""
            CREATE TRIGGER ai_memory_au AFTER UPDATE ON ai_memory BEGIN
                UPDATE ai_memory_fts
                SET question = new.question, answer = new.answer, category = new.category
                WHERE rowid = new.id;
            END
        """)
        
        # trigger للحذف
        cursor.execute("""
            CREATE TRIGGER ai_memory_ad AFTER DELETE ON ai_memory BEGIN
                DELETE FROM ai_memory_fts WHERE rowid = old.id;
            END
        """)
        
        conn.commit()
        logger.info("✅ تم إصلاح التريجرز بنجاح!")
        
        # 3. التحقق من التريجرز الجديدة
        cursor.execute("""
            SELECT name, sql FROM sqlite_master 
            WHERE type = 'trigger' AND name LIKE 'ai_memory%'
        """)
        
        triggers = cursor.fetchall()
        logger.info("📋 التريجرز الحالية:")
        for name, sql in triggers:
            logger.info(f"  {name}: {sql[:100]}...")
            
        return True
        
    except Exception as e:
        logger.error(f"❌ خطأ في إصلاح التريجرز: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

if __name__ == "__main__":
    fix_fts_triggers()
