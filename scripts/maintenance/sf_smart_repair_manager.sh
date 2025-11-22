#!/bin/bash

# ============================================================
# SmartFriend Suite - الذكي للإصلاح والتوحيد
# ============================================================

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# متغيرات التقرير
REPORT_DIR="/opt/smartfriend-suite/reports"
TS=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="$REPORT_DIR/sf_smart_repair_${TS}.log"

# دالة التسجيل
log() {
    echo -e "$(date '+%F %T') $1" | tee -a "$LOG_FILE"
}

# دالة فحص حالة الخدمة
check_service() {
    local service=$1
    local status=$(systemctl is-active "$service" 2>/dev/null)
    if [ "$status" = "active" ]; then
        echo -e "${GREEN}✅ $service${NC}"
        return 0
    else
        echo -e "${RED}❌ $service${NC}"
        return 1
    fi
}

# دالة فحص البورت
check_port() {
    local port=$1
    local service=$2
    if ss -tulpn | grep -q ":$port "; then
        local process=$(ss -tulpn | grep ":$port " | awk '{print $7}' | cut -d'"' -f2)
        echo -e "${GREEN}✅ :$port - $process${NC}"
        return 0
    else
        echo -e "${RED}❌ :$port - غير مشغول${NC}"
        return 1
    fi
}

# دالة الإصلاح الذكي
smart_repair_service() {
    local service=$1
    local port=$2
    local description=$3
    
    log "🔧 محاولة إصلاح: $description"
    
    # حالة الخدمة الحالية
    local current_status=$(systemctl is-active "$service" 2>/dev/null)
    echo -e "${BLUE}الحالة الحالية: $current_status${NC}"
    
    # إيقاف الخدمة إذا كانت تعمل
    if [ "$current_status" = "active" ] || [ "$current_status" = "activating" ]; then
        log "⏸️  إيقاف الخدمة..."
        sudo systemctl stop "$service"
        sleep 2
    fi
    
    # إعادة تحميل systemd
    sudo systemctl daemon-reload
    
    # تشغيل الخدمة
    log "🚀 تشغيل الخدمة..."
    sudo systemctl start "$service"
    sleep 5
    
    # التحقق من النجاح
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✅ نجح إصلاح $service${NC}"
        
        # التحقق من البورت إذا كان محدد
        if [ -n "$port" ]; then
            sleep 3
            if ss -tulpn | grep -q ":$port "; then
                echo -e "${GREEN}✅ البورت $port مشغول الآن${NC}"
            else
                echo -e "${YELLOW}⚠️  الخدمة نشطة لكن البورت $port غير مشغول${NC}"
            fi
        fi
        return 0
    else
        echo -e "${RED}❌ فشل إصلاح $service${NC}"
        
        # عرض الأخطاء
        log "📋 عرض الأخطاء:"
        sudo journalctl -u "$service" -n 10 --no-pager | grep -i "error\|failed\|exception" | head -5 | tee -a "$LOG_FILE"
        return 1
    fi
}

# دالة تفعيل مسارات Nginx
enable_nginx_routes() {
    log "🔀 تفعيل مسارات Nginx..."
    
    # نسخ احتياطي
    cp /etc/nginx/sites-enabled/smartfriend.conf "/etc/nginx/sites-enabled/smartfriend.conf.backup.${TS}"
    
    # إنشاء الإعدادات الجديدة
    cat > /tmp/smartfriend_smart.conf <<'NGINXCONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 62.171.172.105 _;

    client_max_body_size 32m;

    location /nginx-health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # الصفحة الرئيسية – إعادة توجيه للوحة السيوت
    location = / {
        return 302 /dashboard/;
    }

    # ffactory gateway
    location /ffactory/ {
        proxy_pass         http://127.0.0.1:8210/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # واجهة unified الرسمية للسيوت
    location /unified/ {
        proxy_pass         http://127.0.0.1:8210/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # واجهة core الداخلية
    location /core/ {
        proxy_pass         http://127.0.0.1:8211/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # Memory API – مفعل
    location /memory/ {
        proxy_pass         http://127.0.0.1:8214/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # لوحة ويب السيوت
    location /dashboard/ {
        proxy_pass         http://127.0.0.1:8390/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # مسار الصحة العام
    location /health/ {
        proxy_pass         http://127.0.0.1:8215/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }
}
NGINXCONF

    # تطبيق التغييرات
    cp /tmp/smartfriend_smart.conf /etc/nginx/sites-enabled/smartfriend.conf
    
    # اختبار وتطبيق Nginx
    if nginx -t; then
        systemctl reload nginx
        echo -e "${GREEN}✅ تم تفعيل جميع مسارات Nginx${NC}"
        return 0
    else
        echo -e "${RED}❌ خطأ في إعدادات Nginx - تم الاستعادة${NC}"
        cp "/etc/nginx/sites-enabled/smartfriend.conf.backup.${TS}" /etc/nginx/sites-enabled/smartfriend.conf
        return 1
    fi
}

# دالة تحرير البورتات من Legacy
free_legacy_ports() {
    log "🔄 تحرير البورتات من Legacy..."
    
    # البورتات المستهدفة
    declare -A legacy_ports=(
        ["8210"]="smartfrind-gateway"
        ["8211"]="smartfriend-api" 
    )
    
    for port in "${!legacy_ports[@]}"; do
        local legacy_name="${legacy_ports[$port]}"
        
        # فحص من يشغل البورت
        local current_owner=$(ss -tulpn | grep ":$port " | awk '{print $7}' | cut -d'"' -f2 || echo "لا أحد")
        
        if [[ "$current_owner" == *"smartfrind"* ]] || [[ "$current_owner" == *"smartfriend"* ]]; then
            echo -e "${YELLOW}🔄 تحرير البورت $port من $current_owner${NC}"
            
            # إيقاف خدمات systemd المرتبطة
            for svc in smartfrind-gateway.service smartfriend-api.service; do
                if systemctl is-active --quiet "$svc" 2>/dev/null; then
                    sudo systemctl stop "$svc"
                    sudo systemctl disable "$svc"
                    echo -e "${GREEN}✅ تم إيقاف $svc${NC}"
                fi
            done
            
            # قتل العمليات اليدوية
            pkill -f "smartfrind/gateway.py" 2>/dev/null && echo -e "${GREEN}✅ تم قتل smartfrind/gateway.py${NC}"
            pkill -f "smartfriend.*8211" 2>/dev/null && echo -e "${GREEN}✅ تم قتل عمليات smartfriend على 8211${NC}"
            
            sleep 2
            
            # التحقق من التحرير
            local new_owner=$(ss -tulpn | grep ":$port " | awk '{print $7}' | cut -d'"' -f2 || echo "لا أحد")
            if [[ "$new_owner" != *"smartfrind"* ]] && [[ "$new_owner" != *"smartfriend"* ]]; then
                echo -e "${GREEN}✅ البورت $port حر الآن${NC}"
            else
                echo -e "${RED}❌ فشل تحرير البورت $port${NC}"
            fi
        else
            echo -e "${GREEN}✅ البورت $port حر بالفعل${NC}"
        fi
    done
}

# دالة التحليل الذكي للمشاكل
smart_diagnosis() {
    log "🔍 التحليل الذكي للمشاكل..."
    
    echo -e "\n${BLUE}📊 الخدمات الحرجة:${NC}"
    check_service "sf-memory.service"
    check_service "sf-web.service" 
    check_service "sf-unified.service"
    check_service "sf-health.service"
    check_service "sf-core.service"
    
    echo -e "\n${BLUE}🔌 البورتات الرئيسية:${NC}"
    check_port "8210" "Gateway"
    check_port "8211" "Core API"
    check_port "8214" "Memory API"
    check_port "8220" "Unified API"
    check_port "8390" "Web UI"
    
    echo -e "\n${BLUE}📈 إحصائيات النظام:${NC}"
    local sf_active=$(systemctl list-units "sf-*" --no-legend 2>/dev/null | grep -c "running")
    local sf_total=$(systemctl list-unit-files "sf-*" --no-legend 2>/dev/null | wc -l)
    local legacy_active=$(systemctl list-units "smartfrind-*" --no-legend 2>/dev/null | grep -c "running")
    
    echo -e "✅ خدمات السيوت النشطة: $sf_active/$sf_total"
    echo -e "📦 خدمات Legacy النشطة: $legacy_active"
    
    # حساب التقدم
    local progress=$(( (sf_active * 100) / (sf_total + 1) ))
    echo -e "📈 التقدم العام: $progress%"
}

# الدالة الرئيسية
main() {
    echo -e "${BLUE}"
    echo "============================================================"
    echo "   SmartFriend Suite - المدير الذكي للإصلاح والتوحيد"
    echo "============================================================"
    echo -e "${NC}"
    
    # إنشاء مجلد التقارير
    mkdir -p "$REPORT_DIR"
    
    # التحليل الأولي
    smart_diagnosis
    
    echo -e "\n${YELLOW}🚀 بدء الإصلاح التلقائي...${NC}"
    
    # 1. تحرير البورتات من Legacy
    free_legacy_ports
    
    # 2. إصلاح الخدمات الحرجة بالترتيب
    echo -e "\n${BLUE}🔧 إصلاح الخدمات الحرجة:${NC}"
    
    # الخدمات مرتبة حسب الأهمية
    declare -A critical_services=(
        ["sf-memory.service"]="8214 Memory API"
        ["sf-web.service"]="8390 Web UI" 
        ["sf-unified.service"]="8220 Unified Gateway"
        ["sf-health.service"]="8215 Health Monitor"
    )
    
    local repaired=0
    local total=${#critical_services[@]}
    
    for service in "${!critical_services[@]}"; do
        local info=(${critical_services[$service]})
        local port="${info[0]}"
        local description="${info[@]:1}"
        
        if smart_repair_service "$service" "$port" "$description"; then
            ((repaired++))
        fi
        echo "---"
    done
    
    # 3. تفعيل مسارات Nginx
    enable_nginx_routes
    
    # 4. التحليل النهائي
    echo -e "\n${BLUE}📊 النتائج النهائية:${NC}"
    smart_diagnosis
    
    # تقرير النجاح
    echo -e "\n${GREEN}🎯 ملخص الإصلاح:${NC}"
    echo -e "✅ تم إصلاح: $repaired/$total خدمة حرجة"
    echo -e "📁 التقرير الكامل: $LOG_FILE"
    
    if [ $repaired -eq $total ]; then
        echo -e "${GREEN}🎉 تم إصلاح جميع الخدمات بنجاح!${NC}"
    else
        echo -e "${YELLOW}⚠️  تم إصلاح $repaired من $total خدمة${NC}"
    fi
    
    # نصيحة التالي
    echo -e "\n${BLUE}💡 الخطوة التالية المقترحة:${NC}"
    if [ $repaired -ge 3 ]; then
        echo -e "🔧 تشغيل: bash /root/sf_finalize_bots.sh"
    else
        echo -e "🔧 مراجعة الأخطاء في: $LOG_FILE"
    fi
}

# التنفيذ
main "$@"
