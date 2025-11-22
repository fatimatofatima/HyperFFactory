#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================================="
echo "   🔍 SmartFriend Suite vs SmartFrind - Comprehensive Comparison"
echo "==============================================="
echo

SUITE_DIR="/opt/smartfriend-suite"
SMARTFRIND_DIR="/opt/smartfrind"

compare_project() {
    local dir="$1"
    local name="$2"
    
    echo "📊 $name Analysis: $dir"
    echo "----------------------------------------"
    
    if [[ ! -d "$dir" ]]; then
        echo "❌ Directory not found"
        echo
        return
    fi
    
    # Basic info
    echo "📁 Size: $(du -sh "$dir" | cut -f1)"
    echo "🐍 Python files: $(find "$dir" -name "*.py" | wc -l)"
    echo "📄 Total files: $(find "$dir" -type f | wc -l)"
    
    # Directory structure
    echo "📋 Top-level directories:"
    find "$dir" -maxdepth 1 -type d | grep -v "^$dir$" | head -10 | while read subdir; do
        base=$(basename "$subdir")
        count=$(find "$subdir" -name "*.py" | wc -l)
        echo "   📂 $base ($count Python files)"
    done
    
    # Key files detection
    echo "🔑 Key files:"
    for file in "main.py" "app.py" "run.py" "requirements.txt" "setup.py" "Dockerfile" "docker-compose.yml"; do
        if [[ -f "$dir/$file" ]]; then
            echo "   ✅ $file"
        fi
    done
    
    # Git status
    if [[ -d "$dir/.git" ]]; then
        echo "🔄 Git repository: YES"
        cd "$dir" && git log --oneline -3 2>/dev/null | while read commit; do
            echo "   📝 $commit"
        done
        cd - >/dev/null
    else
        echo "🔄 Git repository: NO"
    fi
    
    # Recent activity
    echo "🕒 Recent modifications:"
    find "$dir" -name "*.py" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -3 | while read file; do
        filename=$(echo "$file" | cut -d' ' -f2-)
        timestamp=$(echo "$file" | cut -d' ' -f1)
        date_str=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
        echo "   📄 $(basename "$filename") - $date_str"
    done
    
    echo
}

# Compare both projects
compare_project "$SUITE_DIR" "SMARTFRIEND-SUITE (MAIN)"
compare_project "$SMARTFRIND_DIR" "SMARTFRIND (LEGACY?)"

# Detect which one is actually running
echo "🚀 RUNNING SERVICES ANALYSIS:"
echo "----------------------------------------"

# Check which project directories have active processes
for dir in "$SUITE_DIR" "$SMARTFRIND_DIR"; do
    if [[ -d "$dir" ]]; then
        dir_name=$(basename "$dir")
        echo "🔍 Checking processes from $dir_name:"
        
        # Find PIDs with this working directory
        for pid in $(ps aux | grep python | grep -v grep | awk '{print $2}'); do
            if [[ -d "/proc/$pid" ]]; then
                wd=$(readlink /proc/$pid/cwd 2>/dev/null)
                if [[ "$wd" == "$dir" ]]; then
                    cmd=$(ps -p $pid -o cmd --no-headers 2>/dev/null)
                    echo "   ✅ RUNNING - PID $pid: $cmd"
                fi
            fi
        done
        
        # Check if no running processes found
        if ! ps aux | grep python | grep -v grep | awk '{print $2}' | xargs -I {} readlink /proc/{}/cwd 2>/dev/null | grep -q "$dir"; then
            echo "   ❌ NOT RUNNING"
        fi
        echo
    fi
done

# Database connections analysis
echo "🗄️ DATABASE CONNECTIONS:"
echo "----------------------------------------"
for db in "/var/lib/smartfrind/smart_memory.db" "/opt/smartfrind/data/smartfrind.db" "/opt/smartfriend-suite/data/"*.db; do
    if [[ -f "$db" ]]; then
        echo "📊 $(basename "$db"): $(du -h "$db" | cut -f1)"
        # Try to see which project might be using this DB
        lsof "$db" 2>/dev/null | grep python | while read line; do
            echo "   🔗 Used by: $line"
        done
    fi
done
