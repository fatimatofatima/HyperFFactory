#!/usr/bin/env bash
# HyperFFactory – تكامل سريع مع تقارير حالة

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/hf_quick_integration_${STAMP}.log"

log() {
    printf '%s %s\n' "$(date -Iseconds)" "$*"
}

echo "==========================================================="
echo "== HF QUICK INTEGRATION & STATUS REPORT"
echo "==========================================================="
echo "TIME: $(date)"
echo "ROOT: $ROOT"
echo "LOG:  $LOG_FILE"
echo "==========================================================="

# 1. فحص الخدمات الأساسية
log "🔧 فحص خدمات SmartFriend..."
services=("sf-web" "sf-core" "sf-health" "sf-memory")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log "✅ $service: نشطة"
    else
        log "❌ $service: غير نشطة"
    fi
done

# 2. فحص المنافذ
log "🔌 فحص المنافذ..."
ports=("8390" "8383" "8215" "8214")
for port in "${ports[@]}"; do
    if ss -tulpn | grep -q ":$port "; then
        log "✅ منفذ $port: مفتوح"
    else
        log "❌ منفذ $port: مغلق"
    fi
done

# 3. فحص الهيكل الموحد
log "📁 فحص الهيكل الموحد..."
if [ -d "/root/HyperFFactory" ]; then
    log "✅ /root/HyperFFactory: موجود"
else
    log "❌ /root/HyperFFactory: غير موجود"
fi

if [ -d "/opt/smartfriend-suite" ]; then
    log "✅ /opt/smartfriend-suite: موجود"
else
    log "❌ /opt/smartfriend-suite: غير موجود"
fi

# 4. اختبار HTTP سريع
log "🌐 اختبار HTTP سريع..."
endpoints=("http://127.0.0.1:8390/health" "http://127.0.0.1:8383/health" "http://127.0.0.1:8215/health")
for endpoint in "${endpoints[@]}"; do
    if curl -s --connect-timeout 5 "$endpoint" >/dev/null; then
        log "✅ $endpoint: متاح"
    else
        log "❌ $endpoint: غير متاح"
    fi
done

# 5. تقرير المساحة
log "💾 مساحة التخزين السريعة..."
du -sh /root/HyperFFactory /opt/smartfriend-suite 2>/dev/null | while read size path; do
    log "📦 $size - $path"
done

echo "==========================================================="
echo "✅ التكامل السريع اكتمل"
echo "📄 التفاصيل في: $LOG_FILE"
echo "==========================================================="
