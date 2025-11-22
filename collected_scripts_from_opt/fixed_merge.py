import sqlite3
import glob
import os

ROOT = "/opt/smartfriend-suite"
MASTER = f"{ROOT}/data/smartfriend_unified.db"
SHARDS = glob.glob(f"{ROOT}/data/spider_shards/worker_*.db")

def safe_merge():
    master = sqlite3.connect(MASTER)
    master.execute("PRAGMA busy_timeout=30000")
    
    # التأكد من الجداول الأساسية
    master.executescript("""
        CREATE TABLE IF NOT EXISTS bronze_pages(
            url TEXT PRIMARY KEY, fetched_at TEXT, status_code INTEGER,
            content_hash TEXT, title TEXT, html TEXT, src_seed TEXT, depth INTEGER
        );
        CREATE TABLE IF NOT EXISTS silver_docs(
            url TEXT PRIMARY KEY, promoted_at TEXT, title TEXT,
            content_hash TEXT, text TEXT
        );
        CREATE TABLE IF NOT EXISTS knowledge_base(
            url TEXT PRIMARY KEY, title TEXT, content TEXT
        );
    """)
    
    total_bronze = 0
    total_silver = 0
    
    for shard_path in SHARDS:
        if not os.path.exists(shard_path):
            continue
            
        try:
            shard = sqlite3.connect(f"file:{shard_path}?mode=ro", uri=True)
            
            # دمج bronze_pages بشكل آمن
            try:
                cursor = shard.execute("SELECT * FROM bronze_pages")
                for row in cursor:
                    try:
                        master.execute("""
                            INSERT OR IGNORE INTO bronze_pages 
                            VALUES (?,?,?,?,?,?,?,?)
                        """, row)
                        if master.total_changes > 0:
                            total_bronze += 1
                    except Exception as e:
                        print(f"تخطي سطر bronze: {e}")
                        continue
            except Exception as e:
                print(f"خطأ في bronze_pages: {e}")
            
            # دمج silver_docs بشكل آمن
            try:
                cursor = shard.execute("SELECT * FROM silver_docs")
                for row in cursor:
                    try:
                        master.execute("""
                            INSERT OR IGNORE INTO silver_docs 
                            VALUES (?,?,?,?,?)
                        """, row)
                        if master.total_changes > 0:
                            total_silver += 1
                    except Exception as e:
                        print(f"تخطي سطر silver: {e}")
                        continue
            except Exception as e:
                print(f"خطأ في silver_docs: {e}")
            
            shard.close()
        except Exception as e:
            print(f"خطأ في معالجة الشظية {shard_path}: {e}")
            continue
    
    # ترقية إلى knowledge_base
    try:
        master.execute("""
            INSERT OR IGNORE INTO knowledge_base(url, title, content)
            SELECT url, title, text FROM silver_docs 
            WHERE url NOT IN (SELECT url FROM knowledge_base)
        """)
    except Exception as e:
        print(f"خطأ في ترقية knowledge_base: {e}")
    
    master.commit()
    master.close()
    
    return f"✅ تم دمج {total_bronze} برونز و {total_silver} فضة بنجاح"

if __name__ == "__main__":
    result = safe_merge()
    print(result)
