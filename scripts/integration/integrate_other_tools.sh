#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🛠️ بدء تكامل أدوات other المساعدة"
echo "================================"

# إنشاء دليل للأدوات المساعدة
mkdir -p stack/other_tools

echo "📁 إنشاء حاوية الأدوات المساعدة..."

cat > stack/other_tools/docker-compose.other_tools.yml << 'COMPOSE'
version: '3.8'

services:
  hyper-tools-manager:
    image: alpine:3.20
    container_name: hyper_tools_manager
    command: |
      sh -c '
        echo "🛠️ مدير أدوات HyperFFactory"
        echo "📍 إدارة الأدوات والوظائف المساعدة"
        echo "🔧 أدوات: تنظيف, نسخ احتياطي, تحليل"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    networks:
      hyperffactory-core-net:
        aliases:
          - tools-manager

  hyper-utilities:
    image: alpine:3.20
    container_name: hyper_utilities
    command: |
      sh -c '
        echo "🔧 أدوات مساعدة HyperFFactory"
        echo "📍 وظائف مساعدة متنوعة"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    networks:
      hyperffactory-core-net:
        aliases:
          - utilities

networks:
  hyperffactory-core-net:
    external: true
    name: hyperffactory-core-net
COMPOSE

echo "✅ تم إنشاء هيكل الأدوات المساعدة"

# إضافة إلى stacks.yaml
echo "📝 تحديث config/stacks.yaml..."
cat >> config/stacks.yaml << 'STACKS'

  other_tools:
    type: docker
    compose_file: stack/other_tools/docker-compose.other_tools.yml
    description: "Utility tools and helper functions for HyperFFactory"
STACKS

# إنشاء سكربت تشغيل
cat > scripts/core/start_other_tools.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🛠️ تشغيل الأدوات المساعدة..."
docker compose -f stack/other_tools/docker-compose.other_tools.yml up -d
echo "✅ تم تشغيل الأدوات المساعدة بنجاح!"
docker ps | grep hyper_tools
SCRIPT

chmod +x scripts/core/start_other_tools.sh

echo "🎉 تم تكامل أدوات other بنجاح!"
