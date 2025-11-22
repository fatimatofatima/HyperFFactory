# MyDeepseek/bot_core.py
import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler

from config import settings
from ai_engine import ai_engine
from conversation_manager import conv_manager
from advanced_commands import advanced_cmds
from analytics import analytics
from admin_commands import admin_cmds
from learning_commands import learning_cmds

class MyDeepseekBot:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.application = None
        self.setup_logging()
    
    def setup_logging(self):
        """إعداد نظام التسجيل"""
        logging.basicConfig(
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            level=logging.INFO
        )
        self.logger.info("🚀 MyDeepseek Bot - Logging initialized")
    
    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """رسالة ترحيب مخصصة"""
        user = update.message.from_user
        
        # تسجيل التفاعل في التحليلات
        analytics.log_interaction(str(user.id), user.first_name, "command")
        
        welcome_text = f"""
🌟 **مرحباً {user.first_name}!**

أنت تتحدث مع **{settings.BOT_NAME}** - منصة التعلم الذكية!

🎯 **المميزات المتقدمة:**
• ذكاء اصطناعي تفاعلي محسن
• نظام تعلم تفاعلي مع دورات
• إحصائيات استخدام شخصية
• لوحة تحكم للمسؤولين
• أمثلة برمجية تعليمية
• تتبع التقدم في التعلم

💡 **الأوامر الرئيسية:**
/start - رسالة الترحيب
/help - المساعدة الشاملة  
/learn - بدء التعلم التفاعلي
/stats - إحصائياتك الشخصية
/code - أمثلة برمجية
/ai - معلومات الذكاء الاصطناعي

🔧 **للمسؤولين:**
/admin - لوحة التحكم

🚀 **حالة النظام:** ✅ نشط ومتطور!
        """
        await update.message.reply_text(welcome_text)
        self.logger.info(f"New user started: {user.first_name} (ID: {user.id})")
    
    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نظام مساعدة متطور"""
        analytics.log_interaction(str(update.message.from_user.id), 
                                update.message.from_user.first_name, "command")
        
        help_text = """
🆘 **نظام المساعدة المتقدم - MyDeepseek**

🎓 **نظام التعلم:**
/learn - بدء التعلم التفاعلي
• دورات برمجة متدرجة
• تمارين عملية
• تتبع التقدم

📊 **الإحصائيات:**
/stats - إحصائياتك الشخصية
• عدد الرسائل
• تقدم التعلم
• نشاطك

💻 **البرمجة:**
/code - أمثلة برمجية
• أمثلة حية
• شروحات مفصلة
• تمارين تطبيقية

🤖 **التقنية:**
/ai - معلومات الذكاء الاصطناعي
/about - عن المشروع

🔍 **جرب هذه الكلمات:**
"أريد تعلم برمجة"
"شرح بايثون"
"تمارين برمجية"
"مشروع جديد"

💬 **أو اسأل أي سؤال تقني!**
        """
        await update.message.reply_text(help_text)
    
    async def about_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """عن المشروع"""
        analytics.log_interaction(str(update.message.from_user.id),
                                update.message.from_user.first_name, "command")
        
        about_text = f"""
🧠 **MyDeepseek Project - المنصة المتكاملة**

📁 **الهيكل المتقدم:**
• بوت تليجرام ذكي متطور
• نظام تعلم تفاعلي
• محرك ذكاء اصطناعي مخصص
• نظام تحليلات متقدم
• إدارة محادثات ذكية

🎯 **الرؤية:**
منصة عربية شاملة لتعلم البرمجة والذكاء الاصطناعي
بناء جيل من المطورين العرب
تطوير مشاريع تقنية مبتكرة

🛠 **التقنيات:**
• Python 3.8+ • Telegram Bot API
• Custom AI Engine • JSON Database
• Analytics System • Learning Management

👥 **المستهدفون:**
• المبتدئون في البرمجة
• مطورون يريدون التطوير
• مهتمون بالذكاء الاصطناعي

🚀 **الحالة:** 🔄 تطوير مستمر وإضافات جديدة
        """
        await update.message.reply_text(about_text)
    
    async def learn_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """بدء التعلم التفاعلي"""
        analytics.log_interaction(str(update.message.from_user.id),
                                update.message.from_user.first_name, "command")
        await learning_cmds.start_learning(update, context)
    
    async def admin_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """أوامر المسؤول"""
        await admin_cmds.admin_stats(update, context)
    
    async def handle_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """معالجة الرسائل بالذكاء الاصطناعي المتطور"""
        user_message = update.message.text
        user_id = str(update.message.from_user.id)
        user_name = update.message.from_user.first_name
        
        self.logger.info(f"Message from {user_name}: {user_message}")
        
        # تسجيل التفاعل
        analytics.log_interaction(user_id, user_name, "message")
        
        # الحصول على رد من الذكاء الاصطناعي المحسن
        ai_response = ai_engine.enhanced_ai_response(user_message, user_id)
        
        # حفظ المحادثة في النظام المتقدم
        conv_manager.save_user_conversation(user_id, user_name, user_message, ai_response)
        
        # إرسال الرد
        await update.message.reply_text(ai_response)
    
    def setup_handlers(self):
        """إعداد معالجات الأوامر المتقدمة"""
        # الأوامر الأساسية
        self.application.add_handler(CommandHandler("start", self.start_command))
        self.application.add_handler(CommandHandler("help", self.help_command))
        self.application.add_handler(CommandHandler("about", self.about_command))
        
        # الأوامر المتقدمة
        self.application.add_handler(CommandHandler("stats", advanced_cmds.stats_command))
        self.application.add_handler(CommandHandler("code", advanced_cmds.code_command))
        self.application.add_handler(CommandHandler("ai", advanced_cmds.ai_command))
        
        # أوامر التعلم
        self.application.add_handler(CommandHandler("learn", self.learn_command))
        self.application.add_handler(CommandHandler("learning", self.learn_command))
        
        # أوامر المسؤول
        self.application.add_handler(CommandHandler("admin", self.admin_command))
        
        # معالجة الاستعلامات (للأزرار)
        self.application.add_handler(CallbackQueryHandler(
            learning_cmds.handle_course_selection,
            pattern="^(course_|complete_|next_|main_menu)"
        ))
        
        # معالجة جميع الرسائل النصية
        self.application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_message))
    
    def run(self):
        """تشغيل البوت"""
        try:
            self.logger.info("🚀 Starting Ultimate MyDeepseek Bot...")
            
            # إنشاء تطبيق التليجرام
            self.application = Application.builder().token(settings.BOT_TOKEN).build()
            
            # إعداد المعالجات المتقدمة
            self.setup_handlers()
            
            # البدء
            self.logger.info("✅ Ultimate MyDeepseek Bot is running!")
            self.application.run_polling()
            
        except Exception as e:
            self.logger.error(f"❌ Error starting bot: {e}")
            raise

# دالة التشغيل الرئيسية
def main():
    bot = MyDeepseekBot()
    bot.run()

if __name__ == '__main__':
    main()
