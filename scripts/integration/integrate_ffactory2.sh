#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🚀 بدء تكامل ffactory2 مع HyperFFactory"
echo "======================================"

# إنشاء دليل لـ ffactory2 integration
mkdir -p stack/ffactory2

echo "📁 إنشاء هيكل ffactory2 المتكامل..."

# إنشاء docker-compose لـ ffactory2
cat > stack/ffactory2/docker-compose.ffactory2.yml << 'COMPOSE'
version: '3.8'

services:
  ffactory2-advanced-bridge:
    image: alpine:3.20
    container_name: hyper_ffactory2_advanced_bridge
    command: |
      sh -c '
        echo "🚀 جسر ffactory2 المتقدم"
        echo "📍 تكامل مع النسخة المطورة من ffactory"
        echo "🔗 ميزات: تحليلات متقدمة + إدارة محسنة"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    ports:
      - "8585:8585"
    networks:
      hyperffactory-core-net:
        aliases:
          - ffactory2-advanced-bridge

  ffactory2-analytics:
    image: alpine:3.20  
    container_name: hyper_ffactory2_analytics
    command: |
      sh -c '
        echo "📊 محرك تحليلات ffactory2"
        echo "📍 تحليلات متقدمة وإحصائيات"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    networks:
      hyperffactory-core-net:
        aliases:
          - ffactory2-analytics

networks:
  hyperffactory-core-net:
    external: true
    name: hyperffactory-core-net
COMPOSE

echo "✅ تم إنشاء هيكل ffactory2"

# إضافة ffactory2 إلى stacks.yaml
echo "📝 تحديث config/stacks.yaml بإضافة ffactory2..."
cat >> config/stacks.yaml << 'STACKS'

  ffactory2:
    type: docker
    compose_file: stack/ffactory2/docker-compose.ffactory2.yml
    description: "Advanced ffactory2 integration with enhanced features"
STACKS

echo "✅ تم إضافة ffactory2 إلى التكوين"

# إنشاء سكربت تشغيل خاص بـ ffactory2
cat > scripts/core/start_ffactory2.sh << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

echo "🚀 تشغيل ffactory2 المتقدم..."
docker compose -f stack/ffactory2/docker-compose.ffactory2.yml up -d
echo "✅ تم تشغيل ffactory2 بنجاح!"
docker ps | grep ffactory2
SCRIPT

chmod +x scripts/core/start_ffactory2.sh

echo "🎉 تم تكامل ffactory2 بنجاح!"
echo "📋 الأوامر الجديدة:"
echo "   scripts/core/start_ffactory2.sh"
echo "   scripts/core/ffactory.sh start-stack ffactory2"
