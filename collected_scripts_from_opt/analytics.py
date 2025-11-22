# MyDeepseek/analytics.py
import json
import os
from datetime import datetime, timedelta
import logging

class Analytics:
    def __init__(self):
        self.data_dir = "data"
        self.analytics_file = f"{self.data_dir}/analytics.json"
        self.ensure_data_dir()
        self.logger = logging.getLogger(__name__)
    
    def ensure_data_dir(self):
        """التأكد من وجود مجلد البيانات"""
        if not os.path.exists(self.data_dir):
            os.makedirs(self.data_dir)
    
    def log_interaction(self, user_id, user_name, message_type="message"):
        """تسجيل تفاعل المستخدم"""
        analytics_data = self.load_analytics()
        
        # تحديث الإحصائيات العامة
        analytics_data["total_interactions"] = analytics_data.get("total_interactions", 0) + 1
        analytics_data["last_activity"] = datetime.now().isoformat()
        
        # تحديث إحصائيات المستخدم
        if user_id not in analytics_data["users"]:
            analytics_data["users"][user_id] = {
                "user_name": user_name,
                "first_seen": datetime.now().isoformat(),
                "last_seen": datetime.now().isoformat(),
                "message_count": 0,
                "command_count": 0
            }
        
        user_data = analytics_data["users"][user_id]
        user_data["last_seen"] = datetime.now().isoformat()
        
        if message_type == "message":
            user_data["message_count"] = user_data.get("message_count", 0) + 1
        elif message_type == "command":
            user_data["command_count"] = user_data.get("command_count", 0) + 1
        
        # حفظ البيانات
        self.save_analytics(analytics_data)
    
    def load_analytics(self):
        """تحميل بيانات التحليلات"""
        if os.path.exists(self.analytics_file):
            try:
                with open(self.analytics_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                pass
        
        # بيانات افتراضية
        return {
            "total_interactions": 0,
            "total_users": 0,
            "users": {},
            "last_activity": datetime.now().isoformat(),
            "bot_start_time": datetime.now().isoformat()
        }
    
    def save_analytics(self, analytics_data):
        """حفظ بيانات التحليلات"""
        try:
            with open(self.analytics_file, 'w', encoding='utf-8') as f:
                json.dump(analytics_data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            self.logger.error(f"Error saving analytics: {e}")
    
    def get_dashboard_stats(self):
        """الحصول على إحصائيات اللوحة الرئيسية"""
        analytics_data = self.load_analytics()
        
        # حساب المستخدمين النشطين (آخر 7 أيام)
        active_users = 0
        week_ago = datetime.now() - timedelta(days=7)
        
        for user_id, user_data in analytics_data.get("users", {}).items():
            last_seen = datetime.fromisoformat(user_data["last_seen"])
            if last_seen > week_ago:
                active_users += 1
        
        return {
            "total_interactions": analytics_data.get("total_interactions", 0),
            "total_users": len(analytics_data.get("users", {})),
            "active_users": active_users,
            "last_activity": analytics_data.get("last_activity", ""),
            "bot_uptime": self.get_uptime(analytics_data.get("bot_start_time"))
        }
    
    def get_uptime(self, start_time):
        """حساب مدة التشغيل"""
        if not start_time:
            return "غير معروف"
        
        start = datetime.fromisoformat(start_time)
        now = datetime.now()
        delta = now - start
        
        days = delta.days
        hours = delta.seconds // 3600
        minutes = (delta.seconds % 3600) // 60
        
        return f"{days} أيام, {hours} ساعات, {minutes} دقائق"
    
    def get_top_users(self, limit=5):
        """الحصول على أفضل المستخدمين"""
        analytics_data = self.load_analytics()
        users = analytics_data.get("users", {})
        
        # ترتيب المستخدمين حسب عدد الرسائل
        sorted_users = sorted(users.items(), 
                            key=lambda x: x[1].get("message_count", 0), 
                            reverse=True)
        
        return sorted_users[:limit]

# إنشاء كائن التحليلات
analytics = Analytics()
