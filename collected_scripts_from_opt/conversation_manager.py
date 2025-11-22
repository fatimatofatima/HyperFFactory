# MyDeepseek/conversation_manager.py
import json
import os
from datetime import datetime

class ConversationManager:
    def __init__(self):
        self.data_dir = "data"
        self.ensure_data_dir()
    
    def ensure_data_dir(self):
        """التأكد من وجود مجلد البيانات"""
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
    
    def save_user_conversation(self, user_id, user_name, message, response):
        """حفظ محادثة المستخدم"""
        timestamp = datetime.now().isoformat()
        conversation = {
            "user_id": user_id,
            "user_name": user_name,
            "user_message": message,
            "ai_response": response,
            "timestamp": timestamp
        }
        
        # حفظ في ملف المستخدم
        user_file = f"{self.data_dir}/user_{user_id}.json"
        user_data = self.load_user_data(user_id)
        user_data["conversations"].append(conversation)
        user_data["last_active"] = timestamp
        
        with open(user_file, 'w', encoding='utf-8') as f:
            json.dump(user_data, f, ensure_ascii=False, indent=2)
    
    def load_user_data(self, user_id):
        """تحميل بيانات المستخدم"""
        user_file = f"{self.data_dir}/user_{user_id}.json"
        if os.path.exists(user_file):
            with open(user_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        else:
            return {
                "user_id": user_id,
                "conversations": [],
                "created_at": datetime.now().isoformat(),
                "last_active": datetime.now().isoformat()
            }
    
    def get_user_stats(self, user_id):
        """الحصول على إحصائيات المستخدم"""
        user_data = self.load_user_data(user_id)
        return {
            "total_messages": len(user_data["conversations"]),
            "first_seen": user_data["created_at"],
            "last_active": user_data["last_active"]
        }

# إنشاء مدير المحادثات
conv_manager = ConversationManager()
