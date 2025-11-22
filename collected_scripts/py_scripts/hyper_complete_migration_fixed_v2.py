#!/usr/bin/env python3
import os
import sqlite3
import json
import hashlib
from datetime import datetime

ROOT = "/root/HyperFFactory"
META_DB = os.path.join(ROOT, "meta", "hyper_meta.db")
IDENTITY_DB = "/opt/hyper-factory/var/db/identity/identity.db"
MEMORY_DB = "/opt/hyper-factory/var/db/memory/memory_core_2025.db"
KNOWLEDGE_DB = "/opt/hyper-factory/var/db/knowledge/knowledge_main.db"

NOW = datetime.utcnow().isoformat(timespec="seconds") + "Z"

def setup_knowledge_schema():
    """إعداد سكيما قاعدة المعرفة"""
    conn = sqlite3.connect(KNOWLEDGE_DB)
    cursor = conn.cursor()
    
    # إنشاء جدول documents إذا لم يكن موجوداً
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            content_type TEXT,
            external_source TEXT,
            source_metadata TEXT,
            content_hash TEXT,
            embedding_model TEXT,
            chunk_index INTEGER,
            metadata TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    ''')
    
    # إنشاء جدول chunks إذا لم يكن موجوداً
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER,
            chunk_index INTEGER,
            content TEXT,
            content_hash TEXT,
            embedding BLOB,
            embedding_model TEXT,
            token_count INTEGER,
            metadata TEXT,
            created_at TEXT,
            FOREIGN KEY (document_id) REFERENCES documents(id)
        )
    ''')
    
    # إنشاء الفهارس
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_documents_source ON documents(external_source)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_documents_content_hash ON documents(content_hash)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_chunks_document_id ON chunks(document_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_chunks_content_hash ON chunks(content_hash)')
    
    conn.commit()
    conn.close()
    print("   ✅ سكيما قاعدة المعرفة جاهزة")

def calculate_content_hash(content):
    """حساب الهاش للمحتوى"""
    return hashlib.md5(content.encode('utf-8')).hexdigest()

def migrate_legacy_knowledge():
    """هجرة البيانات من قواعد البيانات القديمة"""
    print("\n🔍 البحث عن بيانات المعرفة في قواعد البيانات القديمة...")
    
    conn_meta = sqlite3.connect(META_DB)
    conn_knowledge = sqlite3.connect(KNOWLEDGE_DB)
    
    cursor_meta = conn_meta.cursor()
    cursor_knowledge = conn_knowledge.cursor()
    
    # البحث عن قواعد البيانات التي تحتوي على جداول المعرفة
    cursor_meta.execute('''
        SELECT id, file_path, file_name, file_role 
        FROM db_files 
        WHERE file_role IN ('knowledge', 'smartfriend_legacy', 'other')
        AND tables_list LIKE '%knowledge_base%'
        OR tables_list LIKE '%documents%'
        OR tables_list LIKE '%chunks%'
    ''')
    
    knowledge_dbs = cursor_meta.fetchall()
    total_documents = 0
    total_chunks = 0
    
    print(f"   📂 وجدت {len(knowledge_dbs)} قاعدة بيانات محتملة للمعرفة")
    
    for db_id, file_path, file_name, file_role in knowledge_dbs:
        if not os.path.exists(file_path):
            print(f"   ⚠️ ملف مفقود: {file_name}")
            continue
            
        try:
            conn_legacy = sqlite3.connect(file_path)
            cursor_legacy = conn_legacy.cursor()
            
            # فحص الجداول المتاحة
            cursor_legacy.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = [row[0] for row in cursor_legacy.fetchall()]
            
            documents_migrated = 0
            chunks_migrated = 0
            
            # هجرة knowledge_base إذا كان موجوداً
            if 'knowledge_base' in tables:
                cursor_legacy.execute('SELECT * FROM knowledge_base')
                columns = [desc[0] for desc in cursor_legacy.description]
                
                for row in cursor_legacy.fetchall():
                    row_dict = dict(zip(columns, row))
                    
                    # تحويل البيانات إلى تنسيق جديد
                    title = row_dict.get('title', '') or row_dict.get('page_title', '') or f"Document from {file_name}"
                    content = row_dict.get('raw_data', '') or row_dict.get('analysis_summary', '')
                    
                    if content:
                        content_hash = calculate_content_hash(content)
                        
                        # التحقق من عدم وجود مكرر
                        cursor_knowledge.execute(
                            'SELECT id FROM documents WHERE content_hash = ?', 
                            (content_hash,)
                        )
                        if cursor_knowledge.fetchone() is None:
                            cursor_knowledge.execute('''
                                INSERT INTO documents 
                                (title, content, content_type, external_source, source_metadata, 
                                 content_hash, metadata, created_at, updated_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ''', (
                                title,
                                content,
                                'legacy_knowledge',
                                file_name,
                                json.dumps({
                                    'legacy_db': file_name,
                                    'legacy_table': 'knowledge_base',
                                    'original_id': row_dict.get('id'),
                                    'category': row_dict.get('category'),
                                    'tags': row_dict.get('tags')
                                }),
                                content_hash,
                                json.dumps({
                                    'confidence_score': row_dict.get('confidence_score'),
                                    'importance_score': row_dict.get('importance_score'),
                                    'date_learned': row_dict.get('date_learned'),
                                    'source_link': row_dict.get('source_link')
                                }),
                                NOW,
                                NOW
                            ))
                            documents_migrated += 1
            
            # هجرة conscious_memory إذا كان موجوداً
            if 'conscious_memory' in tables:
                cursor_legacy.execute('SELECT * FROM conscious_memory WHERE is_active = 1')
                columns = [desc[0] for desc in cursor_legacy.description]
                
                for row in cursor_legacy.fetchall():
                    row_dict = dict(zip(columns, row))
                    
                    content = row_dict.get('content', '')
                    if content:
                        content_hash = calculate_content_hash(content)
                        
                        cursor_knowledge.execute(
                            'SELECT id FROM documents WHERE content_hash = ?', 
                            (content_hash,)
                        )
                        if cursor_knowledge.fetchone() is None:
                            cursor_knowledge.execute('''
                                INSERT INTO documents 
                                (title, content, content_type, external_source, source_metadata, 
                                 content_hash, metadata, created_at, updated_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ''', (
                                f"Memory: {row_dict.get('memory_type', 'unknown')}",
                                content,
                                'conscious_memory',
                                file_name,
                                json.dumps({
                                    'legacy_db': file_name,
                                    'legacy_table': 'conscious_memory',
                                    'original_id': row_dict.get('id'),
                                    'user_id': row_dict.get('user_id'),
                                    'memory_type': row_dict.get('memory_type')
                                }),
                                content_hash,
                                json.dumps({
                                    'importance': row_dict.get('importance'),
                                    'confidence': row_dict.get('confidence'),
                                    'sentiment': row_dict.get('sentiment'),
                                    'urgency': row_dict.get('urgency'),
                                    'category': row_dict.get('category'),
                                    'access_count': row_dict.get('access_count'),
                                    'created_at': row_dict.get('created_at')
                                }),
                                NOW,
                                NOW
                            ))
                            documents_migrated += 1
            
            conn_legacy.close()
            
            if documents_migrated > 0:
                print(f"   ✅ {file_name}: {documents_migrated} مستند")
                total_documents += documents_migrated
                
        except Exception as e:
            print(f"   ❌ خطأ في {file_name}: {e}")
    
    conn_knowledge.commit()
    
    # إحصاءات نهائية
    cursor_knowledge.execute('SELECT COUNT(*) FROM documents')
    final_count = cursor_knowledge.fetchone()[0]
    
    conn_knowledge.close()
    conn_meta.close()
    
    print(f"\n📊 إجمالي المستندات المهاجرة: {total_documents}")
    print(f"📊 إجمالي المستندات في قاعدة المعرفة: {final_count}")

def main():
    print("🚀 بدء الهجرة الكاملة للبيانات...")
    print("=================================")
    
    # إعداد السكيما
    setup_knowledge_schema()
    
    # هجرة البيانات القديمة
    migrate_legacy_knowledge()
    
    print("\n✅ اكتملت الهجرة!")

if __name__ == "__main__":
    main()
