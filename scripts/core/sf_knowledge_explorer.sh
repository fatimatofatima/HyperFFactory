#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# 🧠 SmartFriend - Knowledge & Code Explorer
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
debug() { echo -e "${CYAN}[?]${NC} $*"; }
note() { echo -e "${MAGENTA}[💡]${NC} $*"; }

echo
echo "==============================================="
echo "   🧠 SmartFriend - Knowledge & Code Explorer"
echo "==============================================="
echo

# 1) البحث عن مجلدات التعلم والمعرفة
info "1. 📚 KNOWLEDGE & LEARNING DIRECTORIES"
learning_dirs=()
while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
        learning_dirs+=("$dir")
        log "   📁 $dir"
        
        # فحص المحتويات
        find "$dir" -maxdepth 2 -type f \( -name "*.md" -o -name "*.txt" -o -name "*.py" -o -name "*.sh" \) 2>/dev/null | head -5 | while read file; do
            debug "     📄 $(basename "$file")"
        done
    fi
done < <(find / -type d \( -name "*learn*" -o -name "*knowledge*" -o -name "*doc*" -o -name "*tutorial*" -o -name "*example*" -o -name "*demo*" -o -name "*test*" -o -name "*sample*" \) 2>/dev/null | head -20)

# 2) البحث في مشاريع SmartFriend
info "2. 🤖 SMARTFRIEND PROJECT EXPLORER"
projects=("/opt" "/root" "/home" "/var" "/usr/local")
for base in "${projects[@]}"; do
    if [[ -d "$base" ]]; then
        echo "   🔍 Searching in $base:"
        find "$base" -type d \( -name "*smart*" -o -name "*friend*" -o -name "*ffactory*" -o -name "*memory*" -o -name "*ai*" -o -name "*bot*" \) 2>/dev/null | head -10 | while read dir; do
            if [[ -d "$dir" ]]; then
                note "     🗂️  $dir"
                
                # عد الملفات بأنواعها
                py_count=$(find "$dir" -name "*.py" 2>/dev/null | wc -l)
                md_count=$(find "$dir" -name "*.md" 2>/dev/null | wc -l)
                sh_count=$(find "$dir" -name "*.sh" 2>/dev/null | wc -l)
                json_count=$(find "$dir" -name "*.json" 2>/dev/null | wc -l)
                
                if [[ $py_count -gt 0 ]] || [[ $md_count -gt 0 ]] || [[ $sh_count -gt 0 ]]; then
                    echo "        📊 Python: $py_count, Markdown: $md_count, Scripts: $sh_count, JSON: $json_count"
                    
                    # عرض أهم الملفات
                    find "$dir" -maxdepth 1 -type f \( -name "*.py" -o -name "*.md" -o -name "README*" \) 2>/dev/null | head -3 | while read file; do
                        size=$(du -h "$file" 2>/dev/null | cut -f1)
                        lines=$(wc -l < "$file" 2>/dev/null | tail -1 || echo "?")
                        echo "        📄 $(basename "$file") ($size, ${lines}L)"
                    done
                fi
            fi
        done
    fi
done

# 3) اكتشاف الأكواد المثيرة للاهتمام
info "3. 🔍 INTERESTING CODE PATTERNS"
echo "   🎯 Searching for key components..."

# البحث عن أنماط محددة
patterns=(
    "class.*AI"
    "def.*train"
    "def.*predict"
    "def.*chat"
    "def.*memory"
    "class.*Bot"
    "def.*api"
    "async.*def"
    "import.*llm"
    "from.*transformers"
)

for pattern in "${patterns[@]}"; do
    echo "   🔎 Pattern: $pattern"
    found_files=$(grep -r --include="*.py" -l "$pattern" /opt /root /home 2>/dev/null | head -3)
    if [[ -n "$found_files" ]]; then
        echo "$found_files" | while read file; do
            log "     📄 $file"
            # عرض السطر المحدد
            grep -n "$pattern" "$file" 2>/dev/null | head -1 | while read line; do
                debug "       ➤ $line"
            done
        done
    fi
done

# 4) تحليل البنية المعمارية
info "4. 🏗️ ARCHITECTURE ANALYSIS"
echo "   📐 Discovering project structure..."

# البحث عن ملفات التكوين والبنية
arch_files=$(find /opt /root -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "config*" -o -name "setup*" -o -name "requirements*" 2>/dev/null | head -15)
if [[ -n "$arch_files" ]]; then
    echo "$arch_files" | while read file; do
        note "     🏛️  $(basename "$file")"
        echo "        📍 $file"
    done
fi

# 5) اكتشاف الوثائق والتعليقات
info "5. 📖 DOCUMENTATION & COMMENTS EXPLORER"
echo "   📚 Searching for documentation..."

# البحث عن ملفات التوثيق
doc_files=$(find /opt /root -name "*.md" -o -name "README*" -o -name "DOC*" -o -name "*.rst" 2>/dev/null | head -10)
if [[ -n "$doc_files" ]]; then
    echo "$doc_files" | while read file; do
        log "     📖 $(basename "$file")"
        # عرض السطر الأول من الوثيقة
        head -n 3 "$file" 2>/dev/null | while read line; do
            if [[ -n "$line" ]]; then
                debug "       ➤ $line"
            fi
        done
    done
fi

# 6) تحليل قاعدة البيانات والنماذج
info "6. 🗄️ DATABASE & MODELS ANALYSIS"
echo "   💾 Searching for data models..."

# البحث عن نماذج البيانات
model_files=$(grep -r --include="*.py" -l "class.*Model\|db\.Model\|BaseModel\|class.*Table" /opt /root 2>/dev/null | head -8)
if [[ -n "$model_files" ]]; then
    echo "$model_files" | while read file; do
        note "     🗂️  $(basename "$file")"
        # عرض تعريفات الكلاسات
        grep -n "^class\|def __init__" "$file" 2>/dev/null | head -3 | while read line; do
            debug "       ➤ $line"
        done
    done
fi

# 7) اكتشاف واجهات APIs
info "7. 🌐 API ENDPOINTS DISCOVERY"
echo "   🔌 Searching for API routes..."

# البحث عن نقاط نهاية API
api_files=$(grep -r --include="*.py" -l "@app\.route\|@router\.\|FastAPI\|APIRouter" /opt /root 2>/dev/null | head -8)
if [[ -n "$api_files" ]]; then
    echo "$api_files" | while read file; do
        log "     🔗 $(basename "$file")"
        # عرض routes
        grep -n "@app\.route\|@router\.\|\"GET\"\|\"POST\"" "$file" 2>/dev/null | head -3 | while read line; do
            debug "       ➤ $line"
        done
    done
fi

# 8) سكريبتات الإدارة والأدوات
info "8. 🛠️ MANAGEMENT SCRIPTS & TOOLS"
echo "   🔧 Discovering utility scripts..."

# البحث عن سكريبتات الأدوات
script_files=$(find /opt /root -name "*.sh" -o -name "*.bash" -o -name "*script*" 2>/dev/null | head -10)
if [[ -n "$script_files" ]]; then
    echo "$script_files" | while read file; do
        note "     🛠️  $(basename "$file")"
        # عرض الوصف من أول 2 سطر
        head -n 2 "$file" 2>/dev/null | grep -v "#!/bin" | while read line; do
            if [[ -n "$line" ]]; then
                debug "       ➤ $line"
            fi
        done
    done
fi

# 9) إنشاء خريطة المعرفة
info "9. 🗺️ CREATING KNOWLEDGE MAP"
echo "   📍 Generating project structure overview..."

# إنشاء ملخص للهيكل
cat > /root/knowledge_map.txt << 'MAP'
🧠 SMARTFRIEND KNOWLEDGE MAP
============================

📚 LEARNING RESOURCES:
$(find / -type d \( -name "*learn*" -o -name "*knowledge*" -o -name "*doc*" \) 2>/dev/null | head -10)

🤖 AI PROJECTS:
$(find /opt /root -type d \( -name "*smart*" -o -name "*ai*" -o -name "*bot*" \) 2>/dev/null | head -15)

🏗️ ARCHITECTURE:
$(find /opt /root -name "*.json" -o -name "*.yaml" -o -name "config*" 2>/dev/null | head -10)

📖 DOCUMENTATION:
$(find /opt /root -name "*.md" -o -name "README*" 2>/dev/null | head -10)

🛠️ TOOLS & SCRIPTS:
$(find /opt /root -name "*.sh" -o -name "*script*" 2>/dev/null | head -10)

🔌 APIS & ENDPOINTS:
$(grep -r --include="*.py" -l "@app\.route\|FastAPI" /opt /root 2>/dev/null | head -8)

🗄️ DATA MODELS:
$(grep -r --include="*.py" -l "class.*Model\|db\.Model" /opt /root 2>/dev/null | head -8)
MAP

log "   📄 Knowledge map saved to: /root/knowledge_map.txt"

# 10) التوصيات
info "10. 💡 RECOMMENDED EXPLORATION PATHS"
echo
note "   🚀 ابدأ باكتشاف:"
echo "      1. 📖 ملفات README و documentation"
echo "      2. 🏗️  ملفات التكوين والبنية"  
echo "      3. 🔌 واجهات APIs ونقاط النهاية"
echo "      4. 🤖 نماذج الذكاء الاصطناعي والتدريب"
echo "      5. 🛠️  سكريبتات الإدارة والأدوات"
echo
note "   💡 نصائح الاستكشاف:"
echo "      - استخدم 'cat' لقراءة الملفات الصغيرة"
echo "      - استخدم 'less' أو 'head' للملفات الكبيرة"
echo "      - ابحث عن patterns محددة باستخدام grep"
echo "      - جرب تشغيل السكريبتات البسيطة أولاً"

echo
echo "==============================================="
log "   🧠 Knowledge exploration completed!"
echo "==============================================="
