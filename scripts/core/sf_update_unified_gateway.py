#!/usr/bin/env python3
import sqlite3
from datetime import datetime
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

app = FastAPI(title="Unified Gateway - Knowledge Base")

# CORS مبسط للاختبار
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.get("/api/knowledge/search")
def search_knowledge(
    query: str = Query(..., description="Search query (FTS)"),
    category: str = Query(None, description="Filter by category"),
    limit: int = Query(10, ge=1, le=50, description="Results limit"),
):
    """بحث في knowledge_base باستخدام ai_memory_fts كفهرس نصي"""
    conn = get_connection()
    cur = conn.cursor()

    where = ["ai_memory_fts MATCH ?"]
    params = [query]

    if category:
        where.append("kb.category = ?")
        params.append(category)

    sql = f"""
        SELECT
          kb.id,
          kb.ai_id,
          kb.category,
          kb.question,
          kb.answer,
          kb.source,
          kb.created_at
        FROM knowledge_base kb
        JOIN ai_memory_fts ON ai_memory_fts.rowid = kb.ai_id
        WHERE {' AND '.join(where)}
        ORDER BY kb.created_at DESC
        LIMIT ?
    """
    params.append(limit)

    cur.execute(sql, params)
    rows = cur.fetchall()
    conn.close()

    items = [
        {
            "id": r["id"],
            "ai_id": r["ai_id"],
            "category": r["category"],
            "question": r["question"],
            "answer": r["answer"],
            "source": r["source"],
            "created_at": r["created_at"],
        }
        for r in rows
    ]

    return {
        "query": query,
        "category": category,
        "count": len(items),
        "items": items,
    }

@app.get("/api/knowledge/categories")
def list_categories():
    """إرجاع قائمة التصنيفات مع عدد العناصر في كل تصنيف"""
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT category, COUNT(*) AS count
        FROM knowledge_base
        GROUP BY category
        ORDER BY count DESC, category ASC
    """)
    rows = cur.fetchall()
    conn.close()

    return {
        "categories": [
            {"category": r["category"], "count": r["count"]}
            for r in rows
        ]
    }

@app.get("/api/knowledge/stats")
def kb_stats():
    """إحصائيات عامة عن knowledge_base"""
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("SELECT COUNT(*) FROM knowledge_base")
    total = cur.fetchone()[0]

    cur.execute("SELECT MIN(created_at), MAX(created_at) FROM knowledge_base")
    row = cur.fetchone()
    min_created, max_created = row[0], row[1]

    conn.close()

    return {
        "total_items": total,
        "min_created_at": min_created,
        "max_created_at": max_created,
        "generated_at": datetime.utcnow().isoformat() + "Z",
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8221)
