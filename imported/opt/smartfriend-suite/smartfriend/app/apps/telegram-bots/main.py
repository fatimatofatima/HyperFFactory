#!/usr/bin/env python3
"""
SmartFriend Programmer Bot – forwarder entrypoint.

هذا الملف موجود فقط ليحافظ على المسار:
  /opt/smartfriend-suite/smartfriend/app/apps/telegram-bots/main.py
بينما الكود الحقيقي للبوت موجود تحت:
  /opt/smartfriend-suite/factory/apps/telegram-bots/main.py
"""

from pathlib import Path
import runpy
import sys

TARGET = Path("/opt/smartfriend-suite/factory/apps/telegram-bots/main.py")

if not TARGET.is_file():
    sys.stderr.write(f"[sf-bot-programmer] Real entrypoint not found: {TARGET}\n")
    sys.exit(1)

# تمرير التحكم بالكامل للملف الحقيقي
runpy.run_path(str(TARGET), run_name="__main__")
