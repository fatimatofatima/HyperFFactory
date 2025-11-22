#!/usr/bin/env bash
set -Eeuo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== فحص سريع للمسارات - SmartFriend Suite ===${NC}\n"

# 1. الخدمات الفاشلة فقط
echo -e "${RED}🔴 الخدمات الفاشلة:${NC}"
systemctl list-units --failed --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | while read -r line; do
    service=$(echo "$line" | awk '{print $1}')
    echo "  $service"
    echo "    ExecStart: $(systemctl show "$service" --property=ExecStart --value)"
    echo "    WorkDir: $(systemctl show "$service" --property=WorkingDirectory --value)"
done

# 2. السكربتات في /root
echo -e "\n${YELLOW}📄 السكربتات في /root:${NC}"
for script in /root/smartfrind_auto_learning.sh /root/auto_learning_agent.sh; do
    if [[ -f "$script" ]]; then
        echo "  ✅ $script (موجود)"
        echo "    السطر الأول: $(head -1 "$script")"
    else
        echo "  ❌ $script (مفقود)"
    fi
done

# 3. Symlinks
echo -e "\n${BLUE}🔗 الـ Symlinks:${NC}"
find /opt -maxdepth 2 -type l -name "*smart*" -exec ls -la {} \; 2>/dev/null | head -10

# 4. المسارات الأساسية
echo -e "\n${GREEN}📁 المسارات الأساسية:${NC}"
for path in /opt/smartfriend-suite /opt/smartfriend-suite/data /opt/smartfriend-suite/backups /opt/smartfriend-suite/scripts; do
    if [[ -e "$path" ]]; then
        echo "  ✅ $path"
    else
        echo "  ❌ $path"
    fi
done
