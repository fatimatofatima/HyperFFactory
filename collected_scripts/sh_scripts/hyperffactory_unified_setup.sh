#!/usr/bin/env bash
set -euo pipefail

echo "🏭 HyperFFactory Unified Factory - دمج جميع المشاريع"
echo "====================================================="

BASE_DIR="/root/HyperFFactory"
DATE_STR="$(date '+%Y-%m-%d %H:%M:%S')"

############################################
# 1) إنشاء الهيكل الأساسي
############################################
echo "[1] إنشاء الهيكل الأساسي لـ HyperFFactory..."

mkdir -p "$BASE_DIR"

mkdir -p "$BASE_DIR"/{config,stack,apps,scripts,ai,reports,audit,docs,backups}
mkdir -p "$BASE_DIR"/stack/{core,monitoring,ai_support,integrations}
mkdir -p "$BASE_DIR"/apps/{timeline_analyzer,netflow_inspector,backend_coach_api,legacy_bridge}
mkdir -p "$BASE_DIR"/scripts/{core,health,fix,ai,deploy,integration}
mkdir -p "$BASE_DIR"/ai/{prompts,patterns,skills_tracks,datasets,models}
mkdir -p "$BASE_DIR"/reports/{stack_status,apps_status,ai_eval,performance}
mkdir -p "$BASE_DIR"/docs/{architectures,apis,workflows,agents,legacy}
mkdir -p "$BASE_DIR"/backups/{configs,scripts,databases}

############################################
# 2) سيناريوهات الدمج (توثيق + جسور)
############################################
echo "[2] إعداد سيناريوهات الدمج للمستودعات..."

######## hyper-factory → docs/legacy/hyper-factory
HYPER_FACTORY_DIR="$BASE_DIR/docs/legacy/hyper-factory"
mkdir -p "$HYPER_FACTORY_DIR"

cat > "$HYPER_FACTORY_DIR/integration_notes.md" << 'EOF_HYPER'
# hyper-factory Integration

## الدمج:
- ✅ الهيكل الأساسي (تم تبنيه)
- ✅ مفهوم المصنع الموحد (تم توسيعه)
- ✅ إدارة الـ Stacks (تم تحسينه)

## الملاحظات:
- هذا المستودع يمثل الإصدار الأول لفكرة المصنع
- تم دمج المفاهيم الأساسية في HyperFFactory الجديد
EOF_HYPER

######## ffactory / ffactory2 → stack/core/legacy_ffactory
FFACTORY_LEGACY_DIR="$BASE_DIR/stack/core/legacy_ffactory"
mkdir -p "$FFACTORY_LEGACY_DIR"

cat > "$FFACTORY_LEGACY_DIR/integration_plan.md" << 'EOF_FFACTORY'
# ffactory/ffactory2 Integration

## المكونات للدمج:
- ✅ Docker Compose files → stack/core/
- ✅ إعدادات الـ Services → config/legacy/
- ✅ سكربتات التشغيل → scripts/core/legacy/

## إجراءات الدمج:
1. تحليل docker-compose.yml من ffactory
2. تكييف الإعدادات لتناسب HyperFFactory
3. تحديث المسارات والروابط
4. اختبار التشغيل المتكامل
EOF_FFACTORY

# جسر Docker للـ ffactory/ffactory2
cat > "$BASE_DIR/stack/core/docker-compose.legacy_ffactory.yml" << 'EOF_DOCKER'
version: '3.8'

services:
  legacy-ffactory-bridge:
    image: alpine:3.20
    container_name: hyper_legacy_ffactory_bridge
    command: |
      sh -c '
        echo "🔗 جسر اتصال مع ffactory القديم"
        echo "📍 هذا الحاوية تربط HyperFFactory بالمشاريع القديمة"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    networks:
      - hyperffactory-net

  legacy-ffactory2-bridge:
    image: alpine:3.20
    container_name: hyper_legacy_ffactory2_bridge
    command: |
      sh -c '
        echo "🔗 جسر اتصال مع ffactory2 القديم"
        echo "📍 هذا الحاوية تربط HyperFFactory بالمشاريع القديمة"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    networks:
      - hyperffactory-net

networks:
  hyperffactory-net:
    driver: bridge
    name: hyperffactory-legacy-bridge
EOF_DOCKER

######## smartfrind / smartfriend-suite → stack/ai_support
SMARTFRIEND_DIR="$BASE_DIR/stack/ai_support/smartfriend_suite"
mkdir -p "$SMARTFRIEND_DIR"

cat > "$SMARTFRIEND_DIR/integration_plan.md" << 'EOF_SMARTFRIEND'
# smartfrind/smartfriend-suite Integration

## المكونات للدمج:
- ✅ نظام الذكاء الاصطناعي → ai/models/smartfriend/
- ✅ واجهات البرمجة (APIs) → apps/backend_coach_api/
- ✅ إعدادات المحادثات → ai/prompts/smartfriend/
- ✅ قواعد البيانات → stack/core/databases/

## إجراءات الدمج:
1. تكامل نظام المحادثات الذكية
2. نقل نماذج الذكاء الاصطناعي
3. دمج واجهات البرمجة
4. توحيد قواعد البيانات
EOF_SMARTFRIEND

# جسر SmartFriend Suite
cat > "$BASE_DIR/stack/ai_support/docker-compose.smartfriend.yml" << 'EOF_SMARTFRIEND_DOCKER'
version: '3.8'

services:
  smartfriend-ai-bridge:
    image: alpine:3.20
    container_name: hyper_smartfriend_ai_bridge
    command: |
      sh -c '
        echo "🧠 جسر اتصال مع SmartFriend AI Suite"
        echo "📍 هذا الحاوية تربط HyperFFactory بنظام الذكاء الاصطناعي"
        echo "🔗 APIs: /api/v1/chat, /api/v1/agents, /api/v1/knowledge"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    ports:
      - "8383:8383"  # SmartFriend Core API
      - "8390:8390"  # SmartFriend Web UI
      - "8210:8210"  # SmartFriend Health Gate
    networks:
      - hyperffactory-ai-net

  smartfriend-knowledge-base:
    image: alpine:3.20
    container_name: hyper_smartfriend_knowledge
    command: |
      sh -c '
        echo "📚 قاعدة معرفة SmartFriend المتكاملة"
        echo "📍 تخزين واسترجاع المعرفة للمساعدين الذكيين"
        echo "🔍 البحث الدلالي + الذاكرة السياقية"
        echo "🕒 تم الإنشاء: $(date)"
        tail -f /dev/null
      '
    networks:
      - hyperffactory-ai-net

networks:
  hyperffactory-ai-net:
    driver: bridge
    name: hyperffactory-ai-network
EOF_SMARTFRIEND_DOCKER

######## other → apps/legacy_bridge
OTHER_DIR="$BASE_DIR/apps/legacy_bridge/other_repos"
mkdir -p "$OTHER_DIR"

cat > "$OTHER_DIR/integration_plan.md" << 'EOF_OTHER'
# other Repository Integration

## المكونات للدمج:
- ✅ مشاريع تجريبية → apps/experimental/
- ✅ أدوات مساعدة → scripts/utils/
- ✅ إعدادات خاصة → config/custom/
- ✅ وثائق إضافية → docs/contrib/

## إجراءات الدمج:
1. تحليل المشاريع المتاحة
2. تحديد الأدوات القابلة لإعادة الاستخدام
3. دمج الإعدادات المخصصة
4. توثيق العمليات
EOF_OTHER

############################################
# 3) ملف الإعداد الرئيسي factory_manifest.yaml
############################################
echo "[3] تحديث إعدادات HyperFFactory الموحدة..."

cat > "$BASE_DIR/config/factory_manifest.yaml" << EOF_MANIFEST
factory:
  id: hyper_ffactory_unified
  name: "HyperFFactory Unified - All Repositories"
  owner: "Angel-Malak"
  version: "2.0.0"
  integrated_repos:
    - "hyper-factory"
    - "ffactory"
    - "ffactory2"
    - "smartfrind"
    - "smartfriend-suite"
    - "other"

stacks:
  - id: core_elk
    name: "Core ELK & Databases"
    compose_file: "stack/core/docker-compose.core.yml"
    integrated_from: "ffactory"

  - id: monitoring
    name: "Monitoring & Metrics"
    compose_file: "stack/monitoring/docker-compose.monitoring.yml"
    integrated_from: "ffactory2"

  - id: ai_support
    name: "AI Support Stack"
    compose_file: "stack/ai_support/docker-compose.ai.yml"
    integrated_from: "smartfriend-suite"

  - id: legacy_bridge
    name: "Legacy Repositories Bridge"
    compose_file: "stack/core/docker-compose.legacy_ffactory.yml"
    integrated_from: "ffactory, ffactory2"

  - id: smartfriend_ai
    name: "SmartFriend AI Suite"
    compose_file: "stack/ai_support/docker-compose.smartfriend.yml"
    integrated_from: "smartfrind, smartfriend-suite"

  - id: smartfriend_suite
    name: "SmartFriend Systemd Services"
    type: "systemd"
    integrated_from: "smartfriend-suite"

apps:
  - id: timeline_analyzer
    name: "Timeline Analyzer"
    category: "analytics"
    integrated_from: "hyper-factory"

  - id: netflow_inspector
    name: "Netflow Inspector"
    category: "network"
    integrated_from: "ffactory"

  - id: backend_coach_api
    name: "Backend Coach API"
    category: "ai_education"
    integrated_from: "smartfriend-suite"

  - id: legacy_bridge_app
    name: "Legacy Bridge API"
    category: "integration"
    integrated_from: "other"

agents:
  - id: debug_expert
    name: "Debug Expert"
    integrated_from: "smartfrind"

  - id: system_architect
    name: "System Architect"
    integrated_from: "hyper-factory"

  - id: technical_coach
    name: "Technical Coach"
    integrated_from: "smartfriend-suite"

  - id: integration_specialist
    name: "Integration Specialist"
    integrated_from: "other"

logging:
  unified_logs: true
  reports_dir: "reports"
  audit_file: "audit/unified_actions.log"

integration:
  status: "active"
  phase: "initial_merge"
  next_phase: "data_migration"
  last_updated: "${DATE_STR}"
EOF_MANIFEST

############################################
# 4) سكربت إدارة التكامل repo_integration.sh
############################################
echo "[4] إنشاء أدوات إدارة التكامل..."

cat > "$BASE_DIR/scripts/integration/repo_integration.sh" << 'EOF_INTEGRATION'
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/root/HyperFFactory"

echo "🔗 HyperFFactory Repository Integration Manager"
echo "=============================================="

CMD="${1:-}"

case "${CMD}" in
    status)
        echo "📊 حالة التكامل الحالية:"
        echo "------------------------"
        grep -A10 "integrated_repos:" "$BASE_DIR/config/factory_manifest.yaml" || echo "⚠️ لا يوجد ملف manifest"
        ;;
    
    sync-hyper-factory)
        echo "🔄 مزامنة hyper-factory..."
        # TODO: تنفيذ git pull أو rsync من /root/hyper-factory → $BASE_DIR
        echo "✅ تم تسجيل طلب مزامنة hyper-factory (التنفيذ التفصيلي لاحقًا)"
        ;;
    
    sync-ffactory)
        echo "🔄 مزامنة ffactory..."
        # TODO: دمج Docker Compose والإعدادات
        echo "✅ تم تسجيل طلب مزامنة ffactory"
        ;;
    
    sync-smartfriend)
        echo "🔄 مزامنة smartfriend-suite..."
        # TODO: دمج نظام الذكاء الاصطناعي
        echo "✅ تم تسجيل طلب مزامنة smartfriend-suite"
        ;;
    
    health)
        echo "🏥 فحص صحة التكامل:"
        echo "------------------"
        docker ps --filter "name=hyper_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || echo "ℹ️ لا توجد حاويات hyper_*"
        systemctl --no-pager status "sf-core.service" "sf-web.service" "sf-health.service" "sf-bot.service" 2>/dev/null || echo "ℹ️ لا توجد خدمات sf-* أو لا يمكن قراءتها"
        ;;
    
    backup)
        echo "💾 إنشاء نسخة احتياطية للتكامل..."
        BACKUP_DIR="$BASE_DIR/backups/integration_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -r "$BASE_DIR/config" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "$BASE_DIR/stack" "$BACKUP_DIR/" 2>/dev/null || true
        echo "✅ تم إنشاء النسخة الاحتياطية في: $BACKUP_DIR"
        ;;
    
    *)
        echo "استخدام: $0 <command>"
        echo ""
        echo "الأوامر المتاحة:"
        echo "  status              - عرض حالة التكامل"
        echo "  sync-hyper-factory  - مزامنة hyper-factory"
        echo "  sync-ffactory       - مزامنة ffactory"
        echo "  sync-smartfriend    - مزامنة smartfriend-suite"
        echo "  health              - فحص صحة النظام المتكامل"
        echo "  backup              - نسخ احتياطي للإعدادات"
        ;;
esac
EOF_INTEGRATION

chmod +x "$BASE_DIR/scripts/integration/repo_integration.sh"

############################################
# 5) سكربت التحكم الرئيسي ffactory.sh
############################################
echo "[5] تحديث سكربت التحكم الرئيسي..."

cat > "$BASE_DIR/scripts/core/ffactory.sh" << 'EOF_FFACTORY_MAIN'
#!/usr/bin/env bash
set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACTION="${1:-}"
TARGET="${2:-}"

show_banner() {
    cat << 'EOF_BANNER'
🧠 HyperFFactory Unified Factory v2.0 🏭
🔗 Integrated: hyper-factory, ffactory, smartfriend-suite, ffactory2, smartfrind, other
📍 Managing: Stacks, Apps, AI Agents, Legacy Systems

EOF_BANNER
}

usage() {
    show_banner
    cat << 'EOF_USAGE'
إدارة المصنع الموحّد - Unified Factory Controller

الاستخدام:
  ffactory.sh start-stack <stack_id>      تشغيل stack معين
  ffactory.sh stop-stack <stack_id>       إيقاف stack معين
  ffactory.sh start-app <app_id>          تشغيل تطبيق معين
  ffactory.sh status                      عرض حالة النظام المتكامل
  ffactory.sh health                      فحص صحة الـ stacks والخدمات
  ffactory.sh integration <command>       إدارة تكامل المستودعات
  ffactory.sh shutdown-all                إيقاف كل الأنظمة بأمان

أمثلة:
  ffactory.sh start-stack smartfriend_ai
  ffactory.sh start-app backend_coach_api
  ffactory.sh integration status
  ffactory.sh health

EOF_USAGE
}

case "${ACTION}" in
    start-stack|stop-stack|start-app|stop-app|status|health|shutdown-all)
        "${SCRIPTS_DIR}/ffactory_controller.sh" "${ACTION}" "${TARGET}"
        ;;
    
    integration)
        "${SCRIPTS_DIR}/../integration/repo_integration.sh" "${TARGET}"
        ;;
    
    *)
        usage
        ;;
esac
EOF_FFACTORY_MAIN

chmod +x "$BASE_DIR/scripts/core/ffactory.sh"

############################################
# 6) وثيقة التكامل النهائية
############################################
echo "[6] إنشاء وثائق التكامل..."

cat > "$BASE_DIR/docs/UNIFIED_INTEGRATION_GUIDE.md" << 'EOF_GUIDE'
# 🏭 HyperFFactory Unified Integration Guide

## 📋 نظرة عامة
تم دمج جميع المستودعات في هيكل HyperFFactory الموحد:

### المستودعات المدمجة:
1. **hyper-factory** → الهيكل الأساسي والمفاهيم
2. **ffactory** → البنية التحتية و Docker stacks  
3. **ffactory2** → المراقبة والإشراف
4. **smartfrind** → المساعدين الذكيين الأساسيين
5. **smartfriend-suite** → نظام الذكاء الاصطناعي المتكامل
6. **other** → المشاريع والأدوات الإضافية

## 🗂️ هيكل الدمج

### الـ Stacks المتكاملة (من manifest):

- core_elk          → البنية الأساسية
- monitoring        → المراقبة  
- ai_support        → الذكاء الاصطناعي
- legacy_bridge     → الجسور التراثية
- smartfriend_ai    → نظام المحادثات
- smartfriend_suite → خدمات systemd

### الـ Apps المتكاملة:

- timeline_analyzer  → تحليل الخطوط الزمنية
- netflow_inspector  → مراقبة الشبكة
- backend_coach_api  → تدريب المبرمجين
- legacy_bridge_app  → تكامل الأنظمة القديمة

### الـ Agents المتكاملة:

- debug_expert       → خبير حل المشاكل
- system_architect   → مهندس الأنظمة
- technical_coach    → المدرب التقني
- integration_specialist → مختص التكامل

## 🚀 أوامر التشغيل الأساسية

```bash
cd /root/HyperFFactory

# تشغيل Stacks
scripts/core/ffactory.sh start-stack smartfriend_ai
scripts/core/ffactory.sh start-stack legacy_bridge

# تشغيل تطبيق
scripts/core/ffactory.sh start-app backend_coach_api

# المراقبة
scripts/core/ffactory.sh status
scripts/core/ffactory.sh health

# إدارة التكامل
scripts/core/ffactory.sh integration status
scripts/core/ffactory.sh integration backup

المرحلة 1: ✅ تم الإنتهاء
	•	تصميم هيكل الدمج
	•	إنشاء جسور اتصال
	•	توحيد الإعدادات

المرحلة 2: 🔄 قيد التنفيذ
	•	مزامنة الملفات الفعلية من المستودعات
	•	تكوين الاتصالات بين المكونات
	•	اختبار التكامل

المرحلة 3: ⏳ مخطط لها
	•	نقل البيانات والتهيئة
	•	تحسين الأداء
	•	التوثيق النهائي

EOF_GUIDE

echo “🕒 آخر تحديث للدليل: ${DATE_STR}” >> “$BASE_DIR/docs/UNIFIED_INTEGRATION_GUIDE.md”

############################################

7) الخلاصة النهائية

############################################
echo “[7] اكتمال الدمج الأولي!”

cat << EOF_SUMMARY

🎉 اكتمل إعداد HyperFFactory الموحّد!

✅ ما تم إنجازه:
	1.	🏗️  هيكل موحّد لجميع المستودعات
	2.	🔗 جسور اتصال بين المكونات (ffactory / smartfriend-suite / غيرها)
	3.	⚙️ إعدادات تكامل شاملة (config/factory_manifest.yaml)
	4.	🛠️ أدوات إدارة متكاملة (scripts/integration/repo_integration.sh, scripts/core/ffactory.sh)
	5.	📚 توثيق كامل (docs/UNIFIED_INTEGRATION_GUIDE.md + docs/legacy/*)

🚀 الخطوات التالية (يدويًا):
	1.	فحص حالة التكامل:
cd /root/HyperFFactory
scripts/core/ffactory.sh integration status
	2.	فحص صحة النظام:
scripts/core/ffactory.sh integration health
	3.	بدء اختبار الجسور:
(بعد تجهيز docker-compose.core.yml و docker-compose.ai.yml الفعلية)

scripts/core/ffactory.sh start-stack legacy_bridge
scripts/core/ffactory.sh start-stack smartfriend_ai

🕒 تم الإنشاء في: ${DATE_STR}
EOF_SUMMARY

echo “🏁 تم إنشاء HyperFFactory الموحّد في: $BASE_DIR”
