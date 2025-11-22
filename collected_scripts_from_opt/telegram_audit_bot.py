#!/usr/bin/env python3
import os
import logging
from telegram.ext import Application, CommandHandler

logging.basicConfig(
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    level=logging.INFO,
)

TOKEN = os.environ.get("TELEGRAM_AUDIT_BOT_TOKEN")
if not TOKEN:
    raise SystemExit("TELEGRAM_AUDIT_BOT_TOKEN not set in environment")

logger = logging.getLogger("audit-bot")

async def start(update, context):
    await update.message.reply_text("SmartFriend Audit Bot ✅")

async def ping(update, context):
    await update.message.reply_text("pong")

def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("ping", ping))
    logger.info("Starting audit bot...")
    app.run_polling()

if __name__ == "__main__":
    main()
