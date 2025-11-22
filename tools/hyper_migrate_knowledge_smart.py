#!/usr/bin/env python3
import os
import sqlite3
import json
import hashlib
from datetime import datetime

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
KNOWLEDGE_DB = "/opt/hyper-factory/var/db/knowledge/knowledge_main.db"

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

def calculate_content_hash(content):
    """حساب الهاش للمحتوى"""
    if not content:
        return hashlib.md5(b"").hexdigest()
    return hashlib.md5(content.encode('utf-8')).hexdigest()

def scan_all_databases_for_content():
    """مسح شامل لجميع قواعد البيانات للعثور على محتوى"""
    print("🔍 مسح شامل لجميع قواعد البيانات للعثور على المحتوى...")
    
    conn_meta = sqlite3.connect(META_DB)
    cursor_meta = conn_meta.cursor()
    
    # الحصول على جميع قواعد البيانات
    cursor_meta.execute('''
        SELECT id, file_path, file_name, file_size_mb, file_role, tables_list
        FROM db_files 
        WHERE file_path LIKE '%.db' 
        ORDER BY file_size_mb DESC
    ''')
    
    all_dbs = cursor_meta.fetchall()
    print(f"   📂 عدد قواعد البيانات المكتشفة: {len(all_dbs)}")
    
    content_found = []
    
    for db_id, file_path, file_name, file_size, file_role, tables_list in all_dbs:
        if not os.path.exists(file_path):
            continue
            
        try:
            conn_db = sqlite3.connect(file_path)
            cursor_db = conn_db.cursor()
            
            # الحصول على جميع الجداول
            cursor_db.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in cursor_db.fetchall()]
            
            # البحث عن جداول قد تحتوي على محتوى
            content_tables = []
            for table in tables:
                table_lower = table.lower()
                if any(keyword in table_lower for keyword in [
                    'knowledge', 'memory', 'content', 'data', 'document', 
                    'chunk', 'text', 'message', 'chat', 'conversation',
                    'log', 'note', 'memo', 'thought'
                ]):
                    content_tables.append(table)
            
            if content_tables:
                print(f"   📋 {file_name} ({file_size} MB): {len(content_tables)} جدول محتوى")
                
                # فحص كل جدول محتوى
                for table in content_tables:
                    try:
                        cursor_db.execute(f"SELECT COUNT(*) FROM \"{table}\"")
                        row_count = cursor_db.fetchone()[0]
                        
                        if row_count > 0:
                            # الحصول على عينة من البيانات
                            cursor_db.execute(f"SELECT * FROM \"{table}\" LIMIT 1")
                            columns = [desc[0] for desc in cursor_db.description]
                            
                            print(f"     📊 {table}: {row_count} سجل")
                            content_found.append({
                                'db_file': file_name,
                                'db_path': file_path,
                                'table': table,
                                'row_count': row_count,
                                'columns': columns
                            })
                            
                    except Exception as e:
                        print(f"     ⚠️ خطأ في فحص {table}: {e}")
            
            conn_db.close()
            
        except Exception as e:
            print(f"   ❌ خطأ في فتح {file_name}: {e}")
    
    conn_meta.close()
    return content_found

def migrate_content_from_table(db_path, table_name, file_name):
    """هجرة المحتوى من جدول معين"""
    print(f"   🚚 هجرة المحتوى من {file_name}.{table_name}")
    
    conn_source = sqlite3.connect(db_path)
    conn_dest = sqlite3.connect(KNOWLEDGE_DB)
    
    cursor_source = conn_source.cursor()
    cursor_dest = conn_dest.cursor()
    
    migrated_count = 0
    
    try:
        # الحصول على بيانات الجدول
        cursor_source.execute(f"SELECT * FROM \"{table_name}\"")
        columns = [desc[0] for desc in cursor_source.description]
        
        for row in cursor_source.fetchall():
            row_dict = dict(zip(columns, row))
            
            # محاولة استخراج المحتوى بناءً على أسماء الأعمدة الشائعة
            content = None
            title = f"محتوى من {file_name}.{table_name}"
            
            # البحث عن أعمدة المحتوى المحتملة
            content_fields = ['content', 'text', 'message', 'data', 'raw_data', 
                            'summary', 'analysis', 'description', 'value']
            title_fields = ['title', 'name', 'subject', 'topic', 'label']
            
            for field in content_fields:
                if field in row_dict and row_dict[field]:
                    content = str(row_dict[field])
                    break
            
            for field in title_fields:
                if field in row_dict and row_dict[field]:
                    title = str(row_dict[field])
                    break
            
            if not content:
                # إذا لم نجد محتوى نصي، نحاول تحويل الصف بأكمله إلى JSON
                content = json.dumps(row_dict, ensure_ascii=False, default=str)
                title = f"بيانات من {file_name}.{table_name}"
            
            if content:
                content_hash = calculate_content_hash(content)
                
                # التحقق من عدم وجود مكرر
                cursor_dest.execute(
                    'SELECT id FROM documents WHERE content_hash = ?', 
                    (content_hash,)
                )
                if cursor_dest.fetchone() is None:
                    cursor_dest.execute('''
                        INSERT INTO documents 
                        (external_id, source_type, source_ref, title, content, 
                         external_source, source_metadata, content_hash, 
                         meta_json, created_at, indexed_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        f"{file_name}_{table_name}_{row_dict.get('id', migrated_count)}",
                        'legacy_migration',
                        file_name,
                        title[:500],  # truncate long titles
                        content,
                        file_name,
                        json.dumps({
                            'legacy_db': file_name,
                            'legacy_table': table_name,
                            'original_columns': columns,
                            'row_id': row_dict.get('id')
                        }),
                        content_hash,
                        json.dumps({
                            'migration_time': NOW,
                            'row_data': {k: v for k, v in row_dict.items() if k not in content_fields + title_fields}
                        }),
                        NOW,
                        NOW
                    ))
                    migrated_count += 1
        
        conn_dest.commit()
        print(f"     ✅ تم هجرة {migrated_count} مستند")
        
    except Exception as e:
        print(f"     ❌ خطأ في الهجرة: {e}")
    
    finally:
        conn_source.close()
        conn_dest.close()
    
    return migrated_count

def main():
    print("🚀 بدء الهجرة الذكية للمعرفة...")
    print("=================================")
    
    # المسح الشامل للعثور على المحتوى
    content_sources = scan_all_databases_for_content()
    
    if not content_sources:
        print("❌ لم يتم العثور على أي محتوى في قواعد البيانات!")
        return
    
    print(f"\n🎯 وجدت {len(content_sources)} مصدر محتوى")
    
    total_migrated = 0
    
    # هجرة المحتوى من كل مصدر
    for source in content_sources:
        migrated = migrate_content_from_table(
            source['db_path'], 
            source['table'], 
            source['db_file']
        )
        total_migrated += migrated
    
    # الإحصاءات النهائية
    conn_knowledge = sqlite3.connect(KNOWLEDGE_DB)
    cursor_knowledge = conn_knowledge.cursor()
    
    cursor_knowledge.execute('SELECT COUNT(*) FROM documents')
    final_count = cursor_knowledge.fetchone()[0]
    
    cursor_knowledge.execute('SELECT source_type, COUNT(*) FROM documents GROUP BY source_type')
    stats = cursor_knowledge.fetchall()
    
    conn_knowledge.close()
    
    print(f"\n📊 إحصائيات الهجرة:")
    print(f"   📄 المستندات المهجرة في هذه الجلسة: {total_migrated}")
    print(f"   📚 إجمالي المستندات في قاعدة المعرفة: {final_count}")
    
    for source_type, count in stats:
        print(f"   📂 {source_type}: {count} مستند")
    
    print("\n✅ اكتملت الهجرة الذكية للمعرفة!")

if __name__ == "__main__":
    main()
