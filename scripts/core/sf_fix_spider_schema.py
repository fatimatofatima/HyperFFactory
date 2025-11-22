#!/usr/bin/env python3
import sqlite3

def fix_spider_schema():
    db_path = "/var/lib/smartfrind/smart_memory.db"
    
    print("🔧 إصلاح schema الـ Spider ليتوافق مع ai_memory الفعلي...")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # فحص الأعمدة الحالية في ai_memory
    cursor.execute("PRAGMA table_info(ai_memory)")
    columns = cursor.fetchall()
    print("📋 أعمدة ai_memory الحالية:")
    for col in columns:
        print(f"   {col[1]} ({col[2]})")
    
    # إضافة الأعمدة المفقودة إذا لزم
    required_columns = ['source', 'source_url', 'content_type']
    existing_columns = [col[1] for col in columns]
    
    for col in required_columns:
        if col not in existing_columns:
            print(f"➕ إضافة عمود '{col}'...")
            cursor.execute(f"ALTER TABLE ai_memory ADD COLUMN {col} TEXT")
    
    conn.commit()
    conn.close()
    print("✅ اكتمل إصلاح schema الـ Spider")

if __name__ == "__main__":
    fix_spider_schema()
