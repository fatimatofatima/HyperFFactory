#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

REPORT_DIR="/root/sf_migration"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/sf_services_audit_$(date +%Y%m%d_%H%M%S).txt"

log() { echo "$@" | tee -a "$REPORT_FILE"; }

log "=================================================="
log "   🧩 SmartFrind / SmartFriend Services Audit"
log "=================================================="
log "الوقت: $(date)"
log "=================================================="

# نجمع كل الوحدات اللي تبدأ بـ smartfriend / smartfrind
log ""
log "1) قائمة الوحدات:"
log "------------------"
UNITS=$(systemctl list-unit-files 'smartfriend*' 'smartfrind*' --no-legend 2>/dev/null | awk '{print $1}' | sort -u || true)

if [ -z "$UNITS" ]; then
    log "لا توجد وحدات smartfriend/smartfrind مسجلة."
    exit 0
fi

for u in $UNITS; do
    log " - $u"
done

log ""
log "2) تفاصيل كل خدمة:"
log "------------------"

for u in $UNITS; do
    log ""
    log "=================================================="
    log "🔹 الوحدة: $u"
    log "=================================================="

    # ملخص سريع لحالة الخدمة
    systemctl show "$u" \
        -p Id -p Description -p LoadState -p ActiveState -p SubState \
        -p UnitFileState -p FragmentPath -p Type -p User -p Group \
        -p ExecStart -p WorkingDirectory -p Restart \
        2>/dev/null | tee -a "$REPORT_FILE" || log "⚠️ فشل systemctl show لـ $u"

    log ""
    log "--- systemctl status $u (مختصر) ---"
    systemctl status "$u" --no-pager 2>&1 | sed -e 's/\x1b\[[0-9;]*m//g' | tee -a "$REPORT_FILE" || log "⚠️ فشل systemctl status لـ $u"

done

log ""
log "🕒 وقت انتهاء فحص الخدمات: $(date)"
log "تقرير الخدمات محفوظ في: $REPORT_FILE"
