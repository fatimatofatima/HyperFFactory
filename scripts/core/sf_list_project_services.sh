#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================="
echo "  📊 خدمات وعمليات مشروع SmartFrind / SmartFriend / ffactory / nugxs"
echo "==============================="
echo

### 1) خدمات systemd المرتبطة بالمشروع
echo "1) 📡 خدمات systemd للمشروع:"
SERVICES="$(systemctl list-units --type=service --all \
  | egrep 'smartfrind|smartfriend|ffactory|sf-|nugxs' || true)"

if [ -n "$SERVICES" ]; then
  echo "$SERVICES"
else
  echo "   ❌ لا توجد خدمات مشروع ظاهرة في systemd (بالكلمات المفتاحية الحالية)"
fi

echo
echo "----------------------------------------"
echo "2) 🐳 حاويات Docker المرتبطة بالمشروع:"
if command -v docker >/dev/null 2>&1; then
  DOCKER_OUT="$(docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' \
    | egrep 'smartfrind|smartfriend|ffactory|nugxs' || true)"
  if [ -n "$DOCKER_OUT" ]; then
    echo -e "NAME\tIMAGE\tSTATUS\tPORTS"
    echo "$DOCKER_OUT"
  else
    echo "   ❌ لا توجد حاويات Docker للمشروع حاليًا (بالكلمات المفتاحية الحالية)"
  fi
else
  echo "   ⚠️ Docker غير مثبت أو غير متاح"
fi

echo
echo "----------------------------------------"
echo "3) 🧠 عمليات Python/UVicorn المرتبطة بالمشروع:"
PS_OUT="$(ps aux | egrep 'smartfrind|smartfriend|ffactory|nugxs|uvicorn' | grep -v egrep || true)"
if [ -n "$PS_OUT" ]; then
  echo "$PS_OUT"
else
  echo "   ❌ لا توجد عمليات Python/UVicorn مرتبطة واضحة الآن"
fi

echo
echo "----------------------------------------"
echo "4) 🌐 البورتات الحرجة للمشروع (8000, 8210, 8213, 8220, 8221, 8222, 8223):"
if command -v ss >/dev/null 2>&1; then
  ss -tulpn | egrep '(:8000|:8210|:8213|:8220|:8221|:8222|:8223)' || echo "   ❌ لا توجد خدمات تستمع على هذه البورتات"
else
  echo "   ⚠️ أمر ss غير متاح على هذا النظام"
fi

echo
echo "✅ انتهى فحص خدمات وعمليات المشروع."
