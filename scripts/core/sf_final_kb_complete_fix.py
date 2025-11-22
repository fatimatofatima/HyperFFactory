#!/usr/bin/env python3
import sqlite3
import hashlib
import json
from datetime import datetime

def fix_knowledge_base_completely():
    db_path = "/var/lib/smartfrind/smart_memory.db"
    
    print("🔧 الإصلاح الشامل لـ knowledge_base...")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1) فحص هيكل ai_memory أولاً
    cursor.execute("PRAGMA table_info(ai_memory)")
    ai_columns = {col[1]: col for col in cursor.fetchall()}
    print(f"📋 أعمدة ai_memory: {list(ai_columns.keys())}")
    
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
    
    # 4) نقل البيانات من ai_memory مع التعامل مع الأعمدة المختلفة
    cursor.execute("SELECT COUNT(*) FROM ai_memory")
    ai_count = cursor.fetchone()[0]
    print(f"📊 جاري نقل {ai_count} سجل من ai_memory...")
    
    # تحديد الأعمدة المتاحة
    if 'content' in ai_columns:
        content_col = 'content'
    elif 'raw_data' in ai_columns:
        content_col = 'raw_data'
    else:
        print("❌ لا توجد أعمدة محتوى مناسبة في ai_memory")
        return
    
    if 'source_url' in ai_columns:
        source_col = 'source_url'
    elif 'source' in ai_columns:
        source_col = 'source'
    else:
        source_col = 'NULL'
    
    if 'content_type' in ai_columns:
        type_col = 'content_type'
    else:
        type_col = "'learned'"
    
    # بناء query ديناميكي
    query = f"""
        SELECT {content_col}, {source_col}, {type_col}, created_at 
        FROM ai_memory 
        WHERE {content_col} IS NOT NULL AND {content_col} != ''
    """
    
    cursor.execute(query)
    inserted = 0
    
    for row in cursor.fetchall():
        if source_col == 'NULL':
            content, _, content_type, created_at = row
            source_url = None
        else:
            content, source_url, content_type, created_at = row
        
        if not content:
            continue
            
        # إنشاء hash فريد
        hash_key = hashlib.md5(content.encode()).hexdigest()
        
        # إعداد البيانات
        category = content_type or "learned"
        tags = json.dumps([category, "auto_migrated"])
        summary = content[:200] + "..." if len(content) > 200 else content
        
        try:
            cursor.execute("""
                INSERT OR IGNORE INTO knowledge_base 
                (hash_key, raw_data, processed_data, category, tags, analysis_summary,
                 confidence_score, source_type, source_url, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                hash_key, content, content, category, tags, summary,
                0.9, "learned", source_url, created_at or datetime.now()
            ))
            if cursor.rowcount > 0:
                inserted += 1
        except Exception as e:
            print(f"⚠️ خطأ في إدراج سجل: {e}")
            continue
    
    conn.commit()
    
    # 5) التحقق النهائي
    cursor.execute("SELECT COUNT(*) FROM knowledge_base")
    final_count = cursor.fetchone()[0]
    
    print(f"🎉 تم نقل {inserted} سجل إلى knowledge_base")
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
    fix_knowledge_base_completely()
