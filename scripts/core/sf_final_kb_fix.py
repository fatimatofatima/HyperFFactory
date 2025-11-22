#!/usr/bin/env python3
import sqlite3
import hashlib
import json
from datetime import datetime

def fix_knowledge_base():
    db_path = "/var/lib/smartfrind/smart_memory.db"
    
    print("🔧 الإصلاح النهائي لـ knowledge_base...")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1) حذف الجدول إذا كان تالفاً
    cursor.execute("DROP TABLE IF EXISTS knowledge_base")
    
    # 2) إنشاء الجدول من الصفر
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
    
    # 3) نقل البيانات من ai_memory
    cursor.execute("SELECT COUNT(*) FROM ai_memory")
    ai_count = cursor.fetchone()[0]
    print(f"📊 جاري نقل {ai_count} سجل من ai_memory...")
    
    cursor.execute("""
        SELECT content, source_url, content_type, created_at 
        FROM ai_memory 
        WHERE content IS NOT NULL AND content != ''
    """)
    
    inserted = 0
    for row in cursor.fetchall():
        content, source_url, content_type, created_at = row
        
        # إنشاء hash فريد
        hash_key = hashlib.md5(content.encode()).hexdigest()
        
        # إعداد البيانات
        category = content_type or "learned"
        tags = json.dumps([category, "auto_migrated"])
        summary = content[:200] + "..." if len(content) > 200 else content
        
        try:
            cursor.execute("""
                INSERT INTO knowledge_base 
                (hash_key, raw_data, processed_data, category, tags, analysis_summary,
                 confidence_score, source_type, source_url, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                hash_key, content, content, category, tags, summary,
                0.9, "learned", source_url, created_at or datetime.now()
            ))
            inserted += 1
        except Exception as e:
            continue
    
    conn.commit()
    
    # 4) التحقق النهائي
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
    fix_knowledge_base()
