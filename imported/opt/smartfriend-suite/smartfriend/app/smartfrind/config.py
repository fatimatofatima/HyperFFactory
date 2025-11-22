import os
DB = (os.environ.get('SMARTFRIND_DB') or os.environ.get('SMARTFRIEND_DB') or '/opt/smartfriend-suite/var/db/smartfriend_unified.db')

LLM_ENDPOINT = os.getenv("LLM_ENDPOINT", "https://api.openai.com/v1")
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")
LLM_API_KEY = os.getenv("LLM_API_KEY", "")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")
