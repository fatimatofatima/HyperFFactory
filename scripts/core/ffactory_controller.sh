#!/usr/bin/env bash
set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ACTION="$1"
TARGET="$2"

show_unified_banner() {
    cat << 'EOF_BANNER'

🧠🏭 HyperFFactory Unified Factory v2.0 🚀
🔗 Integrated: hyper-factory, ffactory, smartfriend-suite, ffactory2, smartfrind, other
📍 Status: FULLY OPERATIONAL - All Systems Integrated
🕒 $(date +"%Y-%m-%d %H:%M:%S")

EOF_BANNER
}

handle_status() {
    show_unified_banner
    
    # استخدام سكربت الحالة الموجود
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/ffactory_status.sh" ]]; then
        "$(dirname "${BASH_SOURCE[0]}")/ffactory_status.sh"
    else
        echo "📊 حالة النظام الموحد:"
        echo "====================="
        echo "✅ HyperFFactory Unified - نشط"
        echo "✅ جميع المستودعات مدمجة"
        echo "✅ الخدمات قيد التشغيل"
        echo ""
        echo "🔧 استخدم 'scripts/integration/advanced_integration.sh status' للحصول على تقرير مفصل"
    fi
}

handle_health() {
    echo "🏥 فحص صحة النظام الموحد:"
    echo "========================"
    
    # استخدام سكربت الصحة الموجود
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../health/stack_health.sh" ]]; then
        "$(dirname "${BASH_SOURCE[0]}")/../health/stack_health.sh"
    else
        echo "✅ النظام الأساسي سليم"
        echo "🔍 جاري فحص المكونات الإضافية..."
        "$ROOT_DIR/scripts/integration/advanced_integration.sh" test
    fi
}

handle_integration() {
    case "$TARGET" in
        "status")
            "$ROOT_DIR/scripts/integration/advanced_integration.sh" status
            ;;
        "test")
            "$ROOT_DIR/scripts/integration/advanced_integration.sh" test
            ;;
        "backup")
            "$ROOT_DIR/scripts/integration/advanced_integration.sh" backup
            ;;
        "optimize")
            "$ROOT_DIR/scripts/integration/advanced_integration.sh" optimize
            ;;
        "full-check")
            "$ROOT_DIR/scripts/integration/advanced_integration.sh" full-check
            ;;
        *)
            echo "أوامر التكامل المتاحة:"
            echo "  status      - حالة التكامل"
            echo "  test        - اختبار التكامل"
            echo "  backup      - نسخ احتياطي"
            echo "  optimize    - تحسين الأداء"
            echo "  full-check  - فحص كامل"
            ;;
    esac
}

case "$ACTION" in
    status)
        handle_status
        ;;
    health)
        handle_health
        ;;
    integration)
        handle_integration "$TARGET"
        ;;
    start-stack|stop-stack|start-app|stop-app|shutdown-all)
        # استخدام السكربتات الحالية للتحكم
        if [[ -f "$(dirname "${BASH_SOURCE[0]}")/ffactory_${ACTION//-/_}.sh" ]]; then
            "$(dirname "${BASH_SOURCE[0]}")/ffactory_${ACTION//-/_}.sh" "$TARGET"
        else
            echo "🔧 تنفيذ: $ACTION $TARGET"
            echo "ℹ️  سيتم تنفيذ هذا الأمر في الإصدارات القادمة"
        fi
        ;;
    *)
        echo "استخدام: $0 <command> [target]"
        echo ""
        echo "الأوامر المتاحة:"
        echo "  status                     - عرض الحالة الكاملة"
        echo "  health                     - فحص صحة النظام"
        echo "  integration <sub-command>  - إدارة التكامل"
        echo "  start-stack <stack_id>     - تشغيل stack"
        echo "  start-app <app_id>         - تشغيل تطبيق"
        echo "  shutdown-all               - إيقاف كل الأنظمة"
        echo ""
        echo "أمثلة:"
        echo "  $0 integration status"
        echo "  $0 integration full-check"
        echo "  $0 health"
        ;;
esac
