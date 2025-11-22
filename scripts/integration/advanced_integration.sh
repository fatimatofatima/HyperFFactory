#!/usr/bin/env bash
set -euo pipefail

echo "🔧 HyperFFactory Advanced Integration Manager"
echo "============================================"

BASE_DIR="/root/HyperFFactory"
CONFIG_FILE="$BASE_DIR/config/factory_manifest.yaml"

show_status() {
    echo "📊 حالة التكامل المتقدمة:"
    echo "========================="
    
    # حالة الخدمات النشطة
    echo ""
    echo "🐳 Docker Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(hyper_|ffactory)" || echo "  ℹ️  لا توجد حاويات نشطة"
    
    echo ""
    echo "⚡ Systemd Services:"
    systemctl --no-pager status "sf-*" 2>/dev/null | head -10 || echo "  ℹ️  لا توجد خدمات systemd"
    
    echo ""
    echo "🤖 AI Agents:"
    ls "$BASE_DIR/ai/prompts/"*.md 2>/dev/null | xargs -I {} basename {} .md | while read agent; do
        echo "  ✅ $agent"
    done || echo "  ℹ️  لا توجد وكلاء مكونين"
}

test_integration() {
    echo "🧪 اختبار التكامل:"
    echo "================="
    
    # اختبار الاتصالات الأساسية
    echo ""
    echo "🔗 اختبار اتصال الخدمات:"
    
    # اختبار SmartFriend Core
    if systemctl is-active --quiet sf-core.service; then
        echo "  ✅ SmartFriend Core (8383) - نشط"
    else
        echo "  ❌ SmartFriend Core (8383) - غير نشط"
    fi
    
    # اختبار Elasticsearch
    if curl -s http://localhost:9200 >/dev/null; then
        echo "  ✅ Elasticsearch (9200) - متاح"
    else
        echo "  ❌ Elasticsearch (9200) - غير متاح"
    fi
    
    # اختبار الـ AI Agents
    if [[ -f "$BASE_DIR/scripts/ai/run_agent_smart.sh" ]]; then
        echo "  ✅ AI Agents System - جاهز"
    else
        echo "  ❌ AI Agents System - غير جاهز"
    fi
}

backup_integration() {
    local backup_dir="$BASE_DIR/backups/integration_$(date +%Y%m%d_%H%M%S)"
    echo "💾 إنشاء نسخة احتياطية للتكامل في: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # نسخ الإعدادات الهامة
    cp -r "$BASE_DIR/config" "$backup_dir/"
    cp -r "$BASE_DIR/scripts" "$backup_dir/"
    cp -r "$BASE_DIR/stack" "$backup_dir/"
    cp -r "$BASE_DIR/apps" "$backup_dir/"
    
    # نسخ حالة النظام
    docker ps > "$backup_dir/docker_status.txt"
    systemctl list-units "sf-*" > "$backup_dir/systemd_status.txt" 2>/dev/null || true
    
    echo "✅ تم إنشاء النسخة الاحتياطية"
    echo "📍 الموقع: $backup_dir"
}

optimize_system() {
    echo "⚡ تحسين أداء النظام:"
    echo "===================="
    
    # تنظيف السجلات القديمة
    find "$BASE_DIR/reports" -name "*.txt" -mtime +7 -delete 2>/dev/null || true
    echo "  ✅ تنظيف التقارير القديمة"
    
    # تحسين أذونات السكربتات
    find "$BASE_DIR/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    echo "  ✅ تحديث أذونات السكربتات"
    
    # تحديث الإعدادات
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i "s/last_updated:.*/last_updated: \"$(date '+%Y-%m-%d %H:%M:%S')\"/" "$CONFIG_FILE"
        echo "  ✅ تحديث طابع الزمن"
    fi
    
    echo "🎯 تم تحسين أداء النظام"
}

case "${1:-}" in
    "status")
        show_status
        ;;
    
    "test")
        test_integration
        ;;
    
    "backup")
        backup_integration
        ;;
    
    "optimize")
        optimize_system
        ;;
    
    "full-check")
        show_status
        echo ""
        test_integration
        echo ""
        optimize_system
        ;;
    
    *)
        echo "استخدام: $0 <command>"
        echo ""
        echo "الأوامر المتاحة:"
        echo "  status      - عرض الحالة الكاملة"
        echo "  test        - اختبار التكامل"
        echo "  backup      - نسخ احتياطي للإعدادات"
        echo "  optimize    - تحسين أداء النظام"
        echo "  full-check  - فحص كامل وتحسين"
        ;;
esac
