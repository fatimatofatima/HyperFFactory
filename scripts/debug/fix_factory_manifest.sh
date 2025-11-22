#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "=== [1] فحص factory_manifest.yaml الحالي ==="
if [ -f config/factory_manifest.yaml ]; then
    echo "✅ factory_manifest.yaml موجود"
    grep -A3 "smartfriend_ai" config/factory_manifest.yaml || echo "❌ smartfriend_ai غير موجود في factory_manifest.yaml"
else
    echo "❌ factory_manifest.yaml غير موجود"
fi

echo
echo "=== [2] فحص stacks.yaml الحالي ==="
grep -A3 "smartfriend_ai" config/stacks.yaml

echo
echo "=== [3] إنشاء/تحديث factory_manifest.yaml ==="
cat > config/factory_manifest.yaml << 'MANIFEST'
# HyperFFactory Factory Manifest
# هذا الملف يحدد كل الـ stacks والـ apps المتاحة

stacks:
  core_elk:
    type: docker
    compose_file: stack/core/docker-compose.core.yml
    description: "Core ELK stack with Elasticsearch, Logstash, Kibana"

  monitoring:
    type: docker  
    compose_file: stack/monitoring/docker-compose.monitoring.yml
    description: "Monitoring stack with alerts and dashboards"

  ai_support:
    type: docker
    compose_file: stack/ai_support/docker-compose.ai.yml  
    description: "AI support stack with gateway and agents"

  smartfriend_ai:
    type: docker
    compose_file: stack/ai_support/docker-compose.smartfriend.yml
    description: "Bridge stack to SmartFriend AI Suite"

  legacy_bridge:
    type: docker
    compose_file: stack/core/docker-compose.legacy_ffactory.yml
    description: "Bridge to legacy ffactory systems"

apps:
  smartfriend_suite:
    type: systemd
    description: "SmartFriend AI Suite (systemd services)"
MANIFEST

echo "✅ تم تحديث factory_manifest.yaml"

echo
echo "=== [4] اختبار استخراج compose_file لـ smartfriend_ai ==="
COMPOSE_FILE=$(grep -A3 "smartfriend_ai" config/factory_manifest.yaml | grep "compose_file" | awk '{print $2}' | tr -d '"')
echo "COMPOSE_FILE المستخرج: $COMPOSE_FILE"

COMPOSE_PATH="/root/HyperFFactory/${COMPOSE_FILE}"
echo "COMPOSE_PATH الكامل: $COMPOSE_PATH"

if [[ -f "${COMPOSE_PATH}" ]]; then
    echo "✅ الملف موجود فعلياً!"
else
    echo "❌ الملف غير موجود!"
    ls -la "$(dirname "${COMPOSE_PATH}")" || true
fi

echo
echo "=== [5] اختبار ffactory.sh ==="
scripts/core/ffactory.sh start-stack smartfriend_ai && echo "✅ نجح!" || echo "❌ فشل!"
