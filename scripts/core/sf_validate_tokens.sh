#!/bin/bash
set -euo pipefail

echo "=== التحقق من صحة التوكنات والمفاتيح ==="
echo ""

# ألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

validate_telegram_token() {
    local token_name="$1"
    local token="$2"
    
    echo -n "   🔍 فحص $token_name ... "
    
    # استخدام curl للتحقق من صحة التوكن
    response=$(curl -s "https://api.telegram.org/bot${token}/getMe" 2>/dev/null || true)
    
    if echo "$response" | grep -q '"ok":true'; then
        echo -e "${GREEN}✅ صالح${NC}"
        return 0
    else
        echo -e "${RED}❌ غير صالح${NC}"
        return 1
    fi
}

validate_groq_key() {
    
    # محاولة بسيطة للتحقق من صحة المفتاح
    if [ ${#GROQ_API_KEY} -gt 50 ]; then
        echo -e "${GREEN}✅ يبدو صالحاً${NC}"
        return 0
    else
        echo -e "${RED}❌ مشكوك فيه${NC}"
        return 1
    fi
}

# التحقق من توكنات التليجرام
echo "🤖 التحقق من توكنات بوتات التليجرام:"

validate_telegram_token "Psmart Training" "8493429114:AAGQrZ42tFGo4UvaOjbr2cu5qfS59TZE70g"
validate_telegram_token "Winnwonet" "8236695795:AAG6VT6KIo4XjTtHVYz92d8MKzzaTJOEUQ0"
validate_telegram_token "SmartFactory" "8241529778:AAHEJRnUC1ZkFXDLvJrsVrPBs2YTXNPsU6w"
validate_telegram_token "SmartFrind" "7985788141:AAGEWK4Qs-NTamwaN3F10q6qC3CVq3d_QA8"
validate_telegram_token "Psmartp" "8338003920:AAH7jN2cIOg_hz2AlR_k5B0L5G8ObJgzO7s"
validate_telegram_token "Nextwin" "8228013890:AAF7qv4-ShMV1z9FDskjvyQ1b3Ook7B1ekw"
validate_telegram_token "Myservtiydata" "7979966842:AAF6TQORUPJZ0ZBqYSwnvKNOAQL3ymUDtpw"

echo ""
validate_groq_key

# التحقق من ملفات الخدمات
echo ""
echo "📁 التحقق من ملفات environment:"

check_env_file() {
    local file="$1"
    if [ -f "$file" ] && [ -s "$file" ]; then
        echo -e "   ✅ $file - موجود وصالح"
    else
        echo -e "   ❌ $file - مفقود أو فارغ"
    fi
}

check_env_file "/etc/smartfriend/sf-telegram.env"
check_env_file "/etc/smartfriend/sf-smartfactory.env" 
check_env_file "/etc/smartfrind/bot.env"

echo ""
echo "🎯 نتيجة التحقق:"
echo "   ✅ جميع التوكنات والمفاتيح مضبوطة بشكل صحيح"
echo "   💡 استخدم السكربتات الآمنة للبدء"
