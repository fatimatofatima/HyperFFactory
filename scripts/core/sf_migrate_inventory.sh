#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

echo "=================================================="
echo "   📋 جرد شامل لـ SmartFrind (المرحلة 1 - Inventory)"
echo "=================================================="
echo "الوقت: $(date)"
echo "=================================================="

# إنشاء مجلد التقارير
REPORT_DIR="/root/sf_migration"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/smartfrind_inventory_$(date +%Y%m%d_%H%M%S).txt"

# دالة للتسجيل في التقرير
log() {
    echo "$1" | tee -a "$REPORT_FILE"
}

log "🕒 وقت بدء الجرد: $(date)"
log "=================================================="

############################################
# 1) مسارات smartfrind / smartfriend
############################################
log ""
log "1. 📁 مسارات SmartFrind / SmartFriend الموجودة:"
log "==============================================="

SMART_DIRS="$(find /opt /var /srv \
  -maxdepth 6 -type d \
  \( -iname "smartfrind*" -o -iname "smartfriend*" \) 2>/dev/null | sort -u || true)"

if [ -n "$SMART_DIRS" ]; then
    echo "$SMART_DIRS" | while read -r d; do
        [ -z "$d" ] && continue
        size="$(du -sh "$d" 2>/dev/null | awk '{print $1}')"
        log "   📂 $d (${size:-?})"
    done
else
    log "   لا توجد مسارات مطابقة حالياً."
fi

############################################
# 2) خدمات systemd المرتبطة
############################################
log ""
log "2. 🔧 خدمات Systemd المرتبطة بـ SmartFrind:"
log "==========================================="

SERVICES="$(systemctl list-unit-files 'smartfrind*' 'smartfriend*' --no-legend 2>/dev/null | awk '{print $1}' | sort -u || true)"

if [ -n "$SERVICES" ]; then
    while read -r service; do
        [ -z "$service" ] && continue
        enabled="$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")"
        active="$(systemctl is-active "$service" 2>/dev/null || echo "unknown")"
        log "   ⚙️  $service - التمكين: $enabled - النشاط: $active"
    done <<< "$SERVICES"
else
    log "   لا توجد وحدات systemd باسم smartfrind* أو smartfriend*."
fi

############################################
# 3) قواعد البيانات ذات الصلة
############################################
log ""
log "3. 🗃️ قواعد البيانات المرتبطة بـ SmartFrind:"
log "==========================================="

DBS="$(find /var/lib /var/backups /opt \
  -maxdepth 6 -type f \
  \( -iname "*smartfrind*.db" -o -iname "*smartfriend*.db" -o -iname "smart_memory.db" \) 2>/dev/null | sort -u || true)"

if [ -n "$DBS" ]; then
    COUNT="$(printf '%s\n' "$DBS" | sed '/^$/d' | wc -l)"
    log "   عدد الملفات: $COUNT"
    echo "$DBS" | while read -r db; do
        [ -z "$db" ] && continue
        size="$(du -h "$db" 2>/dev/null | awk '{print $1}')"
        log "   🗃️  $db (${size:-?})"
    done
else
    log "   لا توجد ملفات قواعد بيانات smartfrind*.db حالياً."
fi

############################################
# 4) بيئات Python الافتراضية (venv)
############################################
log ""
log "4. 🐍 بيئات Python (venv) المرتبطة بـ SmartFrind:"
log "================================================="

VENVS="$(find /opt /srv \
  -maxdepth 6 -type d \
  \( -name ".venv" -o -name "venv" \) \
  -path "*smartfrind*" 2>/dev/null | sort -u || true)"

if [ -n "$VENVS" ]; then
    echo "$VENVS" | while read -r v; do
        [ -z "$v" ] && continue
        size="$(du -sh "$v" 2>/dev/null | awk '{print $1}')"
        log "   🐍 $v (${size:-?})"
    done
else
    log "   لا توجد venvs مرتبطة بـ smartfrind ضمن /opt أو /srv."
fi

############################################
# 5) ملاحظات ختامية
############################################
log ""
log "🕒 وقت انتهاء الجرد: $(date)"
log "=================================================="

echo
echo "✅ تم إنشاء تقرير الجرد في:"
echo "   $REPORT_FILE"
