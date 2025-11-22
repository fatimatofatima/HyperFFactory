#!/bin/bash
set -euo pipefail

echo "=== بدء تشغيل آمن لـ SmartFriend Suite ==="

# الخدمات الآمنة للبدء (لا تسبب تعارضات)
SAFE_SERVICES=(
    "sf-core.service"           # النواة الأساسية
    "smartfrind-api.service"    # بوابة API الرئيسية  
    "smartfrind-ask.service"    # خدمة الأسئلة
    "sf-telegram.service"       # بوت التليجرام
)

# إيقاف أي خدمات قد تسبب تعارضات أولاً
echo "🛑 إيقاف الخدمات المحتملة للتعارض..."
systemctl stop smartfrind-simple.service smartfrind-ultra.service 2>/dev/null || true

# تشغيل الخدمات الآمنة بالتسلسل
echo "🚀 تشغيل الخدمات الآمنة..."
for service in "${SAFE_SERVICES[@]}"; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "   ▶️ تشغيل $service"
        systemctl start "$service"
        sleep 3  # انتظار بين كل خدمة
    fi
done

echo "✅ تم البدء الآمن"
echo "📊 الحالة:"
systemctl list-units "sf-*" "smartfrind-*" --state=active --no-pager --no-legend
