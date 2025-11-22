#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🔄 Fixing Knowledge Base Data Transfer"
echo "==========================================="
echo

SUITE_DIR="/opt/smartfriend-suite"
DB_MAIN="/var/lib/smartfrind/smart_memory.db"

cd "$SUITE_DIR"

# إنشاء سكريبت نقل البيانات يدوياً
cat > /tmp/fix_kb_transfer.py << 'PYEOF'
import sqlite3
import hashlib

def main():
    source_db = "/var/lib/smartfrind/smart_memory.db"
    
    print("🔄 نقل البيانات من ai_memory إلى knowledge_base...")
    
    try:
        conn = sqlite3.connect(source_db)
        cursor = conn.cursor()
        
        # عد السجلات في ai_memory
        cursor.execute("SELECT COUNT(*) FROM ai_memory")
        total_records = cursor.fetchone()[0]
        print(f"📊 يوجد {total_records} سجل في ai_memory")
        
        # إنشاء knowledge_base إذا لم تكن موجودة
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS knowledge_base(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          raw_data TEXT,
          category TEXT,
          analysis_summary TEXT,
          confidence_score REAL,
          source_link TEXT,
          importance_score REAL,
          tags TEXT,
          embedding BLOB,
          content_hash TEXT UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        # جلب البيانات من ai_memory
        cursor.execute("""
        SELECT question, answer, category 
        FROM ai_memory 
        WHERE question IS NOT NULL AND answer IS NOT NULL
        """)
        
        records = cursor.fetchall()
        inserted_count = 0
        skipped_count = 0
        
        for question, answer, category in records:
            # إنشاء hash فريد لتجنب التكرار
            content = f"{question}||{answer}"
            content_hash = hashlib.sha256(content.encode()).hexdigest()
            
            # التحقق إذا كان السجل موجوداً بالفعل
            cursor.execute("SELECT id FROM knowledge_base WHERE content_hash = ?", (content_hash,))
            if cursor.fetchone():
                skipped_count += 1
                continue
            
            # إدراج في knowledge_base
            cursor.execute("""
            INSERT INTO knowledge_base 
            (raw_data, category, analysis_summary, confidence_score, importance_score, tags, content_hash)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                content,
                category or "general",
                f"Auto-migrated from ai_memory",
                0.8,
                0.7,
                "auto_migrated,ai_memory",
                content_hash
            ))
            
            inserted_count += 1
        
        conn.commit()
        
        print(f"✅ تم نقل {inserted_count} سجل إلى knowledge_base")
        print(f"⏭️  تم تخطي {skipped_count} سجل (مكرر)")
        
        # عرض إحصائيات
        cursor.execute("SELECT COUNT(*) FROM knowledge_base")
        kb_count = cursor.fetchone()[0]
        cursor.execute("SELECT category, COUNT(*) FROM knowledge_base GROUP BY category")
        categories = cursor.fetchall()
        
        print(f"📈 knowledge_base الآن تحتوي على {kb_count} سجل")
        for cat, count in categories[:10]:  # عرض أول 10 تصنيفات فقط
            print(f"   📂 {cat}: {count} سجل")
        
        conn.close()
        
    except Exception as e:
        print(f"❌ خطأ في نقل البيانات: {e}")

if __name__ == "__main__":
    main()
PYEOF

# تشغيل الإصلاح
python3 /tmp/fix_kb_transfer.py

# تنظيف
rm /tmp/fix_kb_transfer.py
