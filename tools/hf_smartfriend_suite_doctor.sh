#!/usr/bin/env bash
# دكتور السيوت الذكي: يفحص خدمات SmartFriend Suite + يختبر /health + يضبط Nginx لبروكسي sf-web + يعطي تقرير Git

set -Eeuo pipefail

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*" 
}

SECTION() {
    echo
    echo "============================================================"
    echo "== $*"
    echo "============================================================"
}

SECTION "1) فحص خدمات SmartFriend Suite (sf-core / sf-health / sf-memory / sf-web)"

services=(sf-core.service sf-health.service sf-memory.service sf-web.service)

for s in "${services[@]}"; do
    if systemctl list-unit-files "$s" >/dev/null 2>&1; then
        state="$(systemctl is-active "$s" 2>/dev/null || true)"
        log "- $s: الحالة الحالية = $state"
        if [ "$state" != "active" ]; then
            log "  > محاولة restart لـ $s ..."
            systemctl restart "$s" || log "  ! فشل restart لـ $s"
            sleep 1
            state2="$(systemctl is-active "$s" 2>/dev/null || true)"
            log "  > بعد restart: $state2"
        fi
    else
        log "- $s: غير موجود (unit file غير معروف في systemd)"
    fi
done

SECTION "2) فحص نقاط /health لكل الخدمات"

declare -A endpoints
endpoints["sf-core"]="http://127.0.0.1:8383/health"
endpoints["sf-health"]="http://127.0.0.1:8215/health"
endpoints["sf-memory"]="http://127.0.0.1:8214/health"
endpoints["sf-web-health"]="http://127.0.0.1:8390/health"
endpoints["sf-web-root"]="http://127.0.0.1:8390/"

for name in sf-core sf-health sf-memory sf-web-health sf-web-root; do
    url="${endpoints[$name]}"
    log "🔍 اختبار $name → $url"
    if command -v curl >/dev/null 2>&1; then
        http_code="$(curl -s -o /tmp/hf_${name}.out -w '%{http_code}' "$url" || echo '000')"
        if [ "$http_code" = "200" ]; then
            log "   ✅ HTTP 200 OK"
        else
            log "   ❌ HTTP $http_code"
        fi
    else
        log "   ⚠️ curl غير متوفر، تخطي الفحص"
    fi
done

SECTION "3) إعداد/فحص Nginx لبروكسي sf-web على بورت 8010 (بدون لمس البورتات الحالية)"

if ! command -v nginx >/dev/null 2>&1; then
    log "⚠️ nginx غير مُثبت، تخطي إعداد البروكسي."
else
    # هل يوجد إعداد سابق يشير لـ 127.0.0.1:8390 ؟
    if grep -R "127.0.0.1:8390" /etc/nginx 2>/dev/null | head -n1 | grep -q "8390"; then
        log "✅ تم العثور على إعداد Nginx يشير لـ sf-web (8390)، لن أُغيّر الإعداد الحالي."
    else
        log "ℹ️ لم يتم العثور على إعداد Nginx لـ sf-web، سيتم إنشاء موقع جديد على بورت 8010."

        cat >/etc/nginx/sites-available/sf-web.conf <<'NGINXEOF'
server {
    listen 8010;
    server_name _;

    access_log /var/log/nginx/sf-web.access.log;
    error_log  /var/log/nginx/sf-web.error.log;

    location / {
        proxy_pass         http://127.0.0.1:8390;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
NGINXEOF

        if [ ! -L /etc/nginx/sites-enabled/sf-web.conf ]; then
            ln -s /etc/nginx/sites-available/sf-web.conf /etc/nginx/sites-enabled/sf-web.conf
        fi

        log "🔍 اختبار إعداد Nginx بعد إضافة sf-web.conf"
        if nginx -t; then
            log "✅ إعداد Nginx سليم، إعادة تحميل Nginx..."
            systemctl reload nginx
            log "✅ تم إعادة تحميل Nginx بنجاح."
        else
            log "❌ فشل اختبار إعداد Nginx، سيتم حذف symlink والموقع الجديد لتجنب مشاكل."
            rm -f /etc/nginx/sites-enabled/sf-web.conf
            rm -f /etc/nginx/sites-available/sf-web.conf
        fi
    fi

    # فحص ufw وفتح بورت 8010 إن لزم
    if command -v ufw >/dev/null 2>&1; then
        ufw_status="$(ufw status 2>/dev/null | head -n1 || true)"
        if echo "$ufw_status" | grep -qi "active"; then
            if ! ufw status | grep -q "8010/tcp"; then
                log "🔓 فتح بورت 8010 في ufw ..."
                ufw allow 8010/tcp || log "⚠️ تعذر إضافة قاعدة ufw لبورت 8010"
            else
                log "✅ ufw يحتوي بالفعل على قاعدة لبورت 8010"
            fi
        else
            log "ℹ️ ufw غير مفعل (inactive)، لا حاجة لتعديل قواعد الجدار الناري."
        fi
    else
        log "ℹ️ ufw غير موجود، سيتم الاعتماد على إعدادات الجدار الناري الأخرى (إن وجدت)."
    fi

    log "ℹ️ يفترض الآن إمكانية الوصول إلى sf-web من الخارج عبر:"
    log "   http://SERVER_IP:8010/"
fi

SECTION "4) تقرير Git عن /opt/smartfriend-suite (للتأكد من توثيق التعديلات)"

if [ -d /opt/smartfriend-suite/.git ]; then
    log "✅ /opt/smartfriend-suite هو مستودع Git، عرض الحالة المختصرة:"
    (
        cd /opt/smartfriend-suite
        echo "---- git status -sb ----"
        git status -sb || true
        echo
        echo "---- التغييرات في مجلد web/app فقط (diff --stat) ----"
        git diff --stat -- apps/web web || true
    )
else
    log "ℹ️ /opt/smartfriend-suite ليس مستودع Git (أو .git غير موجود)، تخطي تقرير Git."
fi

SECTION "5) تنبيه بخصوص بيئة Python (pip على النظام)"

log "ملاحظة:"
log "- تم استخدام pip على مستوى النظام، وده ممكن يعمل تضارب حزم مع apt."
log "- يُفضّل لاحقًا إنشاء virtualenv مخصص للسيوت (مثلاً: /opt/smartfriend-suite/venv)"
log "- وتشغيل خدمات sf-* باستخدام الـ venv لتفادي تضارب النسخ."

SECTION "انتهى الفحص الشامل لدكتور السيوت"
log "يمكنك الآن تجربة الوصول إلى:"
log "- sf-web داخلياً:   http://127.0.0.1:8390/"
log "- sf-web من الخارج (بعد ضبط الجدار الناري): http://SERVER_IP:8010/"
