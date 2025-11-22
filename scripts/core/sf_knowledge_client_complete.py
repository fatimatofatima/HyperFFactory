#!/usr/bin/env python3
"""
عميل موحد كامل للوصول إلى نظام المعرفة
يمكن استخدامه من قبل أي مكون في SmartFrind-Core
"""
import aiohttp
import json
from typing import List, Dict, Optional, Any
import asyncio

class KnowledgeClient:
    def __init__(
        self, 
        knowledge_base_url: str = "http://localhost:8221",
        learning_url: str = "http://localhost:8222"
    ):
        self.knowledge_base_url = knowledge_base_url.rstrip("/")
        self.learning_url = learning_url.rstrip("/")
    
    async def search(
        self, 
        query: str, 
        category: Optional[str] = None, 
        limit: int = 10
    ) -> List[Dict]:
        """بحث في قاعدة المعرفة"""
        params = {"query": query, "limit": limit}
        if category:
            params["category"] = category
            
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.knowledge_base_url}/api/knowledge/search", 
                params=params
            ) as response:
                data = await response.json()
                return data.get("items", [])
    
    async def get_categories(self) -> List[Dict]:
        """الحصول على جميع التصنيفات"""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.knowledge_base_url}/api/knowledge/categories"
            ) as response:
                data = await response.json()
                return data.get("categories", [])
    
    async def get_stats(self) -> Dict:
        """الحصول على إحصائيات قاعدة المعرفة"""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.knowledge_base_url}/api/knowledge/stats"
            ) as response:
                return await response.json()
    
    async def get_random_learning(self) -> Dict:
        """الحصول على محتوى تعليمي عشوائي"""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.learning_url}/api/learn/random"
            ) as response:
                return await response.json()
    
    async def get_interactive_learning(self) -> Dict:
        """الحصول على فئات التعلم التفاعلي"""
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{self.learning_url}/api/learn/interactive"
            ) as response:
                return await response.json()

# نموذج استخدام
async def demo():
    client = KnowledgeClient()
    
    print("🧪 اختبار عميل المعرفة...")
    
    # اختبار البحث
    results = await client.search("python programming", limit=3)
    print(f"🔍 نتائج البحث: {len(results)} عنصر")
    
    # اختبار التصنيفات
    categories = await client.get_categories()
    print(f"🏷️ عدد التصنيفات: {len(categories)}")
    
    # اختبار التعلم العشوائي
    random_item = await client.get_random_learning()
    print(f"🎓 عنصر تعليمي عشوائي: {random_item.get('item', {}).get('category', 'N/A')}")

if __name__ == "__main__":
    asyncio.run(demo())
