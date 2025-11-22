#!/usr/bin/env python3
import os
import sqlite3
from datetime import datetime

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")

def deep_scan_all_databases():
    """مسح عميق لجميع قواعد البيانات والجداول"""
    print("🔍 مسح عميق لجميع قواعد البيانات...")
    
    conn_meta = sqlite3.connect(META_DB)
    cursor_meta = conn_meta.cursor()
    
    cursor_meta.execute('''
        SELECT file_path, file_name, file_size_mb
        FROM db_files 
        WHERE file_path LIKE '%.db' 
        ORDER BY file_size_mb DESC
    ''')
    
    all_dbs = cursor_meta.fetchall()
    
    for db_path, file_name, file_size in all_dbs:
        if not os.path.exists(db_path):
            continue
            
        try:
            conn_db = sqlite3.connect(db_path)
            cursor_db = conn_db.cursor()
            
            # الحصول على جميع الجداول
            cursor_db.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in cursor_db.fetchall()]
            
            if tables:
                print(f"\n📁 {file_name} ({file_size} MB) - {len(tables)} جدول:")
                
                for table in tables:
                    try:
                        cursor_db.execute(f"SELECT COUNT(*) FROM \"{table}\"")
                        count = cursor_db.fetchone()[0]
                        
                        if count > 0:
                            # الحصول على أسماء الأعمدة
                            cursor_db.execute(f"PRAGMA table_info(\"{table}\")")
                            columns = [row[1] for row in cursor_db.fetchall()]
                            
                            print(f"   📊 {table}: {count} سجل")
                            print(f"      الأعمدة: {columns}")
                            
                            # عرض عينة من البيانات إذا كان الجدول صغير
                            if count <= 5:
                                cursor_db.execute(f"SELECT * FROM \"{table}\" LIMIT 2")
                                sample_data = cursor_db.fetchall()
                                for i, row in enumerate(sample_data):
                                    print(f"      عينة {i+1}: {row}")
                            
                    except Exception as e:
                        print(f"   ⚠️ خطأ في جدول {table}: {e}")
            
            conn_db.close()
            
        except Exception as e:
            print(f"❌ خطأ في {file_name}: {e}")
    
    conn_meta.close()

if __name__ == "__main__":
    deep_scan_all_databases()
