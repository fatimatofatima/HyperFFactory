#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🧠 Finding the MASTER Project"
echo "==========================================="
echo

check_project_quality() {
    local dir="$1"
    local name="$2"
    
    echo "🔍 Evaluating $name: $dir"
    
    if [[ ! -d "$dir" ]]; then
        echo "   ❌ NOT FOUND"
        return 1
    fi
    
    QUALITY_SCORE=0
    
    # 1) وجود هيكل منظم
    if [[ -d "$dir/app" ]] || [[ -d "$dir/src" ]]; then
        echo "   ✅ Has structured app/src directory"
        ((QUALITY_SCORE+=2))
    fi
    
    # 2) وجود requirements أو dependency management
    if [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]]; then
        echo "   ✅ Has dependency management"
        ((QUALITY_SCORE+=2))
    fi
    
    # 3) وجود documentation
    if [[ -f "$dir/README.md" ]] || [[ -f "$dir/docs/" ]]; then
        echo "   ✅ Has documentation"
        ((QUALITY_SCORE+=1))
    fi
    
    # 4) وجود تكوينات
    if find "$dir" -name "*.json" -o -name "*.yaml" -o -name "*.yml" | grep -q .; then
        echo "   ✅ Has configuration files"
        ((QUALITY_SCORE+=1))
    fi
    
    # 5) وجود tests
    if find "$dir" -name "test_*.py" -o -name "*_test.py" | grep -q .; then
        echo "   ✅ Has tests"
        ((QUALITY_SCORE+=1))
    fi
    
    # 6) حجم المشروع (عدد ملفات Python)
    PY_COUNT=$(find "$dir" -name "*.py" | wc -l)
    echo "   📊 Python files: $PY_COUNT"
    if [[ $PY_COUNT -gt 50 ]]; then
        ((QUALITY_SCORE+=2))
    elif [[ $PY_COUNT -gt 20 ]]; then
        ((QUALITY_SCORE+=1))
    fi
    
    # 7) آخر تعديل
    LAST_MOD=$(find "$dir" -name "*.py" -type f -printf "%T@\n" 2>/dev/null | sort -nr | head -1)
    if [[ -n "$LAST_MOD" ]]; then
        DATE_STR=$(date -d "@$LAST_MOD" "+%Y-%m-%d %H:%M:%S")
        echo "   🕒 Last modification: $DATE_STR"
        # Score based on recency (within last 30 days)
        THIRTY_DAYS_AGO=$(date -d "30 days ago" +%s)
        if [[ $LAST_MOD -gt $THIRTY_DAYS_AGO ]]; then
            ((QUALITY_SCORE+=2))
        fi
    fi
    
    echo "   🎯 Quality Score: $QUALITY_SCORE/10"
    echo
    
    return $QUALITY_SCORE
}

# تقييم المشروعين
echo "📈 PROJECT QUALITY ASSESSMENT:"
echo "----------------------------------------"

check_project_quality "/opt/smartfriend-suite" "SMARTFRIEND-SUITE"
SUITE_SCORE=$?

check_project_quality "/opt/smartfrind" "SMARTFRIND"  
SMARTFRIND_SCORE=$?

echo "🎯 FINAL VERDICT:"
echo "----------------------------------------"

if [[ $SUITE_SCORE -gt $SMARTFRIND_SCORE ]]; then
    echo "✅ SMARTFRIEND-SUITE is the MASTER project"
    echo "   Recommendation: Focus development here"
elif [[ $SMARTFRIND_SCORE -gt $SUITE_SCORE ]]; then
    echo "✅ SMARTFRIND is the MASTER project" 
    echo "   Recommendation: Consider migrating to suite"
else
    echo "⚖️ Projects are similar in quality"
    echo "   Recommendation: Analyze specific features"
fi

# Detect actual usage
echo
echo "🔍 USAGE ANALYSIS:"
echo "----------------------------------------"

# Check which project has active services
for dir in "/opt/smartfriend-suite" "/opt/smartfrind"; do
    if [[ -d "$dir" ]]; then
        project=$(basename "$dir")
        echo "Checking $project:"
        
        # Check systemd services
        if systemctl list-units | grep -q "$project"; then
            echo "   ✅ Has systemd services"
        fi
        
        # Check running processes
        if ps aux | grep python | grep -v grep | xargs -I {} echo {} | grep -q "$dir"; then
            echo "   ✅ Has running processes"
        fi
        
        # Check cron jobs
        if crontab -l 2>/dev/null | grep -q "$dir"; then
            echo "   ✅ Has cron jobs"
        fi
    fi
done
