#!/usr/bin/env python3
"""
SmartFriend Behavior Bot – forwarder for behavior analysis.
"""

from pathlib import Path
import runpy
import sys

TARGET = Path("/opt/smartfriend-suite/factory/apps/telegram-bots/main.py")

if not TARGET.is_file():
    sys.stderr.write(f"[sf-bot-behavior] Real entrypoint not found: {TARGET}\n")
    sys.exit(1)

# تمرير الـ role الصحيح للبوت السلوكي
import os
os.environ.setdefault('TELEGRAM_BOT_ROLE', 'behavior')

# تمرير التحكم بالكامل للملف الحقيقي
runpy.run_path(str(TARGET), run_name="__main__")
