#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🚀 تشغيل ffactory2 المتقدم..."
docker compose -f stack/ffactory2/docker-compose.ffactory2.yml up -d
echo "✅ تم تشغيل ffactory2 بنجاح!"
docker ps | grep ffactory2
