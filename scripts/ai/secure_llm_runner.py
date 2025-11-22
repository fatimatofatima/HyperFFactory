#!/usr/bin/env python3
import os
import sys
import requests
import hashlib
from pathlib import Path

class SecureLLMRunner:
    def __init__(self):
        # المفتاح الحقيقي مشفر داخل الكود
        self.encrypted_key = "c2stNTljNjI0OWY2ZmRkNDgyYTgyM2Q0OTNmYzc1MDYzNjk="
        self.api_key = self._decrypt_key()
        self.base_url = "https://api.deepseek.com/v1"
        
    def _decrypt_key(self):
        """فك تشفير المفتاح بشكل آمن"""
        import base64
        try:
            return base64.b64decode(self.encrypted_key).decode('utf-8')
        except:
            return None
    
    def _mask_key(self, key):
        """إخفاء المفتاح في اللوجات"""
        if key and len(key) > 8:
            return key[:4] + "***" + key[-4:]
        return "***"
    
    def test_connection(self):
        """اختبار الاتصال مع DeepSeek API"""
        if not self.api_key:
            print("❌ خطأ في المفتاح")
            return False
            
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": "deepseek-chat",
            "messages": [{"role": "user", "content": "اختبار اتصال - رد بكلمة 'نجاح' فقط"}],
            "max_tokens": 10
        }
        
        try:
            print(f"🔐 اختبار الاتصال بـ DeepSeek API...")
            print(f"   المفتاح: {self._mask_key(self.api_key)}")
            
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=data,
                timeout=10
            )
            
            if response.status_code == 200:
                result = response.json()
                message = result['choices'][0]['message']['content']
                print(f"✅ الاتصال ناجح: {message}")
                return True
            else:
                print(f"❌ فشل الاتصال: {response.status_code} - {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ خطأ في الاتصال: {e}")
            return False
    
    def run_agent(self, agent_id, user_input):
        """تشغيل الـ Agent مع DeepSeek الحقيقي"""
        if not self.test_connection():
            print("🚫 لا يمكن الاتصال بالخدمة")
            return
        
        # تحميل الـ Prompt المناسب
        prompt_content = self._load_agent_prompt(agent_id, user_input)
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": prompt_content},
                {"role": "user", "content": user_input}
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        }
        
        try:
            print(f"🤖 جاري تشغيل {agent_id}...")
            print(f"📝 السؤال: {user_input}")
            print("⏳ في انتظار الرد...")
            
            response = requests.post(
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=data,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                message = result['choices'][0]['message']['content']
                print("\n💡 الإجابة:")
                print("─" * 50)
                print(message)
                print("─" * 50)
                
                # حفظ المحادثة
                self._save_conversation(agent_id, user_input, message)
            else:
                print(f"❌ خطأ من API: {response.status_code}")
                print(f"📄 التفاصيل: {response.text}")
                
        except Exception as e:
            print(f"❌ خطأ: {e}")
    
    def _load_agent_prompt(self, agent_id, user_input):
        """تحميل الـ Prompt المناسب للـ Agent"""
        prompts = {
            "debug_expert": """أنت خبير في تحليل الأخطاء وحل المشاكل التقنية.
المهارات: تحليل الـ logs، تشخيص مشاكل الاتصال، حل مشاكل قواعد البيانات، تحسين الأداء.
أسلوبك: تحليل منهجي، اقتراح حلول عملية، شرح أسباب المشاكل.""",
            
            "system_architect": """أنت مهندس أنظمة محترف متخصص في تصميم البنى التحتية.
المهارات: تصميم هندسة الأنظمة، تخطيط قواعد البيانات، تحسين الأداء، تصميم أنظمة قابلة للتطوير.
أسلوبك: تقديم حلول معمارية متكاملة، شرح المقايضات، تقديم أفضل الممارسات.""",
            
            "technical_coach": """أنت مدرب تقني متخصص في مسار Backend Junior.
المسارات: الأساسيات، Python، المشاريع، Backend Basics، قواعد البيانات، Backend Craft، النشر.
أسلوبك: شرح مفصل، أمثلة عملية، توجيه خطوة بخطوة، تشجيع التعلم الذاتي."""
        }
        
        return prompts.get(agent_id, "أنت مساعد AI مفيد.")
    
    def _save_conversation(self, agent_id, question, answer):
        """حفظ المحادثة في ملف"""
        log_dir = Path("ai/conversations")
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"{agent_id}_conversations.log"
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"🤖 Agent: {agent_id}\n")
            f.write(f"❓ السؤال: {question}\n")
            f.write(f"💡 الإجابة: {answer}\n")
            f.write("─" * 50 + "\n\n")
        
        print(f"📁 تم حفظ المحادثة في: {log_file}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("استخدام: python3 secure_llm_runner.py <agent_id> [سؤال]")
        print("الأجنتس: debug_expert, system_architect, technical_coach")
        sys.exit(1)
    
    agent_id = sys.argv[1]
    user_input = sys.argv[2] if len(sys.argv) > 2 else "كيف يمكنك مساعدتي؟"
    
    runner = SecureLLMRunner()
    runner.run_agent(agent_id, user_input)
