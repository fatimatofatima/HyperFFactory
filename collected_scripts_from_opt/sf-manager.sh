#!/bin/bash
set -e

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# الدوال المساعدة
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_services() {
    echo "🔍 فحص الخدمات..."
    local services=("sf-smartfrind" "sf-smartfactory" "sf-memory" "sf-unified" "sf-health")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service.service"; then
            print_success "$service: 🟢 نشط"
        else
            print_warning "$service: 🔴 متوقف"
        fi
    done
}

check_apis() {
    echo "🌐 فحص واجهات API..."
    local apis=("8214" "8383" "8220" "8210")
    
    for port in "${apis[@]}"; do
        if curl -s "http://127.0.0.1:$port/health" >/dev/null; then
            print_success "Port $port: 🟢 مستجيب"
        else
            print_warning "Port $port: 🔴 غير مستجيب"
        fi
    done
}

check_tokens() {
    echo "🔐 فحص التوكنات..."
    local token_files=("/etc/ai-secrets/smartfrind.token" "/etc/ai-secrets/smartfactory.token")
    
    for token_file in "${token_files[@]}"; do
        if [[ -f "$token_file" && -s "$token_file" ]]; then
            print_success "$(basename "$token_file"): 🟢 موجود"
        else
            print_error "$(basename "$token_file"): 🔴 مفقود أو فارغ"
        fi
    done
}

restart_services() {
    echo "🔄 إعادة تشغيل الخدمات..."
    local services=("sf-memory" "sf-unified" "sf-smartfrind")
    
    for service in "${services[@]}"; do
        print_status "إعادة تشغيل $service..."
        systemctl restart "$service.service" && \
        print_success "تم إعادة تشغيل $service" || \
        print_error "فشل إعادة تشغيل $service"
    done
}

show_logs() {
    echo "📋 عرض السجلات..."
    local service="${1:-sf-smartfrind}"
    journalctl -u "$service.service" -n 20 --no-pager
}

update_bot() {
    echo "🔄 تحديث البوت..."
    cp /opt/smartfriend-suite/integrations/smartfrind_bot_v2.py \
       /opt/smartfriend-suite/integrations/smartfrind_bot.py
    
    chmod +x /opt/smartfriend-suite/integrations/smartfrind_bot.py
    systemctl restart sf-smartfrind.service
    print_success "تم تحديث البوت وإعادة التشغيل"
}

case "${1:-}" in
    status)
        check_services
        check_apis
        check_tokens
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs "${2:-}"
        ;;
    update)
        update_bot
        ;;
    monitor)
        watch -n 5 "systemctl status sf-smartfrind.service --no-pager"
        ;;
    *)
        echo "استخدام: sf-manager.sh {status|restart|logs|update|monitor}"
        echo ""
        echo "الأوامر المتاحة:"
        echo "  status   - عرض حالة النظام"
        echo "  restart  - إعادة تشغيل الخدمات"
        echo "  logs     - عرض سجلات الخدمة"
        echo "  update   - تحديث البوت"
        echo "  monitor  - مراقبة البوت مباشرة"
        ;;
esac
