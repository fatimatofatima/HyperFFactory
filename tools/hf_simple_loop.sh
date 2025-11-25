#!/usr/bin/env bash
# HyperFFactory – حلقة مراقبة مبسّطة للخدمات والحاويات

set -Eeuo pipefail

INTERVAL="${1:-60}"  # الفترة بين كل دورة بالثواني (افتراضي 60 ثانية)

echo "🔄 بدء حلقة المراقبة البسيطة (كل ${INTERVAL} ثانية) – اضغط Ctrl+C للإيقاف"
echo

while true; do
    echo "============================================================"
    echo "=== $(date) ==="
    echo "============================================================"

    echo "🔧 حالة خدمات SmartFriend (systemd):"
    for svc in sf-core sf-web sf-health sf-memory; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
            if systemctl is-active "${svc}.service" >/dev/null 2>&1; then
                echo "  ✅ ${svc}.service : active"
            else
                echo "  ❌ ${svc}.service : NOT active"
            fi
        else
            echo "  ℹ️ ${svc}.service غير معرّف على هذا السيرفر (skip)"
        fi
    done

    echo
    echo "🌐 فحوصات HTTP /health السريعة:"
    # نستخدم curl إن وُجد، وإلا نطبع ملاحظة
    if command -v curl >/dev/null 2>&1; then
        curl -s -o /dev/null -w "  sf-core   (8383)  /health: HTTP %{http_code}\n"  http://127.0.0.1:8383/health || echo "  sf-core   (8383)  /health: ❌ اتصال فاشل"
        curl -s -o /dev/null -w "  sf-memory (8214)  /health: HTTP %{http_code}\n" http://127.0.0.1:8214/health || echo "  sf-memory (8214)  /health: ❌ اتصال فاشل"
        curl -s -o /dev/null -w "  sf-web    (8390)  /health: HTTP %{http_code}\n" http://127.0.0.1:8390/health || echo "  sf-web    (8390)  /health: ❌ اتصال فاشل"
        curl -s -o /dev/null -w "  sf-health (8215)  /health: HTTP %{http_code}\n" http://127.0.0.1:8215/health || echo "  sf-health (8215)  /health: ❌ اتصال فاشل"
    else
        echo "  ⚠️ curl غير متوفر – لن يتم فحص /health عبر HTTP."
    fi

    echo
    echo "🐋 ملخص سريع لحاويات Docker (hyper_* / ffactory-*):"
    if command -v docker >/dev/null 2>&1; then
        # نطبع فقط الحاويات ذات الأسماء المرتبطة بالنظام
        if ! docker ps --format '  {{.Names}}  {{.Status}}' | grep -E 'hyper_|ffactory' ; then
            echo "  (لا توجد حاويات hyper_/ffactory شغّالة حاليًا أو docker ps فارغ لهذه الفلترة)"
        fi
    else
        echo "  ⚠️ docker غير متوفر أو غير في PATH – تخطي فحص الحاويات."
    fi

    echo
    echo "⏲️ النوم ${INTERVAL} ثانية قبل الدورة التالية..."
    sleep "${INTERVAL}"
done
