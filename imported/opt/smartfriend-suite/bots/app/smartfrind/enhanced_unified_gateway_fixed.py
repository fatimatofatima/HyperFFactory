#!/usr/bin/env python3
"""
بوابة موحّدة محسّنة - الإصدار المصحح مع إصلاح الاستيراد
"""

import sys
import os
import logging
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
import uvicorn
import sqlite3
import datetime

# إضافة المسار الجذر للمشروع إلى sys.path
project_root = "/opt/smartfriend-suite"
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# إعداد التسجيل
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# محاولة استيراد نظام المعرفة
knowledge_client = None
KNOWLEDGE_AVAILABLE = False

try:
    logger.info("🔧 محاولة استيراد KnowledgeClient...")
    from sf_knowledge_client_complete import KnowledgeClient
    knowledge_client = KnowledgeClient()
    KNOWLEDGE_AVAILABLE = True
    logger.info("✅ نظام المعرفة متاح - KnowledgeClient مهيأ")
except ImportError as e:
    logger.warning(f"❌ فشل استيراد KnowledgeClient: {e}")
    KNOWLEDGE_AVAILABLE = False
except Exception as e:
    logger.error(f"❌ خطأ غير متوقع في تهيئة KnowledgeClient: {e}")
    KNOWLEDGE_AVAILABLE = False

app = FastAPI(
    title="Enhanced Unified Gateway - Fixed",
    description="بوابة موحدة محسنة مع إصلاح مشاكل الاستيراد",
    version="2.1.0"
)

# نماذج البيانات
class SearchResponse(BaseModel):
    query: str
    category: Optional[str] = None
    count: int
    items: List[Dict[str, Any]]
    source: str

class HealthResponse(BaseModel):
    status: str
    service: str
    knowledge_system: str
    timestamp: str

class LearningResponse(BaseModel):
    status: str
    source: str
    data: Optional[Dict[str, Any]] = None
    message: Optional[str] = None

@app.get("/", include_in_schema=False)
async def root():
    return {
        "message": "Enhanced Unified Gateway - Fixed",
        "knowledge_system": "available" if KNOWLEDGE_AVAILABLE else "unavailable",
        "version": "2.1.0"
    }

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """فحص صحة النظام"""
    return HealthResponse(
        status="healthy",
        service="enhanced_unified_gateway_fixed",
        knowledge_system="available" if KNOWLEDGE_AVAILABLE else "unavailable",
        timestamp=datetime.datetime.now().isoformat()
    )

@app.get("/api/v2/search", response_model=SearchResponse)
async def search_knowledge_v2(
    query: str = Query(..., description="عبارة البحث"),
    category: Optional[str] = Query(None, description="التصنيف"),
    limit: int = Query(10, description="عدد النتائج")
):
    """بحث محسّن باستخدام نظام المعرفة"""
    try:
        if KNOWLEDGE_AVAILABLE and knowledge_client:
            logger.info(f"🔍 استخدام نظام المعرفة للبحث: {query}")
            items = await knowledge_client.search(query, category, limit)
            source = "knowledge_system"
        else:
            logger.info(f"🔍 استخدام البحث الاسترجاعي: {query}")
            items = await fallback_search(query, category, limit)
            source = "fallback_db"
        
        return SearchResponse(
            query=query,
            category=category,
            count=len(items),
            items=items,
            source=source
        )
    except Exception as e:
        logger.error(f"❌ فشل البحث: {e}")
        raise HTTPException(status_code=500, detail=f"فشل البحث: {str(e)}")

async def fallback_search(query: str, category: Optional[str] = None, limit: int = 10) -> List[Dict]:
    """بحث استرجاعي مباشر من قاعدة البيانات"""
    db_path = "/var/lib/smartfrind/smart_memory.db"
    
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        sql = """
            SELECT kb.id, kb.ai_id, kb.category, kb.question, kb.answer, kb.source, kb.created_at
            FROM knowledge_base kb
            JOIN ai_memory_fts fts ON fts.rowid = kb.ai_id
            WHERE fts MATCH ?
        """
        params = [query]
        
        if category:
            sql += " AND kb.category = ?"
            params.append(category)
        
        sql += " LIMIT ?"
        params.append(limit)
        
        cursor.execute(sql, params)
        results = [dict(row) for row in cursor.fetchall()]
        
        logger.info(f"📊 البحث الاسترجاعي وجد {len(results)} نتيجة لـ '{query}'")
        return results
    except Exception as e:
        logger.error(f"❌ فشل البحث الاسترجاعي: {e}")
        return []
    finally:
        if 'conn' in locals():
            conn.close()

@app.get("/api/v2/learn/random", response_model=LearningResponse)
async def random_learning():
    """محتوى تعليمي عشوائي"""
    try:
        if KNOWLEDGE_AVAILABLE and knowledge_client:
            logger.info("🎓 استخدام نظام المعرفة للحصول على محتوى تعليمي")
            result = await knowledge_client.get_random_learning()
            return LearningResponse(
                status="success",
                source="knowledge_system",
                data=result
            )
        else:
            logger.info("🎓 استخدام النظام الاسترجاعي للتعلم")
            # محاولة الحصول على عنصر عشوائي من قاعدة البيانات
            random_item = await get_random_fallback_item()
            return LearningResponse(
                status="success" if random_item else "fallback",
                source="fallback_db",
                data={"item": random_item} if random_item else None,
                message="استخدم نظام التعلم الأساسي" if not random_item else None
            )
    except Exception as e:
        logger.error(f"❌ فشل الحصول على محتوى تعليمي: {e}")
        raise HTTPException(status_code=500, detail=f"فشل التعلم: {str(e)}")

async def get_random_fallback_item() -> Optional[Dict]:
    """الحصول على عنصر عشوائي من قاعدة البيانات"""
    db_path = "/var/lib/smartfrind/smart_memory.db"
    
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT kb.id, kb.ai_id, kb.category, kb.question, kb.answer, kb.source, kb.created_at
            FROM knowledge_base kb
            ORDER BY RANDOM()
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        if row:
            return dict(row)
        return None
    except Exception as e:
        logger.error(f"❌ فشل الحصول على عنصر عشوائي: {e}")
        return None
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    logger.info("🚀 تشغيل البوابة المحسنة المصححة على المنفذ 8223...")
    logger.info(f"📊 حالة نظام المعرفة: {'متاح' if KNOWLEDGE_AVAILABLE else 'غير متاح'}")
    uvicorn.run(app, host="0.0.0.0", port=8223, log_level="info")
