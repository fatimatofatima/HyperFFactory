#!/usr/bin/env python3
import os
import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("smartfrind.bot")
TOKEN = "7985788141:AAGEWK4Qs-NTamwaN3F10q6qC3CVq3d_QA8"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await update.message.reply_text(f"🎉 أهلاً {user.first_name}!\n🤖 أنا SmartFrind Bot")

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("🆘 /start - بدء التشغيل\n/help - المساعدة\n/status - حالة النظام")

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("✅ النظام يعمل بشكل طبيعي")

def main():
    try:
        app = Application.builder().token(TOKEN).build()
        app.add_handler(CommandHandler("start", start))
        app.add_handler(CommandHandler("help", help_command))
        app.add_handler(CommandHandler("status", status))
        logger.info("🤖 تشغيل بوت SmartFrind...")
        app.run_polling(drop_pending_updates=True)
    except Exception as e:
        logger.error(f"❌ خطأ: {e}")

if __name__ == "__main__":
    main()
