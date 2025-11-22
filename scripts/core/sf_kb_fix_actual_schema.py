#!/usr/bin/env python3
import sqlite3
import hashlib
import json
from datetime import datetime

def fix_knowledge_base_actual():
    db_path = "/var/lib/smartfrind/smart_memory.db"
    
    print("🔧 الإصلاح النهائي لـ knowledge_base بناءً على الهيكل الفعلي...")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1) فحص الهيكل الفعلي لـ ai_memory
    cursor.execute("PRAGMA table_info(ai_memory)")
    ai_columns = {col[1]: col for col in cursor.fetchall()}
    print(f"🎯 الهيكل الفعلي لـ ai_memory: {list(ai_columns.keys())}")
    
    # 2) حذف knowledge_base إذا كانت تالفة
    cursor.execute("DROP TABLE IF EXISTS knowledge_base")
    
    # 3) إنشاء knowledge_base بالـ schema الصحيح
    cursor.execute("""
        CREATE TABLE knowledge_base(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash_key TEXT UNIQUE NOT NULL,
            raw_data TEXT NOT NULL,
            processed_data TEXT,
            category TEXT DEFAULT 'general',
            tags TEXT DEFAULT '[]',
            analysis_summary TEXT,
            confidence_score REAL DEFAULT 1.0,
            source_type TEXT DEFAULT 'crawled',
            source_url TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            access_count INTEGER DEFAULT 0,
            metadata TEXT DEFAULT '{}'
        )
    """)
    print("✅ تم إنشاء knowledge_base جديد")
    
    # 4) نقل البيانات من ai_memory باستخدام الأعمدة الفعلية
    cursor.execute("SELECT COUNT(*) FROM ai_memory")
    ai_count = cursor.fetchone()[0]
    print(f"📊 جاري نقل {ai_count} سجل من ai_memory...")
    
    # استخدام الأعمدة الفعلية من ai_memory
    # نستخدم user_input و ai_response كمحتوى
    cursor.execute("""
        SELECT user_input, ai_response, category, question, answer, created_at 
        FROM ai_memory 
        WHERE (user_input IS NOT NULL AND user_input != '') 
           OR (ai_response IS NOT NULL AND ai_response != '')
    """)
    
    inserted = 0
    skipped = 0
    
    for row in cursor.fetchall():
        user_input, ai_response, category, question, answer, created_at = row
        
        # تحديد المحتوى الأفضل للنقل
        if ai_response and ai_response.strip():
            content = ai_response
        elif user_input and user_input.strip():
            content = user_input
        elif question and answer:
            content = f"سؤال: {question}\nإجابة: {answer}"
        else:
            skipped += 1
            continue
        
        # إنشاء hash فريد
        hash_key = hashlib.md5(content.encode()).hexdigest()
        
        # التحقق من التكرار
        cursor.execute("SELECT id FROM knowledge_base WHERE hash_key = ?", (hash_key,))
        if cursor.fetchone():
            skipped += 1
            continue
        
        # إعداد البيانات
        final_category = category or "conversation"
        tags = json.dumps([final_category, "ai_learning", "conversation"])
        summary = content[:200] + "..." if len(content) > 200 else content
        
        try:
            cursor.execute("""
                INSERT INTO knowledge_base 
                (hash_key, raw_data, processed_data, category, tags, analysis_summary,
                 confidence_score, source_type, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                hash_key, content, content, final_category, tags, summary,
                0.9, "ai_conversation", created_at or datetime.now()
            ))
            inserted += 1
        except Exception as e:
            print(f"⚠️ خطأ في إدراج سجل: {e}")
            skipped += 1
            continue
    
    conn.commit()
    
    # 5) التحقق النهائي
    cursor.execute("SELECT COUNT(*) FROM knowledge_base")
    final_count = cursor.fetchone()[0]
    
    print(f"🎉 تم نقل {inserted} سجل إلى knowledge_base")
    print(f"⏭️  تم تخطي {skipped} سجل (مكرر أو فارغ)")
    print(f"📈 الإجمالي النهائي: {final_count} سجل")
    
    # عرض التصنيفات
    cursor.execute("""
        SELECT category, COUNT(*) as count 
        FROM knowledge_base 
        GROUP BY category 
        ORDER BY count DESC
        LIMIT 10
    """)
    
    print("🏷️ أهم التصنيفات:")
    for category, count in cursor.fetchall():
        print(f"   {category}: {count} سجل")
    
    conn.close()

if __name__ == "__main__":
    fix_knowledge_base_actual()
