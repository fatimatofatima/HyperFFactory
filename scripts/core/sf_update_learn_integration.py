#!/usr/bin/env python3
"""
تحديث learn.py لاستخدام نظام التعلم الجديد
"""
import os

LEARN_PATH = "/opt/smartfriend-suite/bots/app/smartfrind/learn.py"

def analyze_learn_module():
    """تحليل وحدة التعلم الحالية"""
    if not os.path.exists(LEARN_PATH):
        print("❌ learn.py غير موجود في المسار المحدد")
        return None
    
    with open(LEARN_PATH, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("📊 تحليل learn.py الحالي:")
    print(f"   - الطول: {len(content)} حرف")
    print(f"   - يستخدم ai_memory: {'ai_memory' in content}")
    print(f"   - يستخدم SELECT: {'SELECT' in content}")
    print(f"   - يحتوي على دوال تعلم: {'def learn' in content or 'def get_learning' in content}")
    
    return content

def create_enhanced_learn_module():
    """إنشاء وحدة تعلم محسنة"""
    
    enhanced_learn = '''#!/usr/bin/env python3
"""
Enhanced Learn Module - Integrated with Knowledge Learning System
وحدة تعلم محسنة تستخدم نظام المعرفة المركزي
"""

import logging
from typing import Dict, List, Optional, Any

try:
    from sf_knowledge_client_complete import KnowledgeClient
    KNOWLEDGE_SYSTEM_AVAILABLE = True
except ImportError:
    KNOWLEDGE_SYSTEM_AVAILABLE = False
    logging.warning("KnowledgeClient not available for learn module")

class EnhancedLearnSystem:
    """نظام تعلم محسن يستخدم بوابة المعرفة"""
    
    def __init__(self):
        if KNOWLEDGE_SYSTEM_AVAILABLE:
            self.knowledge_client = KnowledgeClient()
        else:
            self.knowledge_client = None
            logging.warning("Learning system running in fallback mode")
    
    async def get_random_learning(self) -> Dict[str, Any]:
        """الحصول على محتوى تعليمي عشوائي"""
        if self.knowledge_client:
            try:
                result = await self.knowledge_client.get_random_learning()
                return {
                    "status": "success",
                    "source": "knowledge_system",
                    "data": result
                }
            except Exception as e:
                logging.error(f"Knowledge system learning failed: {e}")
        
        # وضع الاسترجاع
        return {
            "status": "fallback",
            "source": "legacy",
            "data": {
                "message": "استخدم النظام التعليمي الأساسي",
                "suggestion": "تفعيل اتصال نظام المعرفة"
            }
        }
    
    async def get_interactive_learning(self, category: Optional[str] = None) -> Dict[str, Any]:
        """الحصول على تعلم تفاعلي"""
        if self.knowledge_client:
            try:
                result = await self.knowledge_client.get_interactive_learning()
                return {
                    "status": "success",
                    "source": "knowledge_system",
                    "data": result
                }
            except Exception as e:
                logging.error(f"Interactive learning failed: {e}")
        
        return {
            "status": "fallback",
            "source": "legacy",
            "data": {
                "message": "النظام التفاعلي غير متاح",
                "category": category
            }
        }
    
    async def search_learning_content(self, query: str, category: Optional[str] = None) -> Dict[str, Any]:
        """بحث في المحتوى التعليمي"""
        if self.knowledge_client:
            try:
                results = await self.knowledge_client.search(query, category, limit=5)
                return {
                    "status": "success",
                    "source": "knowledge_system",
                    "query": query,
                    "category": category,
                    "results": results
                }
            except Exception as e:
                logging.error(f"Learning search failed: {e}")
        
        return {
            "status": "fallback",
            "source": "legacy",
            "query": query,
            "category": category,
            "results": []
        }

# نموذج استخدام
learn_system = EnhancedLearnSystem()

async def demo_enhanced_learn():
    """عرض تجريبي للنظام المحسن"""
    print("🧠 تجربة نظام التعلم المحسن...")
    
    # محتوى عشوائي
    random_content = await learn_system.get_random_learning()
    print(f"🎓 عشوائي: {random_content['status']} - {random_content['source']}")
    
    # بحث تعليمي
    search_content = await learn_system.search_learning_content("python")
    print(f"🔍 بحث: {search_content['status']} - {len(search_content['results'])} نتيجة")

if __name__ == "__main__":
    import asyncio
    asyncio.run(demo_enhanced_learn())
'''

    enhanced_path = "/opt/smartfriend-suite/bots/app/smartfrind/enhanced_learn.py"
    with open(enhanced_path, 'w', encoding='utf-8') as f:
        f.write(enhanced_learn)
    
    print(f"✅ تم إنشاء وحدة التعلم المحسنة في: {enhanced_path}")
    return enhanced_path

if __name__ == "__main__":
    current_content = analyze_learn_module()
    if current_content:
        create_enhanced_learn_module()
