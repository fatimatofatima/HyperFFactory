#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "=== [1] فحص وجود ملف docker-compose.smartfriend.yml فعلياً ==="
ls -la stack/ai_support/docker-compose.smartfriend.yml || echo "❌ الملف غير موجود في ls"

echo
echo "=== [2] اختبارات [-f] على المسار النسبي والمطلق ==="
if [ -f stack/ai_support/docker-compose.smartfriend.yml ]; then
  echo "✅ -f على المسار النسبي OK"
else
  echo "❌ -f على المسار النسبي FAIL"
fi

if [ -f /root/HyperFFactory/stack/ai_support/docker-compose.smartfriend.yml ]; then
  echo "✅ -f على المسار المطلق OK"
else
  echo "❌ -f على المسار المطلق FAIL"
fi

echo
echo "=== [3] docker compose config على نفس الملف ==="
docker compose -f stack/ai_support/docker-compose.smartfriend.yml config > /tmp/smartfriend_ai_compose.out 2> /tmp/smartfriend_ai_compose.err || echo "⚠️ docker compose config رجّع كود خطأ"

echo "--- stdout (أول 40 سطر) ---"
sed -n '1,40p' /tmp/smartfriend_ai_compose.out || true

echo
echo "--- stderr (أول 40 سطر) ---"
sed -n '1,40p' /tmp/smartfriend_ai_compose.err || true

echo
echo "=== [4] تعريف smartfriend_ai في config/stacks.yaml (مع أرقام الأسطر) ==="
nl -ba config/stacks.yaml | sed -n '1,220p' | sed -n '1,220p' | grep -n 'smartfriend_ai' -n -A3 -B3 || true

echo
echo "=== [5] موضع رسالة \"Compose file not found\" داخل scripts/core/ffactory.sh ==="
grep -n "Compose file not found" scripts/core/ffactory.sh || echo "⚠️ لم يتم العثور على النص داخل ffactory.sh"

echo
echo "=== [6] مقطع من ffactory.sh (أول 160 سطر) مع أرقام الأسطر ==="
nl -ba scripts/core/ffactory.sh | sed -n '1,160p' || true
