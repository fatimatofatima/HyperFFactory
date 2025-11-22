#!/usr/bin/env bash
set -Eeuo pipefail

echo "============================================================"
echo " SmartFriend Suite – Takeover البورت 8210 من Legacy"
echo "============================================================"
echo

echo "1) من يشغل 8210 حاليًا؟"
ss -tulpn | grep ':8210' || echo "   لا أحد على 8210 حاليًا"
echo

echo "2) محاولة إيقاف أي خدمات Legacy مرتبطة بالـ gateway/envwatch"
for svc in smartfrind-gateway.service smartfrind-envwatch.service; do
  if systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
    echo "   - إيقاف وتعطيل $svc"
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
  else
    echo "   - $svc غير موجود كـ unit file"
  fi
done

echo
echo "3) قتل أي process يدوي لـ smartfrind/gateway.py"
ps aux | grep -F "smartfrind/gateway.py" | grep -v grep || echo "   لا يوجد process smartfrind/gateway.py"
pkill -f 'smartfrind/gateway.py' 2>/dev/null || echo "   لا يوجد ما يتم قتله"
echo

echo "4) التحقق من 8210 بعد قتل الـ legacy"
ss -tulpn | grep ':8210' || echo "   لا أحد على 8210 الآن (جاهز للسيوت)"
echo

echo "5) (اختياري) تشغيل sf-unified.service كـ Gateway رسمي"
echo "   - systemctl restart sf-unified.service"
systemctl daemon-reload
systemctl restart sf-unified.service 2>/dev/null || echo "   ⚠️ فشل تشغيل sf-unified.service – راجع journalctl -u sf-unified.service"

sleep 3
echo
echo "6) حالة sf-unified.service (أول 20 سطر)"
systemctl --no-pager -l status sf-unified.service | sed -n '1,20p' || true

echo
echo "7) التحقق النهائي من 8210"
ss -tulpn | grep ':8210' || echo "   ⚠️ 8210 ما زال غير مشغول – يعني sf-unified لم ينجح في أخذ البورت"
echo
echo "انتهى السكربت – لم يتم لمس Nginx."
