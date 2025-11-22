#!/usr/bin/env python3
"""
بوابة موحّدة محسّنة (Enhanced Unified Gateway)
- تعتمد على KnowledgeClient
- توفّر:
    - GET /health
    - GET /api/v2/search
    - GET /api/v2/learn/random
"""

import logging
import os
import sys
from typing import Optional, List, Dict, Any

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel

# === ضبط مسار المشروع ليشمل /opt/smartfriend-suite ===
BASE_DIR = os.path.dirname(
    os.path.dirname(
        os.path.dirname(
            os.path.abspath(__file__)
        )
    )
)
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

# محاولة استيراد KnowledgeClient من عميل المعرفة الموحد
knowledge_client = None

try:
    from sf_knowledge_client_complete import KnowledgeClient
    knowledge_client = KnowledgeClient()
    logging.info("KnowledgeClient initialized successfully in enhanced_unified_gateway")
except Exception as e:
    logging.warning("KnowledgeClient import/init failed in enhanced_unified_gateway: %s", e)
    knowledge_client = None


class SearchItem(BaseModel):
    id: Optional[int] = None
    ai_id: Optional[int] = None
    question: Optional[str] = None
    answer: Optional[str] = None
    category: Optional[str] = None
    source: Optional[str] = None
    created_at: Optional[str] = None


class SearchResponse(BaseModel):
    status: str
    query: str
    category: Optional[str] = None
    limit: int
    items: List[SearchItem]
    fallback: bool = False


class LearnItem(BaseModel):
    id: Optional[int] = None
    ai_id: Optional[int] = None
    question: Optional[str] = None
    answer: Optional[str] = None
    category: Optional[str] = None
    source: Optional[str] = None
    created_at: Optional[str] = None


class LearnResponse(BaseModel):
    status: str
    item: Optional[LearnItem] = None
    fallback: bool = False


app = FastAPI(
    title="SmartFrind Enhanced Unified Gateway",
    version="1.0.0",
    description="بوابة موحدة محسّنة متكاملة مع نظام المعرفة"
)


@app.get("/health")
async def health() -> Dict[str, Any]:
    """
    فحص صحة البوابة وتوفر KnowledgeClient
    """
    return {
        "status": "ok",
        "service": "enhanced_unified_gateway",
        "knowledge_client": "available" if knowledge_client is not None else "fallback",
    }


@app.get("/api/v2/search", response_model=SearchResponse)
async def enhanced_search(
    query: str = Query(..., min_length=1),
    category: Optional[str] = None,
    limit: int = Query(10, ge=1, le=50),
):
    """
    بحث محسن عبر نظام المعرفة
    """
    if knowledge_client is None:
        return SearchResponse(
            status="fallback",
            query=query,
            category=category,
            limit=limit,
            items=[],
            fallback=True,
        )

    try:
        raw_items = await knowledge_client.search(query=query, category=category, limit=limit)
    except Exception as e:
        logging.error("KnowledgeClient.search error: %s", e)
        raise HTTPException(status_code=502, detail="Knowledge search backend error")

    items: List[SearchItem] = []
    for r in raw_items:
        items.append(
            SearchItem(
                id=r.get("id"),
                ai_id=r.get("ai_id"),
                question=r.get("question"),
                answer=r.get("answer"),
                category=r.get("category"),
                source=r.get("source"),
                created_at=r.get("created_at"),
            )
        )

    return SearchResponse(
        status="ok",
        query=query,
        category=category,
        limit=limit,
        items=items,
        fallback=False,
    )


@app.get("/api/v2/learn/random", response_model=LearnResponse)
async def enhanced_random_learn():
    """
    استرجاع عنصر تعليمي عشوائي من بوابة التعلم
    """
    if knowledge_client is None:
        return LearnResponse(
            status="fallback",
            item=None,
            fallback=True,
        )

    try:
        raw = await knowledge_client.random_learning_item()
    except Exception as e:
        logging.error("KnowledgeClient.random_learning_item error: %s", e)
        raise HTTPException(status_code=502, detail="Learning backend error")

    if not raw:
        return LearnResponse(status="ok", item=None, fallback=False)

    item = LearnItem(
        id=raw.get("id"),
        ai_id=raw.get("ai_id"),
        question=raw.get("question"),
        answer=raw.get("answer"),
        category=raw.get("category"),
        source=raw.get("source"),
        created_at=raw.get("created_at"),
    )

    return LearnResponse(
        status="ok",
        item=item,
        fallback=False,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8223)
