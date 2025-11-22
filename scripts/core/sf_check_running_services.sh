#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🚀 Running Services & Ports Check"
echo "==========================================="
echo

echo "🔍 SmartFriend related processes:"
ps aux | grep -E "smart|ffactory|memory|gateway" | grep -v grep | while read process; do
    echo "   🔄 $process"
done

echo
echo "🌐 Active ports (SmartFriend related):"
netstat -tulpn | grep -E ':(8000|8170|8211|8214|8220|11434)' | while read line; do
    echo "   🔌 $line"
done

echo
echo "⚙️  Systemd services:"
systemctl list-units --all | grep -E "smart|ffactory|memory" | while read service; do
    echo "   🛠️  $service"
done

echo
echo "📁 Current working directories of running processes:"
for pid in $(ps aux | grep -E "python.*smart\|python.*ffactory" | grep -v grep | awk '{print $2}'); do
    if [[ -d "/proc/$pid" ]]; then
        wd=$(readlink /proc/$pid/cwd 2>/dev/null)
        cmd=$(ps -p $pid -o cmd --no-headers 2>/dev/null)
        echo "   📍 PID $pid: $wd"
        echo "      🖥️  $cmd"
    fi
done
