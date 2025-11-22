#!/bin/bash
set -e

REPORT_FILE="/root/sf_system_report_$(date +%Y%m%d_%H%M%S).txt"

{
echo "================================================"
echo "    SmartFriend System Report"
echo "    Generated: $(date)"
echo "================================================"
echo ""

echo "=== SYSTEM INFORMATION ==="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -a)"
echo ""

echo "=== RESOURCE USAGE ==="
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memory: $(free -h | awk 'NR==2{printf "%.2f/%.2f (%.2f%%)", $3,$2,$3*100/$2}')"
echo "Disk: $(df -h / | awk 'NR==2{print $5 " used (" $3 "/" $2 ")"}')"
echo ""

echo "=== SERVICES STATUS ==="
systemctl list-units --all "sf-*" --no-pager | head -10
echo ""

echo "=== ACTIVE PORTS ==="
ss -tulpn | grep -E ':8210|:8214|:8220|:8383' | sort
echo ""

echo "=== BOT PROCESSES ==="
ps aux | grep -E "python.*(smartfrind|smartfactory)" | grep -v grep | head -5
echo ""

echo "=== DATABASE INFO ==="
DB_FILE="/opt/smartfriend-suite/data/smartfriend_unified.db"
if [[ -f "$DB_FILE" ]]; then
    echo "Database: $(du -h "$DB_FILE" | cut -f1)"
    echo "Tables: $(sqlite3 "$DB_FILE" ".tables" 2>/dev/null | wc -w || echo "N/A")"
else
    echo "Database: Not found"
fi
echo ""

echo "=== TOKEN STATUS ==="
for token in /etc/ai-secrets/*.token; do
    if [[ -f "$token" ]]; then
        echo "$(basename "$token"): $(wc -c < "$token") bytes"
    fi
done
echo ""

echo "=== RECENT ERRORS ==="
journalctl -u "sf-*" --since "1 hour ago" -p err --no-pager | head -5
echo ""

echo "=== RECOMMENDATIONS ==="
if ! systemctl is-active --quiet sf-unified.service; then
    echo "❌ Start Unified API: systemctl start sf-unified.service"
fi

if ! curl -s http://127.0.0.1:8383/health >/dev/null; then
    echo "❌ Check Unified API health"
fi

if [[ ! -f "/etc/ai-secrets/smartfrind.token" ]]; then
    echo "❌ Add Telegram token to /etc/ai-secrets/smartfrind.token"
fi

echo ""
echo "================================================"
echo "Report saved to: $REPORT_FILE"
echo "================================================"

} | tee "$REPORT_FILE"

echo "✅ Report generated: $REPORT_FILE"
