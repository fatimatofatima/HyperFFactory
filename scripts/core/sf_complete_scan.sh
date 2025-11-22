#!/bin/bash
echo "=================================================="
echo "          فحص شامل لخدمات السيرفر"
echo "=================================================="
echo "الوقت: $(date)"
echo "المستخدم: $(whoami)" 
echo "السيرفر: $(hostname)"
echo ""

echo "=== حالة النظام العام ==="
uptime
echo ""

echo "=== استخدام الذاكرة ==="
free -h
echo ""

echo "=== استخدام المساحة ==="
df -h / /opt /var
echo ""

echo "=== جميع خدمات SmartFriend ==="
systemctl list-units --all --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | while read unit status load active sub description; do
    echo "الخدمة: $unit"
    echo "  الحالة: $active"
    echo "  الوصف: $description"
    echo "---"
done

echo "=== الخدمات الفاشلة ==="
systemctl list-units --failed --no-legend | while read unit status load active sub description; do
    echo "❌ فاشلة: $unit - $description"
    journalctl -u $unit --since "1 hour ago" --no-pager | grep -E '(error|Error|ERROR|failed|Failed)' | tail -2 | while read line; do
        echo "  $line"
    done
    echo "---"
done

echo "=== الخدمات النشطة ==="
systemctl list-units --state=running --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | while read unit status load active sub description; do
    echo "✅ نشطة: $unit - $description"
    pid=$(systemctl show $unit --property=MainPID --value)
    if [[ $pid -ne 0 ]]; then
        echo "  PID: $pid"
        echo "  الذاكرة: $(ps -o rss= -p $pid 2>/dev/null | awk '{print $1/1024 " MB"}' || echo 'غير متاح')"
    fi
    echo "---"
done

echo "=== خدمات النظام الأساسية ==="
important_services="systemd-networkd systemd-resolved ssh nginx mysql docker"
for service in $important_services; do
    if systemctl is-active $service >/dev/null 2>&1; then
        echo "✅ $service: نشط"
    else
        echo "❌ $service: غير نشط"
    fi
done

echo "=== حالة الشبكة ==="
ss -tuln | grep -E ':(8210|8383|8390|80|443|22)' | head -10

echo "=== المسارات الحرجة ==="
important_paths=("/opt/smartfriend-suite" "/etc/smartfriend" "/var/log")
for path in "${important_paths[@]}"; do
    if [[ -d $path ]]; then
        size=$(du -sh $path 2>/dev/null | cut -f1)
        echo "📁 $path: $size"
    fi
done

echo "=== قاعدة البيانات ==="
db_path="/opt/smartfriend-suite/data/smartfriend_unified.db"
if [[ -f $db_path ]]; then
    db_size=$(ls -lh "$db_path" | awk '{print $5}')
    echo "قاعدة البيانات: $db_path ($db_size)"
else
    echo "❌ قاعدة البيانات غير موجودة"
fi

echo "=== النسخ الاحتياطية ==="
backup_dir="/opt/smartfriend-suite/backups"
if [[ -d $backup_dir ]]; then
    echo "النسخ الاحتياطية:"
    ls -la $backup_dir | grep -E "\.(db|sql|gz|tar)$" | tail -3
else
    echo "❌ مجلد النسخ الاحتياطية غير موجود"
fi

echo "=== السجلات الحديثة ==="
find /var/log /opt/smartfriend-suite/logs -name "*.log" -type f 2>/dev/null | head -3 | while read log; do
    if [[ -f $log ]]; then
        size=$(ls -lh "$log" | awk '{print $5}')
        echo "📋 $log ($size)"
    fi
done

echo ""
echo "=================================================="
echo "               التقرير النهائي"
echo "=================================================="

total_services=$(systemctl list-units --all --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | wc -l)
active_services=$(systemctl list-units --state=running --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | wc -l)
failed_services=$(systemctl list-units --failed --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | wc -l)

echo "إجمالي الخدمات: $total_services"
echo "الخدمات النشطة: $active_services" 
echo "الخدمات الفاشلة: $failed_services"

if [[ $failed_services -eq 0 ]]; then
    echo "✅ حالة النظام: جيدة"
else
    echo "⚠️  حالة النظام: تحتاج انتباه"
fi

echo ""
echo "تم الانتهاء: $(date)"
