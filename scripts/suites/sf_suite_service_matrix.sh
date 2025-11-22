#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
MATRIX_FILE="$REPORT_DIR/sf_suite_service_matrix_${TS}.yaml"
GAP_ANALYSIS_FILE="$REPORT_DIR/sf_suite_gap_analysis_${TS}.md"

mkdir -p "$REPORT_DIR"

log() { echo "[$(date '+%F %T')] $*"; }

# دالة لتحليل نوع الخدمة من الاسم والـ ExecStart
analyze_service_type() {
    local service_name="$1"
    local exec_start="$2"
    
    case "$service_name" in
        *api*|*gateway*|*unified*|*core*)
            echo "API/Gateway"
            ;;
        *bot*|*telegram*)
            echo "Bot"
            ;;
        *memory*)
            echo "Memory"
            ;;
        *web*|*ui*)
            echo "WebUI"
            ;;
        *health*|*guard*|*watchdog*|*monitor*)
            echo "Health/Monitoring"
            ;;
        *spider*|*harvest*|*ingest*|*crawl*)
            echo "Spider/Ingest"
            ;;
        *brain*|*learn*|*train*|*kb*|*fts*)
            echo "Brain/Learning"
            ;;
        *backup*|*maintenance*|*db*)
            echo "Operations"
            ;;
        *factory*|*ffactory*)
            echo "Factory"
            ;;
        *)
            # تحليل أكثر دقة من الـ ExecStart
            if [[ "$exec_start" == *uvicorn* ]]; then
                echo "API/Gateway"
            elif [[ "$exec_start" == *python*bot* ]] || [[ "$exec_start" == *telegram* ]]; then
                echo "Bot"
            elif [[ "$exec_start" == *spider* ]] || [[ "$exec_start" == *crawl* ]] || [[ "$exec_start" == *harvest* ]]; then
                echo "Spider/Ingest"
            elif [[ "$exec_start" == *learn* ]] || [[ "$exec_start" == *train* ]] || [[ "$exec_start" == *brain* ]]; then
                echo "Brain/Learning"
            else
                echo "Other"
            fi
            ;;
    esac
}

# دالة لاستخراج البورت من الـ ExecStart
extract_port() {
    local exec_start="$1"
    local service_name="$2"
    
    # البحث عن --port في uvicorn
    if [[ "$exec_start" == *uvicorn* ]]; then
        if echo "$exec_start" | grep -q -- "--port"; then
            echo "$exec_start" | grep -o -- "--port [0-9]*" | awk '{print $2}'
            return
        fi
    fi
    
    # بورتات معروفة بناءً على اسم الخدمة
    case "$service_name" in
        *health*) echo "8210" ;;
        *core*|*api*) echo "8211" ;;
        *unified*) echo "8220" ;;
        *memory*) echo "8214" ;;
        *web*) echo "8390" ;;
        *factory*) echo "8170" ;;
        *) echo "" ;;
    esac
}

# دالة لتحديد العائلة
get_service_family() {
    local service_name="$1"
    case "$service_name" in
        sf-*) echo "sf-suite" ;;
        smartfriend-*) echo "smartfriend-suite" ;;
        smartfrind-*) echo "smartfrind-legacy" ;;
        ffactory-*) echo "ffactory" ;;
        *) echo "other" ;;
    esac
}

# دالة لتحديد حالة الخدمة
get_service_status() {
    local service_name="$1"
    local status=$(systemctl is-active "$service_name" 2>/dev/null || echo "not-found")
    local enabled=$(systemctl is-enabled "$service_name" 2>/dev/null || echo "unknown")
    
    if [[ "$status" == "active" ]]; then
        echo "active"
    elif [[ "$status" == "failed" ]]; then
        echo "failed"
    elif [[ "$status" == "activating" ]]; then
        echo "activating"
    else
        echo "inactive"
    fi
}

log "بدء إنشاء Service Matrix..."

{
    echo "# SmartFriend Suite Service Matrix"
    echo "# Generated: $(date '+%F %T')"
    echo "# Hostname: $(hostname)"
    echo ""
    echo "services:"
    
    # جمع كل خدمات systemd المرتبطة
    ALL_SERVICES=$(systemctl list-unit-files --all --type=service | grep -E '(sf-|smartfriend-|smartfrind-|ffactory-)' | awk '{print $1}' | sort)
    
    for service in $ALL_SERVICES; do
        log "تحليل الخدمة: $service"
        
        # استخراج معلومات الخدمة
        exec_start=$(systemctl show "$service" --property=ExecStart --value 2>/dev/null || echo "")
        description=$(systemctl show "$service" --property=Description --value 2>/dev/null || echo "")
        fragment_path=$(systemctl show "$service" --property=FragmentPath --value 2>/dev/null || echo "")
        
        service_type=$(analyze_service_type "$service" "$exec_start")
        family=$(get_service_family "$service")
        status=$(get_service_status "$service")
        port=$(extract_port "$exec_start" "$service")
        
        echo "  - name: '$service'"
        echo "    family: '$family'"
        echo "    type: '$service_type'"
        echo "    status: '$status'"
        if [[ -n "$port" ]]; then
            echo "    port: $port"
        fi
        if [[ -n "$description" ]]; then
            echo "    description: '$description'"
        fi
        if [[ -n "$fragment_path" && "$fragment_path" != "/dev/null" ]]; then
            echo "    config_path: '$fragment_path'"
        fi
        if [[ -n "$exec_start" ]]; then
            echo "    exec_start: '$exec_start'"
        fi
        echo ""
    done
    
} > "$MATRIX_FILE"

log "تم إنشاء Service Matrix: $MATRIX_FILE"

# الآن إنشاء تحليل الفجوات
log "بدء تحليل الفجوات G1-G10..."

{
    echo "# SmartFriend Suite Gap Analysis (G1-G10)"
    echo "# Generated: $(date '+%F %T')"
    echo ""
    
    echo "## G1 - فجوة البراند والخدمات (ازدواجية الهوية)"
    echo ""
    echo "الخدمات التي لها نظائر مكررة عبر العائلات المختلفة:"
    echo ""
    
    # البحث عن خدمات مكررة (نفس النوع في عائلات مختلفة)
    echo "### APIs/Gateways المكررة:"
    grep -A10 "type: 'API/Gateway'" "$MATRIX_FILE" | grep "name:" | sed 's/.*: //' | sed "s/'//g" | sort
    echo ""
    
    echo "### Bots المكررة:"
    grep -A10 "type: 'Bot'" "$MATRIX_FILE" | grep "name:" | sed 's/.*: //' | sed "s/'//g" | sort
    echo ""
    
    echo "### Brain/Learning المكررة:"
    grep -A10 "type: 'Brain/Learning'" "$MATRIX_FILE" | grep "name:" | sed 's/.*: //' | sed "s/'//g" | sort
    echo ""
    
    echo "## G2 - ملكية البورتات الأساسية"
    echo ""
    echo "البورتات الأساسية وملكيتها الحالية:"
    echo ""
    
    for port in 8210 8211 8214 8220 8383 8390 8170; do
        echo "### البورت $port:"
        grep -B5 -A5 "port: $port" "$MATRIX_FILE" | grep -E "(name:|family:|status:)" | head -3
        echo ""
    done
    
    echo "## G3 - فجوة Memory API (البورت 8214)"
    echo ""
    echo "الخدمات التي تحاول استخدام البورت 8214:"
    grep -B10 -A5 "port: 8214" "$MATRIX_FILE" || echo "لا توجد خدمات مع البورت 8214"
    echo ""
    
    echo "## G4 - فجوة Web UI"
    echo ""
    echo "خدمات Web UI:"
    grep -B10 -A5 "type: 'WebUI'" "$MATRIX_FILE" || echo "لا توجد خدمات WebUI"
    echo ""
    
    echo "## G5 - ازدواجية Brain/Learning"
    echo ""
    echo "خدمات Brain/Learning عبر جميع العائلات:"
    grep -B5 -A5 "type: 'Brain/Learning'" "$MATRIX_FILE"
    echo ""
    
    echo "## G6 - ازدواجية Spider/Ingest"
    echo ""
    echo "خدمات Spider/Ingest:"
    grep -B5 -A5 "type: 'Spider/Ingest'" "$MATRIX_FILE" || echo "لا توجد خدمات Spider/Ingest"
    echo ""
    
    echo "## G7 - ازدواجية Bots"
    echo ""
    echo "جميع خدمات Bots:"
    grep -B5 -A5 "type: 'Bot'" "$MATRIX_FILE"
    echo ""
    
    echo "## G8 - ازدواجية Health/Monitoring"
    echo ""
    echo "خدمات Health/Monitoring:"
    grep -B5 -A5 "type: 'Health/Monitoring'" "$MATRIX_FILE" || echo "لا توجد خدمات Health/Monitoring"
    echo ""
    
    echo "## G9 - فجوة إدارة الأسرار والبيئة"
    echo ""
    echo "الخدمات التي تفشل (قد تكون بسبب مشاكل بيئة):"
    grep -B10 "status: 'failed'" "$MATRIX_FILE" | grep "name:" | sed 's/.*: //' | sed "s/'//g"
    echo ""
    
    echo "## G10 - وحدات systemd قديمة غير مستخدمة"
    echo ""
    echo "الخدمات المعطلة أو غير الموجودة:"
    grep -B10 -A5 "status: 'inactive'" "$MATRIX_FILE" | grep "name:" | sed 's/.*: //' | sed "s/'//g" | head -20
    echo ""
    
    echo "## التوصيات الفورية"
    echo ""
    echo "1. **إيقاف الخدمات المكررة** في smartfrind-legacy"
    echo "2. **إصلاح الخدمات الفاشلة** في sf-suite" 
    echo "3. **توحيد البورتات** تحت ملكية sf-suite فقط"
    echo "4. **إنشاء ملف إعداد مركزي** للسيوت"
    echo ""
    
} > "$GAP_ANALYSIS_FILE"

log "تم إنشاء تحليل الفجوات: $GAP_ANALYSIS_FILE"

# عرض ملخص سريع
echo ""
echo "📊 ملخص Service Matrix:"
echo "========================="
echo "إجمالي الخدمات المحللة: $(grep -c "name:" "$MATRIX_FILE")"
echo ""
echo "📈 التوزيع حسب العائلة:"
grep "family:" "$MATRIX_FILE" | sort | uniq -c | sort -nr
echo ""
echo "🚦 التوزيع حسب الحالة:"
grep "status:" "$MATRIX_FILE" | sort | uniq -c | sort -nr
echo ""
echo "🔧 التوزيع حسب النوع:"
grep "type:" "$MATRIX_FILE" | sort | uniq -c | sort -nr
echo ""
echo "📍 الملفات المنشأة:"
echo "• Service Matrix: $MATRIX_FILE"
echo "• Gap Analysis: $GAP_ANALYSIS_FILE"
echo ""
echo "✅ اكتمل Step 1 - يمكنك مراجعة الملفات والانتقال لـ Step 2"

