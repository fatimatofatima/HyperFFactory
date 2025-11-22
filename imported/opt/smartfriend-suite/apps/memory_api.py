from fastapi import FastAPI
from pathlib import Path
import os
import sqlite3
import time
from typing import Dict, Any

UNIFIED_DB = os.getenv("SF_UNIFIED_DB", "/opt/smartfriend-suite/var/db/smartfriend_unified.db")
MEMORY_DB = os.getenv("SF_MEMORY_DB", "/opt/smartfriend-suite/var/db/memory.db")

app = FastAPI(
    title="SmartFriend Memory API",
    version="1.0.0",
    description="Thin memory/knowledge facade for SmartFriend Suite."
)

def db_info(path: str) -> Dict[str, Any]:
    p = Path(path)
    info: Dict[str, Any] = {
        "path": str(p),
        "exists": p.exists(),
        "size_bytes": p.stat().st_size if p.exists() else 0,
    }
    if p.exists():
        try:
            conn = sqlite3.connect(str(p))
            cur = conn.cursor()
            # نحاول قراءة عدد الجداول فقط كمؤشر حياة
            cur.execute("SELECT count(*) FROM sqlite_master WHERE type='table';")
            info["tables"] = cur.fetchone()[0]
            conn.close()
        except Exception as e:
            info["error"] = str(e)
    return info

@app.get("/health")
async def health():
    return {
        "service": "sf-memory",
        "status": "ok",
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

@app.get("/stats")
async def stats():
    return {
        "unified_db": db_info(UNIFIED_DB),
        "memory_db": db_info(MEMORY_DB),
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
