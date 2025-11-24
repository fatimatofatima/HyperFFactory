#!/usr/bin/env bash
# إصلاح أذونات حزم Python للمصنع الموحد

set -Eeuo pipefail

echo "🔧 إصلاح أذونات حزم Python..."

# إصلاح أذونات الحزم الأساسية
for pkg in starlette fastapi uvicorn pydantic; do
    pkg_path="/usr/local/lib/python3.10/dist-packages/$pkg"
    if [ -d "$pkg_path" ]; then
        echo "إصلاح أذونات: $pkg"
        sudo find "$pkg_path" -name "*.py" -exec chmod 644 {} \; 2>/dev/null || true
        sudo chmod -R 644 "$pkg_path" 2>/dev/null || true
    fi
done

# إعادة تشغيل الخدمات المتضررة
sudo systemctl restart sf-web.service 2>/dev/null || true

echo "✅ تم إصلاح الأذونات"
