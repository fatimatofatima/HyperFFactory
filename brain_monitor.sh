#!/bin/bash

echo "🧠 === مراقب العقل الحي ==="
echo "📊 الذاكرة: $(find /opt/hyper-factory/var/db/ -name "*.db" | wc -l) قاعدة"
echo "🔧 الخدمات: $(systemctl list-units --type=service --state=running | grep -c hyper)"
echo "📈 التعلم: $(ps aux | grep -c [l]earning || echo 'جاري التفعيل')"
echo "🚀 الحالة: $(./scripts/core/ffactory_status.sh | head -1)"
