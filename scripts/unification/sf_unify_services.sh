#!/bin/bash
echo "🔄 توحيد خدمات smartfriend-* تحت sf-*..."

# 1. إيقاف خدمات smartfriend-*
sudo systemctl stop smartfriend-api.service smartfriend-smartcore.service smartfriend-unified.service

# 2. تعطيلها نهائياً
sudo systemctl disable smartfriend-api.service smartfriend-smartcore.service smartfriend-unified.service smartfriend-hybrid.service

# 3. نقل المنطق إلى sf-* المكافئة
echo "نقل المنطق إلى الخدمات المكافئة في sf-*..."

# smartfriend-api.service (port 8211) → sf-core.service (port 8383) لكننا نحتاج 8211
# سنقوم بتعديل sf-core.service لتعمل على 8211 بدلاً من 8383

# نسخ إعدادات smartfriend-api إلى sf-core
echo "تعديل sf-core.service للعمل على port 8211..."
sudo cp /etc/systemd/system/sf-core.service /etc/systemd/system/sf-core.service.backup
sudo sed -i 's/--port 8383/--port 8211/g' /etc/systemd/system/sf-core.service
sudo systemctl daemon-reload
sudo systemctl restart sf-core.service

# 4. تأكيد النقل
echo "التحقق من الخدمات الموحدة..."
echo "   sf-core.service (port 8211): $(sudo systemctl is-active sf-core.service)"
echo "   sf-unified.service: $(sudo systemctl is-active sf-unified.service)"
echo "   sf-memory.service: $(sudo systemctl is-active sf-memory.service)"

# 5. تحديث Nginx ليتجه للخدمات الجديدة
echo "تحديث Nginx للتوجيه لـ sf-* فقط..."
sudo cp /etc/nginx/sites-enabled/smartfriend.conf /etc/nginx/sites-enabled/smartfriend.conf.backup

# تعديل التوجيهات
sudo sed -i 's/127.0.0.1:8211/127.0.0.1:8211/g' /etc/nginx/sites-enabled/smartfriend.conf # تبقى كما هي
sudo sed -i 's/127.0.0.1:8210/127.0.0.1:8210/g' /etc/nginx/sites-enabled/smartfriend.conf # تبقى كما هي

# إضافة توجيه للذاكرة عندما تصبح جاهزة
sudo sed -i '/#location \\/memory\\/ /a location /memory/ { proxy_pass http://127.0.0.1:8214/; proxy_http_version 1.1; proxy_set_header Host $host; }' /etc/nginx/sites-enabled/smartfriend.conf

sudo nginx -t && sudo systemctl reload nginx

echo "✅ تم توحيد الخدمات بنجاح"
