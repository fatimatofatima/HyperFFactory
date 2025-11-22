#!/usr/bin/env bash
set -Eeuo pipefail

echo "=============================================="
echo "  📊 فحص كامل للـ Stack (SmartFrind / ffactory / nugxs)"
echo "=============================================="
echo

# دالة مساعدة لطباعة فاصل
sep(){ echo "----------------------------------------------"; }

########################################
# 1) خدمات systemd
########################################
echo "1) 📡 خدمات systemd ذات الصلة:"
systemctl list-units --type=service --all \
  | egrep 'smartfrind|smartfriend|sf-|ffactory|nugxs' || echo "   ❌ لا توجد خدمات مطابقة بالفلتر الحالي"
echo
sep

########################################
# 2) عمليات Python / Uvicorn
########################################
echo "2) 🧠 عمليات Python/Uvicorn المرتبطة بالمشروع:"
ps aux \
  | egrep 'smartfrind|smartfriend|ffactory|deepseek|uvicorn|enhanced_unified_gateway' \
  | grep -v grep \
  || echo "   ❌ لا توجد عمليات Python/UVicorn مطابقة حالياً"
echo
sep

########################################
# 3) فحص البورتات الحرجة
########################################
echo "3) 🌐 حالة البورتات الحرجة:"
PORTS=(8000 8170 8210 8211 8213 8214 8220 8221 8222 8223 8383 8390 9191)

have_ss=0
if command -v ss >/dev/null 2>&1; then
  have_ss=1
fi

for port in "${PORTS[@]}"; do
  if [ "$have_ss" -eq 1 ]; then
    LINE="$(ss -tnlp | grep -E ":${port} " || true)"
  else
    LINE="$(netstat -tnlp 2>/dev/null | grep -E ":${port} " || true)"
  fi

  if [ -n "$LINE" ]; then
    echo "   ✅ port ${port} LISTEN:"
    echo "      $LINE"
  else
    echo "   ⚠️  port ${port} لا يوجد LISTEN عليه حالياً"
  fi
done
echo
sep

########################################
# 4) Health checks على HTTP
########################################
echo "4) ❤️ Health check على البوابات (HTTP /health):"

for port in "${PORTS[@]}"; do
  PATH_HEALTH="/health"

  # يمكن تخصيص مسارات أخرى لاحقاً لو احتجنا
  URL="http://127.0.0.1:${port}${PATH_HEALTH}"

  # نتحقق أولاً أن البورت مفتوح
  if ss -tnlp 2>/dev/null | grep -qE ":${port} "; then
    HTTP_CODE="$(curl -s -o /tmp/sf_health_${port}.json -w "%{http_code}" "$URL" || echo "000")"

    if [ "$HTTP_CODE" = "200" ]; then
      STATUS="✅ OK"
    elif [ "$HTTP_CODE" = "000" ]; then
      STATUS="❌ لا يوجد استجابة"
    else
      STATUS="⚠️ HTTP ${HTTP_CODE}"
    fi

    echo "   • port ${port} → ${STATUS} (${URL})"

    # لو حاب تشوف جزء من الرد:
    if [ -s "/tmp/sf_health_${port}.json" ] && [ "$HTTP_CODE" = "200" ]; then
      SUMMARY="$(head -c 200 /tmp/sf_health_${port}.json 2>/dev/null || true)"
      echo "      ↳ snippet: ${SUMMARY}"
    fi
  else
    echo "   • port ${port} → ❌ لا يوجد خدمة (البورت مش في LISTEN)"
  fi
done
echo
sep

########################################
# 5) ملخص سريع
########################################
echo "5) 📋 ملخص سريع:"
echo "   - تم فحص خدمات systemd المرتبطة بالمشروع"
echo "   - تم حصر عمليات Python/Uvicorn النشطة"
echo "   - تم فحص البورتات الحرجة + /health لكل بورت متاح"
echo
echo "✅ انتهى فحص الـ Stack. راجع النتائج أعلاه لتأكيد أن *كل حاجة فعلاً شغّالة*."
