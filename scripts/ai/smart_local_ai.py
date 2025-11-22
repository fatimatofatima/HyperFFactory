#!/usr/bin/env python3
import sys
import random
from pathlib import Path

class SmartLocalAI:
    def __init__(self):
        self.knowledge_base = self._load_knowledge()
    
    def _load_knowledge(self):
        """قاعدة معرفة مبنية على الخبرة"""
        return {
            "debug_expert": {
                "database_connection": [
                    "تحقق من: 1) connection string 2) كلمة المرور 3) حالة خدمة PostgreSQL",
                    "أخطاء Connection Refused: تأكد أن PostgreSQL شغال → systemctl status postgresql",
                    "تحقق من الـ firewall: sudo ufw status | grep 5432",
                    "جرب: psql -h localhost -U username -d database_name للاختبار المباشر"
                ],
                "general": [
                    "ابدأ بفحص الـ logs: journalctl -u service_name --no-pager",
                    "تحقق من الـ disk space: df -h",
                    "افحص الـ memory: free -h",
                    "اختبر الـ network: ping hostname"
                ]
            },
            "system_architect": {
                "logging_system": [
                    "تصميم نظام لوجات: ELK Stack (Elasticsearch للبحث, Logstash للمعالجة, Kibana للعرض)",
                    "لـ 1000 طلب/ثانية: استخدم Kafka كـ buffer + multiple Logstash instances",
                    "هندسة مقترحة: App → Kafka → Logstash → Elasticsearch → Kibana",
                    "تحسين الأداء: استخدم bulk requests + compression + proper indexing"
                ],
                "microservices": [
                    "هندسة Microservices: API Gateway + Service Mesh + Centralized Logging",
                    "استخدم Docker + Kubernetes للـ orchestration",
                    "طبق Circuit Breaker pattern للـ resilience",
                    "استخدم Redis للـ caching و Kafka للـ async communication"
                ]
            },
            "technical_coach": {
                "backend_roadmap": [
                    "مسار Backend Junior: 1) Python أساسيات 2) مشاريع تطبيقية 3) قواعد بيانات 4) APIs 5) نشر",
                    "ابدأ بـ: Python syntax → functions → OOP → file handling → error handling",
                    "ثم: Flask/FastAPI → REST APIs → SQL → PostgreSQL → Redis → Docker",
                    "مشاريع مقترحة: TODO app → Weather API → Blog system → E-commerce backend"
                ],
                "database_learning": [
                    "تعلم قواعد البيانات: 1) SQL basics 2) Normalization 3) Indexes 4) Transactions 5) ORM",
                    "ابدأ بـ: SELECT, INSERT, UPDATE, DELETE → ثم JOINs → ثم subqueries",
                    "طبق على: PostgreSQL (مفتوح المصدر وقوي)",
                    "استخدم SQLAlchemy كـ ORM لربط Python مع PostgreSQL"
                ]
            }
        }
    
    def get_smart_response(self, agent_id, user_input):
        """إجابة ذكية بناءً على المدخلات"""
        user_input_lower = user_input.lower()
        
        if agent_id == "debug_expert":
            if any(word in user_input_lower for word in ['postgresql', 'قاعدة', 'database', 'connection', 'اتصال']):
                responses = self.knowledge_base["debug_expert"]["database_connection"]
            else:
                responses = self.knowledge_base["debug_expert"]["general"]
        
        elif agent_id == "system_architect":
            if any(word in user_input_lower for word in ['لوجات', 'تحليلات', 'logging', '1000', 'طلب']):
                responses = self.knowledge_base["system_architect"]["logging_system"]
            else:
                responses = self.knowledge_base["system_architect"]["microservices"]
        
        elif agent_id == "technical_coach":
            if any(word in user_input_lower for word in ['backend', 'برمجة', 'تعلم', 'مسار']):
                responses = self.knowledge_base["technical_coach"]["backend_roadmap"]
            else:
                responses = self.knowledge_base["technical_coach"]["database_learning"]
        
        else:
            return "🤖 Agent غير معروف"
        
        return random.choice(responses)
    
    def run_agent(self, agent_id, user_input):
        """تشغيل الـ Agent المحلي"""
        agent_names = {
            "debug_expert": "🛠️ Debug Expert",
            "system_architect": "🏗️ System Architect", 
            "technical_coach": "👨‍🏫 Technical Coach"
        }
        
        print(f"{agent_names.get(agent_id, '🤖 AI')}")
        print("─" * 50)
        print(f"📝 السؤال: {user_input}")
        print("💡 الإجابة الذكية:")
        print("")
        
        response = self.get_smart_response(agent_id, user_input)
        print(response)
        print("")
        print("─" * 50)
        print("🎯 تم إنشاء هذه الإجابة باستخدام قاعدة معرفة مبنية على أفضل الممارسات")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("استخدام: python3 smart_local_ai.py <agent_id> [سؤال]")
        print("الأجنتس: debug_expert, system_architect, technical_coach")
        sys.exit(1)
    
    agent_id = sys.argv[1]
    user_input = sys.argv[2] if len(sys.argv) > 2 else "كيف يمكنك مساعدتي؟"
    
    ai = SmartLocalAI()
    ai.run_agent(agent_id, user_input)
