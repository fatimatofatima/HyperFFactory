#!/usr/bin/env python3
import sqlite3
import random
from datetime import datetime
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

app = FastAPI(title="AI Learning Gateway - Knowledge Base")

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

@app.get("/api/learn/random")
def get_random_learning():
    """الحصول على سؤال/إجابة عشوائيين من knowledge_base"""
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT id, ai_id, question, answer, category, source, created_at
        FROM knowledge_base
        WHERE question IS NOT NULL AND question != ''
        ORDER BY RANDOM()
        LIMIT 1
    """)
    row = cur.fetchone()
    conn.close()

    if not row:
        return {"status": "empty", "message": "knowledge_base is empty"}

    return {
        "status": "ok",
        "item": {
            "id": row["id"],
            "ai_id": row["ai_id"],
            "question": row["question"],
            "answer": row["answer"],
            "category": row["category"],
            "source": row["source"],
            "created_at": row["created_at"],
        },
        "served_at": datetime.utcnow().isoformat() + "Z",
    }

@app.get("/api/learn/interactive")
def interactive_learning():
    """واجهة تعلم تفاعلي مبسطة"""
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT category, COUNT(*) AS count
        FROM knowledge_base
        GROUP BY category
        ORDER BY count DESC
    """)
    rows = cur.fetchall()
    conn.close()

    categories = [
        {"category": r["category"], "count": r["count"]}
        for r in rows
    ]

    suggested = None
    if categories:
        top = categories[:5]
        suggested = random.choice(top)["category"]

    return {
        "status": "ok",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "categories": categories,
        "suggested_next_category": suggested,
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8222)
