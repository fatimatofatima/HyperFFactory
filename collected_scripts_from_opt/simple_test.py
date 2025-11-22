#!/usr/bin/env python3
import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# إعدادات بسيطة
BOT_TOKEN = "8483808469:AAFEwFvJuHgqTrJ56eqJKF9xwQGjZfgHfK4"

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text('🎉 البوت يعمل! نظام MyDeepseek جاهز!')

async def help_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text('💡 الأوامر: /start, /help, /learn')

async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(f'📩 رسالتك: {update.message.text}')

def main():
    logging.basicConfig(level=logging.INFO)
    application = Application.builder().token(BOT_TOKEN).build()
    
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("help", help_cmd))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))
    
    print("🚀 تشغيل البوت...")
    application.run_polling()

if __name__ == '__main__':
    main()
