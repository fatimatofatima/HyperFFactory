#!/usr/bin/env python3
import sqlite3
import os

MEMORY_DB = "/opt/hyper-factory/var/db/memory/memory_core_2025.db"
KNOWLEDGE_DB = "/opt/hyper-factory/var/db/knowledge/knowledge_main.db"

def open_db(path: str) -> sqlite3.Connection:
    if not os.path.exists(path):
        raise SystemExit(f"DB not found: {path}")
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn

def check_memory_events():
    conn = open_db(MEMORY_DB)
    cur = conn.cursor()
    print("=== legacy events in memory_core_2025 ===")
    cur.execute("""
      SELECT 
        COUNT(*) AS total_events,
        COUNT(DISTINCT correlation_id) AS unique_ids
      FROM events
      WHERE event_type LIKE 'legacy.%';
    """)
    row = cur.fetchone()
    print(f" total_events        = {row['total_events']}")
    print(f" unique_correlation  = {row['unique_ids']}")
    print()
    print(" top event_type counts:")
    cur.execute("""
      SELECT event_type, COUNT(*) AS c
      FROM events
      WHERE event_type LIKE 'legacy.%'
      GROUP BY event_type
      ORDER BY c DESC, event_type ASC;
    """)
    for r in cur.fetchall():
        print(f"  {r['event_type']}: {r['c']}")
    conn.close()
    print()

def check_knowledge_docs():
    conn = open_db(KNOWLEDGE_DB)
    cur = conn.cursor()
    print("=== knowledge_main documents ===")
    cur.execute("""
      SELECT COUNT(*) AS docs,
             COUNT(DISTINCT content_hash) AS distinct_hashes
      FROM documents;
    """)
    row = cur.fetchone()
    print(f" docs           = {row['docs']}")
    print(f" distinct_hashes= {row['distinct_hashes']}")
    print()
    print(" docs by source_type:")
    cur.execute("""
      SELECT source_type, COUNT(*) AS c
      FROM documents
      GROUP BY source_type
      ORDER BY c DESC;
    """)
    for r in cur.fetchall():
        print(f"  {r['source_type']}: {r['c']}")
    conn.close()
    print()

def main():
    print("🚦 HyperFFactory legacy migration check")
    print("=======================================")
    check_memory_events()
    check_knowledge_docs()
    print("✅ done")

if __name__ == "__main__":
    main()
