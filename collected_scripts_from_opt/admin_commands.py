# MyDeepseek/admin_commands.py
import logging
from telegram import Update
from telegram.ext import ContextTypes
from analytics import analytics

class AdminCommands:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.admin_users = ["1885528223"]  # أضف أي دي المسؤول هنا
    
    def is_admin(self, user_id):
        """التحقق إذا كان المستخدم مسؤول"""
        return str(user_id) in self.admin_users
    
    async def admin_stats(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """إحصائيات المسؤول"""
        user_id = str(update.message.from_user.id)
        
        if not self.is_admin(user_id):
            await update.message.reply_text("❌ ليس لديك صلاحية الوصول لهذا الأمر.")
            return
        
        stats = analytics.get_dashboard_stats()
        top_users = analytics.get_top_users(5)
        
        # بناء رسالة الإحصائيات
        stats_text = f"""
📊 **لوحة التحكم - إحصائيات البوت**

👥 **المستخدمون:**
• إجمالي المستخدمين: {stats['total_users']}
• المستخدمون النشطون: {stats['active_users']}
• إجمالي التفاعلات: {stats['total_interactions']}

⏰ **النشاط:**
• آخر نشاط: {stats['last_activity'][:16]}
• مدة التشغيل: {stats['bot_uptime']}

🏆 **أفضل المستخدمين:"""
        
        for i, (user_id, user_data) in enumerate(top_users, 1):
            stats_text += f"\n{i}. {user_data.get('user_name', 'Unknown')} - {user_data.get('message_count', 0)} رسالة"
        
        await update.message.reply_text(stats_text)
    
    async def broadcast_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """بث رسالة لجميع المستخدمين"""
        user_id = str(update.message.from_user.id)
        
        if not self.is_admin(user_id):
            await update.message.reply_text("❌ ليس لديك صلاحية البث.")
            return
        
        # هذه تحتاج تطوير إضافي لتخزين معرفات المستخدمين
        await update.message.reply_text("📢 خاصية البث قيد التطوير...")

# إنشاء كائن أوامر المسؤول
admin_cmds = AdminCommands()
