#!/usr/bin/env bash
set -Eeuo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!]${NC} $*"; }

echo "==========================================="
echo "   🕷️  SmartFriend - Net Learner Test (Phase C)"
echo "   🔒 SAFE MODE - LIMITED PAGES"
echo "==========================================="
echo

# 1) التحقق من الملفات الأساسية
info "1. 🔍 Checking required files..."
REQUIRED_FILES=(
    "/opt/smartfrind/learner/seeds.txt"
    "/opt/smartfrind/learner/allowlist_domains.txt" 
    "/opt/smartfrind/learner/denylist_patterns.txt"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        ok "   $(basename "$file") - موجود"
    else
        warn "   $(basename "$file") - غير موجود، سيتم إنشاء نسخة افتراضية"
        # إنشاء ملفات افتراضية إذا كانت مفقودة
        if [[ "$file" == *"seeds.txt" ]]; then
            cat > "$file" << 'SEEDS'
https://realpython.com
https://docs.python.org/3/tutorial/
https://huggingface.co/docs
SEEDS
        elif [[ "$file" == *"allowlist_domains.txt" ]]; then
            cat > "$file" << 'ALLOW'
realpython.com
docs.python.org
huggingface.co
ALLOW
        elif [[ "$file" == *"denylist_patterns.txt" ]]; then
            cat > "$file" << 'DENY'
/login
/register
/admin
DENY
        fi
    fi
done

# 2) عد السجلات الحالية قبل التشغيل
info "2. 📊 Counting records before run..."
DB_MAIN="/var/lib/smartfrind/smart_memory.db"
BEFORE_AI=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM ai_memory" 2>/dev/null || echo "0")
BEFORE_KB=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM knowledge_base" 2>/dev/null || echo "0")

echo "   قبل التشغيل:"
echo "      ai_memory: $BEFORE_AI سجل"
echo "      knowledge_base: $BEFORE_KB سجل"

# 3) تشغيل Net Learner بحدود آمنة
info "3. 🚀 Running Net Learner (Safe Mode)..."
cd /opt/smartfrind

# تعيين متغيرات بيئة آمنة
export SF_LEARN_MAX_PAGES=5
export SF_LEARN_PER_DOMAIN=2
export SF_LEARN_HTTP_TIMEOUT=10
export SF_LEARN_LOG="/var/log/smartfrind/learner_test.log"

# تشغيل Net Learner
python3 learner/net_learner.py

# 4) عد السجلات بعد التشغيل
info "4. 📈 Counting records after run..."
AFTER_AI=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM ai_memory" 2>/dev/null || echo "0")
AFTER_KB=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM knowledge_base" 2>/dev/null || echo "0")

NEW_AI=$((AFTER_AI - BEFORE_AI))
NEW_KB=$((AFTER_KB - BEFORE_KB))

echo "   بعد التشغيل:"
echo "      ai_memory: $AFTER_AI سجل (+$NEW_AI جديد)"
echo "      knowledge_base: $AFTER_KB سجل (+$NEW_KB جديد)"

# 5) عرض السجلات الجديدة
if [[ $NEW_AI -gt 0 ]]; then
    info "5. 🔍 New ai_memory records:"
    sqlite3 "$DB_MAIN" "SELECT question FROM ai_memory ORDER BY id DESC LIMIT 3" 2>/dev/null | while read question; do
        echo "      📝 $question"
    done
fi

echo
if [[ $NEW_AI -gt 0 ]] || [[ $NEW_KB -gt 0 ]]; then
    ok "✅ Phase C completed - Net Learner worked successfully!"
    echo "   النظام الآن يتعلم تلقائياً 🎉"
else
    warn "⚠️  Phase C completed - No new records added"
    echo "   قد يحتاج Net Learner إلى تعديل الإعدادات"
fi

# 6) عرض السجلات للفحص
echo
info "📋 Log file: /var/log/smartfrind/learner_test.log"
tail -10 "/var/log/smartfrind/learner_test.log" 2>/dev/null || echo "   No log file yet"
