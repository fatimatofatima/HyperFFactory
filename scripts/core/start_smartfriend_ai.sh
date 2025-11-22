#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🚀 بدء تشغيل SmartFriend AI Stack مباشرة..."

COMPOSE_FILE="stack/ai_support/docker-compose.smartfriend.yml"
COMPOSE_PATH="/root/HyperFFactory/${COMPOSE_FILE}"

if [[ ! -f "${COMPOSE_PATH}" ]]; then
    echo "❌ ملف docker-compose غير موجود: ${COMPOSE_PATH}"
    exit 1
fi

echo "✅ تشغيل: ${COMPOSE_PATH}"
docker compose -f "${COMPOSE_PATH}" up -d

echo "🎉 تم تشغيل SmartFriend AI Stack بنجاح!"
docker ps | grep smartfriend
