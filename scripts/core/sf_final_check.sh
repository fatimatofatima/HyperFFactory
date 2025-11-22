#!/bin/bash
echo "========================================"
echo " 🎯 الفحص النهائي للنظام"
echo "========================================"

echo "1. الخدمات الأساسية:"
services=("sf-core.service" "sf-unified.service" "sf-memory.service" "sf-web.service" "sf-health.service")
for service in "${services[@]}"; do
    if systemctl is-active "$service" >/dev/null; then
        echo "✅ $service - ACTIVE"
    else
        echo "❌ $service - INACTIVE"
    fi
done

echo
echo "2. البورتات الشغالة:"
ss -tlnp | grep -E ':(8211|8214|8215|8220|8390)' | while read line; do
    echo "📡 $line"
done

echo
echo "3. اختبار الواجهات:"
apis=("http://127.0.0.1:8211/health" "http://127.0.0.1:8214/health" "http://127.0.0.1:8220/health")
for api in "${apis[@]}"; do
    if curl -s "$api" >/dev/null; then
        echo "🌐 $api - RESPONDING"
    else
        echo "💥 $api - FAILED"
    fi
done

echo
echo "========================================"
echo " ✅ النظام جاهز للانتقال الكامل!"
echo "========================================"
