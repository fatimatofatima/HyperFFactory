#!/usr/bin/env python3
"""
تحديث unified_gateway.py لاستخدام نظام المعرفة الجديد
"""
import os
import re

# المسار إلى الملف الأصلي
GATEWAY_PATH = "/opt/smartfriend-suite/bots/app/smartfrind/unified_gateway.py"
BACKUP_PATH = f"{GATEWAY_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

def update_unified_gateway():
    # نسخة احتياطية أولاً
    os.system(f"cp {GATEWAY_PATH} {GATEWAY_PATH}.backup.$(date +%Y%m%d_%H%M%S)")
    
    with open(GATEWAY_PATH, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. إضافة استيراد KnowledgeClient
    import_pattern = r'(import.*?\\n)(\\n)'
    new_import = "from sf_knowledge_client_complete import KnowledgeClient\\n"
    
    if "KnowledgeClient" not in content:
        content = re.sub(import_pattern, r'\\1' + new_import + r'\\2', content, count=1)
    
    # 2. البحث عن دوال البحث واستبدالها
    old_search_pattern = r'def.*search.*?:\n.*?cursor\\.execute\\(.*?SELECT.*?FROM.*?ai_memory'
    
    # 3. إضافة معرفة العميل في __init__ أو كمتغير عالمي
    init_pattern = r'(def __init__\\(.*?:\\))(.*?)(def|class)'
    
    if "self.knowledge_client" not in content:
        new_init = r'\\1\\2        self.knowledge_client = KnowledgeClient()\\n\\n    \\3'
        content = re.sub(init_pattern, new_init, content, flags=re.DOTALL)
    
    # 4. استبدال استعلامات البحث المباشرة
    # البحث عن نمط: cursor.execute("SELECT ... FROM ai_memory ...")
    direct_query_pattern = r'cursor\\.execute\\(["\\']SELECT.*?FROM.*?ai_memory.*?["\\']'
    
    if re.search(direct_query_pattern, content):
        print("🔍 وجد استعلامات مباشرة لـ ai_memory تحتاج للتحديث")
        # سنقوم بإنشاء ملف معدل بدلاً من التعديل المباشر
        return create_enhanced_gateway()
    else:
        print("✅ لا توجد استعلامات مباشرة واضحة - إنشاء بوابة محسنة")
        return create_enhanced_gateway()

def create_enhanced_gateway():
    """إنشاء نسخة محسنة من unified_gateway تستخدم نظام المعرفة"""
    
    enhanced_content = '''#!/usr/bin/env python3
"""
Unified Gateway - Integrated with Knowledge System
إصدار محسن يستخدم نظام المعرفة المركزي
"""

import sqlite3
import logging
from typing import List, Dict, Optional, Any
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware

# استيراد عميل المعرفة
try:
    from sf_knowledge_client_complete import KnowledgeClient
    KNOWLEDGE_SYSTEM_AVAILABLE = True
except ImportError:
    KNOWLEDGE_SYSTEM_AVAILABLE = False
    logging.warning("KnowledgeClient not available, falling back to direct DB access")

app = FastAPI(title="SmartFriend Unified Gateway - Knowledge Integrated")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_PATH = "/var/lib/smartfrind/smart_memory.db"

class EnhancedUnifiedGateway:
    def __init__(self):
        self.db_path = DB_PATH
        if KNOWLEDGE_SYSTEM_AVAILABLE:
            self.knowledge_client = KnowledgeClient()
        else:
            self.knowledge_client = None
    
    def get_connection(self):
        """الحصول على اتصال قاعدة البيانات (للتوافق مع الكود القديم)"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    async def search_knowledge(self, query: str, category: Optional[str] = None, limit: int = 10) -> List[Dict]:
        """بحث في المعرفة باستخدام النظام الجديد أو القديم"""
        if self.knowledge_client:
            # استخدام نظام المعرفة الجديد
            try:
                results = await self.knowledge_client.search(query, category, limit)
                return results
            except Exception as e:
                logging.warning(f"Knowledge system search failed, falling back to DB: {e}")
        
        # Fallback إلى البحث المباشر في DB
        return self._legacy_search(query, category, limit)
    
    def _legacy_search(self, query: str, category: Optional[str] = None, limit: int = 10) -> List[Dict]:
        """البحث القديم في قاعدة البيانات (للتوافق)"""
        conn = self.get_connection()
        try:
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
            return results
        finally:
            conn.close()
    
    async def get_learning_content(self) -> Dict:
        """الحصول على محتوى تعليمي"""
        if self.knowledge_client:
            try:
                return await self.knowledge_client.get_random_learning()
            except Exception as e:
                logging.warning(f"Knowledge learning failed, falling back: {e}")
        
        # Fallback implementation
        return {"status": "fallback", "message": "Learning system unavailable"}

# تهيئة البوابة
gateway = EnhancedUnifiedGateway()

# Endpoints
@app.get("/api/v2/search")
async def search_v2(
    query: str = Query(..., description="Search query"),
    category: Optional[str] = Query(None, description="Filter by category"),
    limit: int = Query(10, description="Number of results")
):
    """بحث محسن باستخدام نظام المعرفة"""
    try:
        results = await gateway.search_knowledge(query, category, limit)
        return {
            "query": query,
            "category": category,
            "count": len(results),
            "items": results,
            "source": "knowledge_system" if gateway.knowledge_client else "legacy_db"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {e}")

@app.get("/api/v2/learn/random")
async def random_learning_v2():
    """محتوى تعليمي عشوائي محسن"""
    try:
        content = await gateway.get_learning_content()
        return content
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Learning content unavailable: {e}")

@app.get("/health")
async def health_check():
    """فحص صحة النظام"""
    return {
        "status": "healthy",
        "knowledge_system": KNOWLEDGE_SYSTEM_AVAILABLE,
        "gateway": "enhanced_unified_gateway"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8223)
'''

    # حفظ البوابة المحسنة
    enhanced_path = "/opt/smartfriend-suite/bots/app/smartfrind/enhanced_unified_gateway.py"
    with open(enhanced_path, 'w', encoding='utf-8') as f:
        f.write(enhanced_content)
    
    print(f"✅ تم إنشاء البوابة المحسنة في: {enhanced_path}")
    return enhanced_path

if __name__ == "__main__":
    update_unified_gateway()
