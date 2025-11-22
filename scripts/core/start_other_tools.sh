#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🛠️ تشغيل الأدوات المساعدة..."
docker compose -f stack/other_tools/docker-compose.other_tools.yml up -d
echo "✅ تم تشغيل الأدوات المساعدة بنجاح!"
docker ps | grep hyper_tools
