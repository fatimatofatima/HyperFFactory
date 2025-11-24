#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== إصلاح خدمة ffactory.service المتضاربة ====="

# نسخ احتياطي
BACKUP_DIR="/root/ffactory_unit_backups_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "[1] نسخ احتياطي للخدمة..."
if [ -f /etc/systemd/system/ffactory.service ]; then
    cp -a /etc/systemd/system/ffactory.service "${BACKUP_DIR}/" 
    echo "✅ تم النسخ الاحتياطي: ${BACKUP_DIR}/ffactory.service"
fi

if [ -d /etc/systemd/system/ffactory.service.d ]; then
    cp -a /etc/systemd/system/ffactory.service.d "${BACKUP_DIR}/" 
    echo "✅ تم النسخ الاحتياطي للإعدادات: ${BACKUP_DIR}/ffactory.service.d"
fi

echo "[2] إيقاف الخدمة..."
systemctl stop ffactory.service 2>/dev/null && echo "✅ تم الإيقاف" || echo "⚠️ الخدمة غير نشطة"

echo "[3] تعطيل الخدمة..."
systemctl disable ffactory.service 2>/dev/null && echo "✅ تم التعطيل" || echo "⚠️ الخدمة غير مفعلة"

echo "[4] تحديث systemd..."
systemctl daemon-reload && echo "✅ تم التحديث"

echo "[5] التحقق من الحالة النهائية..."
systemctl status ffactory.service --no-pager --lines=5

echo "[6] التحقق من المنافذ النشطة..."
echo "المنافذ الحالية:"
ss -tulpn | grep -E ":(8210|8220|9191)" | while read line; do
    echo "🔌 $line"
done

echo "===== الإصلاح اكتمل! ====="
echo "النسخ الاحتياطي في: $BACKUP_DIR"
