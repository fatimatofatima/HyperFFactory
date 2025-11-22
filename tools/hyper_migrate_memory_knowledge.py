#!/usr/bin/env python3
import os
import sqlite3
import json
from datetime import datetime

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
MEMORY_DB = "/opt/hyper-factory/var/db/memory/memory_core_2025.db"

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

def migrate_conversations():
    """هجرة المحادثات من القواعد القديمة"""
    print("💬 بدء هجرة المحادثات...")
    
    meta_conn = sqlite3.connect(META_DB)
    memory_conn = sqlite3.connect(MEMORY_DB)
    
    meta_cursor = meta_conn.cursor()
    memory_cursor = memory_conn.cursor()
    
    # البحث عن قواعد البيانات التي تحتوي على محادثات
    meta_cursor.execute("""
        SELECT file_path, file_name, file_size_mb 
        FROM db_files 
        WHERE file_role IN ('memory_core', 'knowledge_hub')
        ORDER BY file_size_mb DESC
        LIMIT 5
    """)
    
    memory_files = meta_cursor.fetchall()
    total_migrated = 0
    
    for file_path, file_name, file_size_mb in memory_files:
        full_path = os.path.join(ROOT, file_path)
        
        if not os.path.exists(full_path):
            continue
            
        print(f"📂 معالجة: {file_name} ({file_size_mb} MB)")
        
        try:
            legacy_conn = sqlite3.connect(full_path)
            legacy_cursor = legacy_conn.cursor()
            
            # البحث عن جداول المحادثات
            legacy_cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in legacy_cursor.fetchall()]
            
            conversation_tables = [t for t in tables if 'conversation' in t.lower() or 'chat' in t.lower()]
            
            for table in conversation_tables:
                try:
                    legacy_cursor.execute(f"SELECT COUNT(*) FROM \"{table}\"")
                    count = legacy_cursor.fetchone()[0]
                    
                    print(f"   💬 جدول {table}: {count} محادثة")
                    
                    # هجرة عينة من المحادثات
                    legacy_cursor.execute(f"SELECT * FROM \"{table}\" LIMIT 10")
                    conversations = legacy_cursor.fetchall()
                    columns = [desc[0] for desc in legacy_cursor.description]
                    
                    for i, conv in enumerate(conversations):
                        conv_dict = dict(zip(columns, conv))
                        
                        # إدراج كحدث في الذاكرة
                        memory_cursor.execute('''
                            INSERT INTO events 
                            (timestamp, event_type, payload_json, created_at, external_id, external_source)
                            VALUES (?, ?, ?, ?, ?, ?)
                        ''', (
                            NOW,
                            "legacy_conversation",
                            json.dumps(conv_dict),
                            NOW,
                            f"{file_name}:{table}:{i}",
                            file_name
                        ))
                        total_migrated += 1
                        
                except Exception as e:
                    print(f"     ⚠️ خطأ في معالجة {table}: {e}")
            
            legacy_conn.close()
            memory_conn.commit()
            
        except Exception as e:
            print(f"   ❌ خطأ في معالجة {file_name}: {e}")
    
    print(f"✅ تم هجرة {total_migrated} محادثة")
    meta_conn.close()
    memory_conn.close()

if __name__ == "__main__":
    migrate_conversations()
