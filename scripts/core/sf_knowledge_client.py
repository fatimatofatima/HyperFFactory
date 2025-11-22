#!/usr/bin/env python3
"""
عميل موحد للوصول إلى نظام المعرفة (Knowledge / Learning Gateways)
يمكن استدعاؤه من أي مكوّن داخل SmartFriend Suite.
"""

from typing import List, Dict, Optional, Any
import aiohttp


class KnowledgeClient:
    def __init__(
        self,
        knowledge_base_url: str = "http://localhost:8221",
        learning_url: str = "http://localhost:8222",
    ) -> None:
        self.knowledge_base_url = knowledge_base_url.rstrip("/")
        self.learning_url = learning_url.rstrip("/")

    async def _get_json(
        self,
        base_url: str,
        path: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{base_url}{path}", params=params, timeout=30) as resp:
                resp.raise_for_status()
                return await resp.json()

    async def search(
        self,
        query: str,
        category: Optional[str] = None,
        limit: int = 10,
    ) -> List[Dict[str, Any]]:
        """
        بحث عام في قاعدة المعرفة باستخدام FTS.
        """
        params: Dict[str, Any] = {"query": query, "limit": limit}
        if category:
            params["category"] = category

        data = await self._get_json(
            self.knowledge_base_url,
            "/api/knowledge/search",
            params=params,
        )
        return data.get("items", [])

    async def categories(self) -> List[Dict[str, Any]]:
        """
        الحصول على قائمة الفئات + عدد العناصر في كل فئة.
        """
        data = await self._get_json(
            self.knowledge_base_url,
            "/api/knowledge/categories",
        )
        return data.get("categories", [])

    async def stats(self) -> Dict[str, Any]:
        """
        إحصائيات عامة عن قاعدة المعرفة.
        """
        return await self._get_json(
            self.knowledge_base_url,
            "/api/knowledge/stats",
        )

    async def random_learning_item(self) -> Optional[Dict[str, Any]]:
        """
        الحصول على عنصر تعليمي عشوائي من بوابة التعلم.
        """
        data = await self._get_json(
            self.learning_url,
            "/api/learn/random",
        )
        return data.get("item")

    async def interactive_overview(self) -> Dict[str, Any]:
        """
        الحصول على نظرة تفاعلية: توزيع الفئات + فئة مقترحة للتعلّم.
        """
        return await self._get_json(
            self.learning_url,
            "/api/learn/interactive",
        )


# نسخة جاهزة للاستخدام من أي موديول
knowledge_client = KnowledgeClient()


if __name__ == "__main__":
    # اختبار يدوي بسيط عند التشغيل المباشر
    import asyncio

    async def _demo() -> None:
        client = KnowledgeClient()
        print("🔎 search('python') -> أول 2 نتيجة:")
        items = await client.search("python", limit=2)
        for i, item in enumerate(items, start=1):
            print(f"{i}. [{item.get('category')}] {item.get('question')[:80]}")

        print("\n📊 stats:")
        print(await client.stats())

        print("\n🎓 random_learning_item:")
        print(await client.random_learning_item())

    asyncio.run(_demo())
