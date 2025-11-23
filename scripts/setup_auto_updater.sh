#!/bin/bash

# إعداد التحديث التلقائي لـ HyperFFactory

CRON_JOB="0 18 * * * /root/HyperFFactory/hyper_repo_manager.sh auto"
CRON_FILE="/etc/cron.d/hyperffactory-auto-update"

echo "🔄 إعداد التحديث التلقائي لـ HyperFFactory..."

# إضافة Cron job
echo "$CRON_JOB" | sudo tee "$CRON_FILE" > /dev/null

# تعيين الصلاحيات المناسبة
sudo chmod 644 "$CRON_FILE"

# إعادة تحميل Cron
sudo systemctl reload crond

echo "✅ تم إعداد التحديث التلقائي:"
echo "• سيتم التشغيل يومياً الساعة 6 مساءً"
echo "• الملف: $CRON_FILE"
echo "• السكربت: /root/HyperFFactory/hyper_repo_manager.sh"

# اختبار التشغيل
echo "🧪 اختبار التشغيل..."
/root/HyperFFactory/hyper_repo_manager.sh status
