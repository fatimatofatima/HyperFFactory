#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
LOG_FILE="$REPORT_DIR/sf_auto_fix_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

section() {
    echo | tee -a "$LOG_FILE"
    echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
    echo "$1" | tee -a "$LOG_FILE"
    echo "------------------------------------------------------------" | tee -a "$LOG_FILE"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "هذا السكربت يجب أن يُشغّل كـ root" >&2
        exit 1
    fi
}

detect_unified_port() {
    local exec_line
    exec_line="$(systemctl show -p ExecStart sf-unified.service 2>/dev/null | sed -n 's/^ExecStart=//p')"
    local port
    port="$(printf '%s\n' "$exec_line" | sed -n 's/.*--port \([0-9]\+\).*/\1/p' | tail -n 1)"
    if [ -z "$port" ]; then
        echo ""
    else
        echo "$port"
    fi
}

show_service_brief() {
    local svc="$1"
    if ! systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
        log "  - $svc: unit غير موجود"
        return
    fi
    local state active
    state="$(systemctl show -p UnitFileState "$svc" 2>/dev/null | cut -d= -f2)"
    active="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"
    log "  - $svc: active=$active, enabled=$state"
}

fix_service() {
    local svc="$1"
    local label="$2"

    if ! systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
        log "  ⚠️  الخدمة $svc ($label) غير موجودة كـ unit"
        return
    fi

    log "🔧 محاولة إصلاح وتشغيل: $label ($svc)"
    systemctl stop "$svc" 2>/dev/null || true
    systemctl daemon-reload
    systemctl start "$svc" 2>/dev/null || true
    sleep 3

    if systemctl is-active --quiet "$svc"; then
        log "✅ $svc ($label) نشطة الآن"
    else
        log "❌ فشل تشغيل $svc ($label) – آخر 10 أسطر من journalctl:"
        journalctl -u "$svc" -n 10 --no-pager 2>/dev/null | tee -a "$LOG_FILE" || true
    fi
}

snapshot_state() {
    section "A) Snapshot للخدمات الحرجة (قبل/بعد الإصلاح)"
    log "الخدمات الحرجة من السيوت:"
    for svc in sf-core.service sf-unified.service sf-memory.service sf-web.service sf-health.service sf-spider.service sf-learning.service; do
        show_service_brief "$svc"
    done

    section "B) البورتات الرئيسية (8210 / 8211 / 8214 / 8220 / 8390)"
    ss -tulpn | grep -E '(:8210|:8211|:8214|:8220|:8390)' || log "  لا توجد عمليات على البورتات المستهدفة حالياً"

    section "C) عمليات Legacy smartfrind النشطة"
    ps aux | grep smartfrind | grep -v grep || log "  لا توجد عمليات smartfrind نشطة"
}

activate_critical_sf_services() {
    section "D) إصلاح وتشغيل الخدمات الحرجة في السيوت"
    fix_service sf-unified.service "Gateway الموحد"
    fix_service sf-memory.service  "Memory API"
    fix_service sf-web.service     "Web UI / Dashboard"
    fix_service sf-health.service  "Health / Guard"
    fix_service sf-spider.service  "Spider / Harvester"
    fix_service sf-learning.service "Brain Learning Loop"

    local unified_port
    unified_port="$(detect_unified_port)"
    if [ -n "$unified_port" ]; then
        log "ℹ️  ExecStart لـ sf-unified يشير للبورت: $unified_port"
    else
        log "⚠️  لم أجد --port في ExecStart لـ sf-unified (قد يستخدم الإعداد الافتراضي لـ uvicorn)."
    fi
}

takeover_gateway_8210() {
    section "E) استلام البورت 8210 من Legacy smartfrind"

    log "1) حالة البورت 8210 قبل أي تغيير:"
    ss -tulpn | grep ':8210' || log "  لا أحد على 8210 حالياً"
    echo | tee -a "$LOG_FILE"

    log "2) محاولة إيقاف وتعطيل وحدات smartfrind gateway/envwatch إن وجدت"
    for svc in smartfrind-gateway.service smartfrind-envwatch.service; do
        if systemctl list-unit-files "$svc" --no-legend &>/dev/null; then
            log "   - إيقاف $svc"
            systemctl stop "$svc" 2>/dev/null || true
            log "   - تعطيل $svc من الإقلاع"
            systemctl disable "$svc" 2>/dev/null || true
        else
            log "   - $svc غير موجود كـ unit file (تجاهل)"
        fi
    done

    echo | tee -a "$LOG_FILE"
    log "3) قتل أي process لملف smartfrind/gateway.py"
    if ps aux | grep -F "smartfrind/gateway.py" | grep -v grep >/dev/null 2>&1; then
        ps aux | grep -F "smartfrind/gateway.py" | grep -v grep | tee -a "$LOG_FILE" || true
        pkill -f 'smartfrind/gateway.py' 2>/dev/null || true
        log "   - تم إرسال إشارة kill للـ process"
    else
        log "   - لا يوجد process smartfrind/gateway.py نشط"
    fi

    sleep 2
    log "4) حالة 8210 بعد قتل الـ Legacy:"
    ss -tulpn | grep ':8210' || log "  لا أحد على 8210 الآن (جاهز للسيوت)"

    echo | tee -a "$LOG_FILE"
    log "5) إعادة تشغيل sf-unified كـ Gateway رسمي (بدون تعديل Nginx)"
    systemctl daemon-reload
    systemctl restart sf-unified.service 2>/dev/null || true
    sleep 3

    if systemctl is-active --quiet sf-unified.service; then
        log "✅ sf-unified.service نشط بعد إعادة التشغيل"
    else
        log "❌ sf-unified.service ما زال غير نشط – راجع journalctl -u sf-unified.service"
        journalctl -u sf-unified.service -n 10 --no-pager 2>/dev/null | tee -a "$LOG_FILE" || true
    fi

    log "6) التحقق النهائي من 8210:"
    ss -tulpn | grep ':8210' || log "  ⚠️ 8210 ما زال غير مشغول – ربما sf-unified مهيأ على بورت آخر (تحقق من ExecStart)."
}

create_nginx_helper_script() {
    section "F) إنشاء سكربت مستقل لتفعيل مسارات Nginx (/memory/ و /dashboard/) بدون تشغيل تلقائي"

    cat > /root/sf_nginx_enable_routes.sh <<'NGINXEOF'
#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
CONF="/etc/nginx/sites-enabled/smartfriend.conf"
BACKUP="/etc/nginx/sites-enabled/smartfriend.conf.backup.${TS}"

echo "🔀 تفعيل مسارات Nginx /memory/ و /dashboard/"
echo "1) نسخ احتياطي: ${BACKUP}"

if [ -f "$CONF" ]; then
    cp "$CONF" "$BACKUP"
    echo "✅ تم إنشاء نسخة احتياطية من smartfriend.conf"
else
    echo "⚠️  لم أجد $CONF – سيتم إنشاء ملف جديد."
fi

cat > /tmp/smartfriend_new.conf <<'CONFEOF'
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

    # ffactory / unified gateway (يجب أن يكون على نفس البورت الذي يعمل عليه sf-unified)
    location /ffactory/ {
        proxy_pass         http://127.0.0.1:8210/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

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

    # Memory API
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
}
CONFEOF

echo "2) استبدال smartfriend.conf بالتكوين الجديد"
cp /tmp/smartfriend_new.conf "$CONF"

echo "3) اختبار إعدادات Nginx..."
nginx -t

echo "4) إعادة تحميل Nginx..."
systemctl reload nginx

echo "✅ تم تفعيل /memory/ و /dashboard/ في Nginx (بشرط أن sf-memory و sf-web يعملان على 8214 و 8390)."
NGINXEOF

    chmod +x /root/sf_nginx_enable_routes.sh
    log "✅ تم إنشاء /root/sf_nginx_enable_routes.sh (لن يتم تشغيله تلقائياً)."
    log "   شغّله يدويًا عندما تتأكد أن sf-unified / sf-memory / sf-web تعمل على البورتات الصحيحة."
}

main() {
    require_root

    echo "============================================================" | tee -a "$LOG_FILE"
    echo " SmartFriend Suite – سكربت الفحص والإصلاح الشامل (Auto-Fix)" | tee -a "$LOG_FILE"
    echo " Timestamp: $(date '+%F %T')" | tee -a "$LOG_FILE"
    echo " Log file:  $LOG_FILE" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"

    snapshot_state
    activate_critical_sf_services
    takeover_gateway_8210
    snapshot_state
    create_nginx_helper_script

    section "G) خلاصة تنفيذ السكربت"
    log "📌 تم تنفيذ خطوات:"
    log "   - فحص Snapshot أولي."
    log "   - محاولة تشغيل الخدمات الحرجة (sf-unified / sf-memory / sf-web / sf-health / sf-spider / sf-learning)."
    log "   - محاولة سحب البورت 8210 من smartfrind gateway وتشغيل sf-unified مكانه."
    log "   - Snapshot نهائي بعد الإصلاح."
    log "   - إنشاء سكربت مستقل لتفعيل /memory/ و /dashboard/ في Nginx بدون تشغيل تلقائي."

    log "📁 راجع التقرير التفصيلي في: $LOG_FILE"
    echo "انتهى." | tee -a "$LOG_FILE"
}

main "$@"
