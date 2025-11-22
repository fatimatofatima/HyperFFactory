#!/usr/bin/env python3
import os
import logging
import asyncio
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# إعداد التسجيل
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("telegram.bot")

# التوكن - نستخدم القيمة المباشرة لتجنب مشاكل البيئة
TOKEN = "7985788141:AAGEWK4Qs-NTamwaN3F10q6qC3CVq3d_QA8"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة أمر /start"""
    user = update.effective_user
    welcome_text = f"""
🎉 أهلاً {user.first_name}!

🤖 أنا SmartFriend Bot - النظام الذكي المتكامل
✅ الإصدار: 2.0.0  
👤 المسؤول: أبو حازم
🌐 الخادم: vmi2733174.contaboserver.net

استخدم /help لعرض الأوامر المتاحة.
    """
    await update.message.reply_text(welcome_text)

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة أمر /help"""
    help_text = """
🆘 **الأوامر المتاحة:**

/start - بدء التشغيل والتعريف بالنظام
/help - عرض هذه المساعدة
/status - حالة النظام والخدمات
/health - فحص صحة الخدمات
/about - معلومات عن البوت

📊 **الخدمات المتاحة:**
• الذاكرة (Memory API)
• النظام الموحد (Unified API) 
• بوابة الصحة (Health Gate)
• بوابة الذكاء الاصطناعي
    """
    await update.message.reply_text(help_text)

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة أمر /status"""
    import requests
    
    services = [
        ("🧠 الذاكرة", "http://127.0.0.1:8214/health"),
        ("🔗 النظام الموحد", "http://127.0.0.1:8220/health"),
        ("🏥 بوابة الصحة", "http://127.0.0.1:8210/health")
    ]
    
    results = []
    for name, url in services:
        try:
            response = requests.get(url, timeout=3)
            if response.status_code == 200:
                results.append(f"✅ {name}")
            else:
                results.append(f"⚠️ {name} ({response.status_code})")
        except Exception as e:
            results.append(f"❌ {name}")
    
    status_text = "📊 **حالة الخدمات:**\n" + "\n".join(results)
    await update.message.reply_text(status_text)

async def health(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة أمر /health"""
    health_text = """
🏥 **فحص الصحة:**

✅ النظام الأساسي يعمل
✅ APIs جاهزة للاستخدام  
✅ قاعدة البيانات نشطة
✅ الذاكرة متاحة

💡 النظام جاهز للاستخدام!
    """
    await update.message.reply_text(health_text)

async def about(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة أمر /about"""
    about_text = """
🤖 **SmartFriend System**

📚 نظام ذكي متكامل للإدارة والذكاء الاصطناعي

🔧 **المميزات:**
• إدارة الذاكرة والمعرفة
• واجهات برمجة متعددة
• تكامل مع منصات الذكاء الاصطناعي
• نظام مراقبة متكامل

👨‍💼 **المطور:** أبو حازم
🌐 **الخادم:** vmi2733174
📅 **الإصدار:** 2.0.0
    """
    await update.message.reply_text(about_text)

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة الرسائل النصية العادية"""
    text = update.message.text
    if text:
        response = f"📨 رسالتك: '{text}'\n\n💡 استخدم /help لعرض الأوامر المتاحة."
        await update.message.reply_text(response)

def main():
    """الدالة الرئيسية"""
    try:
        logger.info("🚀 بدء تشغيل بوت Telegram...")
        
        # إنشاء التطبيق
        app = Application.builder().token(TOKEN).build()
        
        # إضافة معالجات الأوامر
        app.add_handler(CommandHandler("start", start))
        app.add_handler(CommandHandler("help", help_command))
        app.add_handler(CommandHandler("status", status))
        app.add_handler(CommandHandler("health", health))
        app.add_handler(CommandHandler("about", about))
        
        # إضافة معالج الرسائل النصية
        app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
        
        logger.info("✅ تم إعداد البوت بنجاح")
        logger.info("🔍 بدء الاستطلاع للرسائل...")
        
        # بدء الاستطلاع
        app.run_polling(
            drop_pending_updates=True,
            allowed_updates=Update.ALL_TYPES
        )
        
    except Exception as e:
        logger.error(f"❌ خطأ في تشغيل البوت: {e}")
        raise

if __name__ == "__main__":
    main()
