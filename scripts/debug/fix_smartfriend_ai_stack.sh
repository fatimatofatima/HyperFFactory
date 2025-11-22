#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "=== [0] نسخ احتياطية فورية ==="
ts="$(date +%Y%m%d_%H%M%S)"
cp config/stacks.yaml "config/stacks.yaml.pre_smartfriend_fix_${ts}"
cp stack/ai_support/docker-compose.smartfriend.yml "stack/ai_support/docker-compose.smartfriend.yml.pre_smartfriend_fix_${ts}" 2>/dev/null || true
echo "✔️ تم إنشاء نسخ احتياطية باسم: ${ts}"

echo
echo "=== [1] محاولة اختيار نسخة stacks.yaml سليمة من الباك أب ==="
good_backup=""
# نختار أول نسخة لا تحتوي على النمط المعطوب: 'compose_file: ... description:'
for f in config/stacks.yaml.bak_*; do
  [ -f "$f" ] || continue
  if ! grep -q 'compose_file: .*description:' "$f"; then
    good_backup="$f"
    break
  fi
done

if [ -n "$good_backup" ]; then
  echo "👉 استخدام النسخة السليمة: $good_backup"
  cp "$good_backup" config/stacks.yaml
else
  echo "⚠️ لم يتم العثور على نسخة سليمة، سنكمل بالملف الحالي."
fi

echo
echo "=== [2] حذف أي بلوك قديم لـ smartfriend_ai وما بعده (لو موجود) ==="
if grep -q '^  smartfriend_ai:' config/stacks.yaml; then
  sed -i '/^  smartfriend_ai:/,$d' config/stacks.yaml
  echo "✔️ تم حذف البلوك القديم لـ smartfriend_ai من config/stacks.yaml"
else
  echo "ℹ️ لا يوجد بلوك smartfriend_ai سابق في config/stacks.yaml"
fi

echo
echo "=== [3] إعادة كتابة بلوكات smartfriend_ai + الـ placeholders بصيغة YAML صحيحة ==="
cat >> config/stacks.yaml << 'YAML'

  smartfriend_ai:
    type: docker
    compose_file: stack/ai_support/docker-compose.smartfriend.yml
    description: "Bridge stack to SmartFriend AI Suite (systemd services + APIs)"

  timeline_analyzer:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for timeline analyzer (no containers)"

  netflow_inspector:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for netflow inspector (no containers)"

  backend_coach_api:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for backend coach api"

  debug_expert:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for debug expert agent"

  system_architect:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for system architect agent"

  technical_coach:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for technical coach agent"

  integration_specialist:
    type: docker
    compose_file: stack/core/docker-compose.noop.yml
    description: "Logical stack placeholder for integration specialist agent"
YAML

echo "✔️ تم حقن البلوكات الجديدة في config/stacks.yaml"

echo
echo "=== [4] تأكيد tail لملف config/stacks.yaml (آخر 40 سطر) ==="
nl -ba config/stacks.yaml | tail -n 40

echo
echo "=== [5] فحص docker-compose.smartfriend.yml بـ docker compose config ==="
if [ ! -f stack/ai_support/docker-compose.smartfriend.yml ]; then
  echo "❌ ملف stack/ai_support/docker-compose.smartfriend.yml غير موجود بشكل غير متوقع"
  exit 1
fi

docker compose -f stack/ai_support/docker-compose.smartfriend.yml config > /tmp/smartfriend_ai_compose_fix.out 2> /tmp/smartfriend_ai_compose_fix.err || echo "⚠️ docker compose config رجّع كود خطأ"

echo "--- stdout (أول 30 سطر) ---"
sed -n '1,30p' /tmp/smartfriend_ai_compose_fix.out || true

echo
echo "--- stderr (أول 30 سطر) ---"
sed -n '1,30p' /tmp/smartfriend_ai_compose_fix.err || true

echo
echo "=== [6] تشغيل stack smartfriend_ai عبر ffactory.sh ==="
scripts/core/ffactory.sh start-stack smartfriend_ai || echo "⚠️ start-stack smartfriend_ai رجّع كود خطأ"

echo
echo "=== [7] فحص ظهور الحاوية hyper_smartfriend_ai_bridge ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep hyper_smartfriend_ai_bridge || echo "⚠️ لا توجد حاوية hyper_smartfriend_ai_bridge بعد"

echo
echo "=== [8] فحص حالة المصنع بعد الإصلاح ==="
scripts/core/ffactory.sh status || true
scripts/core/ffactory.sh health || true

echo
echo "✔️ انتهى fix_smartfriend_ai_stack.sh"
