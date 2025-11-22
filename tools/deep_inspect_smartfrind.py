#!/usr/bin/env python3
import sqlite3
import json
import os

def deep_inspect_smartfrind():
    db_path = "/root/HyperFFactory/all_legacy_dbs/smartfrind.db"
    
    if not os.path.exists(db_path):
        print("❌ smartfrind.db غير موجود")
        return
    
    print("🔍 الفحص العميق لـ smartfrind.db")
    print("=================================")
    
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # الحصول على جميع الجداول
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    
    print(f"📊 عدد الجداول: {len(tables)}")
    print(f"📋 أسماء الجداول: {tables}")
    
    # فحص كل جدول بالتفصيل
    for table in tables:
        print(f"\n🎯 جدول: {table}")
        print("-" * 50)
        
        try:
            # عدد السجلات
            cursor.execute(f"SELECT COUNT(*) as count FROM \"{table}\"")
            count = cursor.fetchone()['count']
            print(f"   عدد السجلات: {count}")
            
            # هيكل الجدول
            cursor.execute(f"PRAGMA table_info(\"{table}\")")
            columns = cursor.fetchall()
            print(f"   الأعمدة ({len(columns)}):")
            for col in columns:
                print(f"     - {col['name']} ({col['type']})")
            
            # عينات من البيانات
            if count > 0:
                cursor.execute(f"SELECT * FROM \"{table}\" LIMIT 3")
                sample_rows = cursor.fetchall()
                
                print(f"   عينات البيانات:")
                for i, row in enumerate(sample_rows):
                    row_dict = dict(row)
                    # تقليل حجم العرض
                    display_dict = {}
                    for key, value in row_dict.items():
                        if value and len(str(value)) > 100:
                            display_dict[key] = str(value)[:100] + "..."
                        else:
                            display_dict[key] = value
                    print(f"     {i+1}. {display_dict}")
            
        except Exception as e:
            print(f"   ❌ خطأ في فحص الجدول: {e}")
    
    conn.close()
    
    print(f"\n✅ اكتمل الفحص العميق لـ smartfrind.db")

if __name__ == "__main__":
    deep_inspect_smartfrind()
