#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
ok()   { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }

REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/sf_legacy_rebrand_into_suite_$(date +%Y%m%d_%H%M%S).log"

teeout(){ tee -a "$REPORT"; }

UNIT_DIR="/etc/systemd/system"

log "=== SmartFriend Suite – توحيد تسمية smartfrind-* وربطها رسميًا بالسيوت + تحديث مسارات DB ===" | teeout
echo | teeout

cd "$UNIT_DIR"

# جمع كل وحدات smartfrind-*.service
mapfile -t UNITS < <(systemctl list-unit-files 'smartfrind-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)

if [ "${#UNITS[@]}" -eq 0 ]; then
    warn "لا توجد وحدات smartfrind-*.service مسجّلة في systemd" | teeout
    exit 0
fi

log "الوحدات المستهدفة:" | teeout
for u in "${UNITS[@]}"; do
    echo "  - $u" | teeout
done
echo | teeout

# مجلد نسخ احتياطية
BACKUP_DIR="/root/sf_unit_backups/legacy_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

skip_unit() {
    local u="$1"
    case "$u" in
        smartfrind-delta.sh.service|smartfrind-setup.sh.service)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

for u in "${UNITS[@]}"; do
    if skip_unit "$u"; then
        warn "تخطي وحدة إعداد/Delta (لا تُلمس تلقائيًا): $u" | teeout
        continue
    fi

    local_path="$UNIT_DIR/$u"
    if [ ! -f "$local_path" ]; then
        warn "ملف الوحدة غير موجود فعليًا (قد يكون من drop-in فقط): $u" | teeout
        continue
    fi

    log "معالجة الوحدة: $u" | teeout

    # نسخة احتياطية
    cp "$local_path" "$BACKUP_DIR/"
    ok "نسخة احتياطية → $BACKUP_DIR/$u" | teeout

    # 1) توحيد الوصف Description كجزء من السيوت
    if grep -q '^Description=' "$local_path"; then
        sed -i 's/^Description=.*/Description=SmartFriend Suite - Legacy service/' "$local_path"
        ok "تحديث Description -> SmartFriend Suite - Legacy service" | teeout
    else
        tmp_file="${local_path}.tmp_desc"
        {
            echo "Description=SmartFriend Suite - Legacy service"
            cat "$local_path"
        } > "$tmp_file"
        mv "$tmp_file" "$local_path"
        ok "إضافة Description جديد في أعلى الملف" | teeout
    fi

    # 2) توحيد مسار قاعدة البيانات إلى المسار الرسمي في السيوت
    sed -i 's#/opt/smartfriend-suite/data/db/smartfriend_unified.db#/opt/smartfriend-suite/var/db/smartfriend_unified.db#g' "$local_path" || true
    sed -i 's#/opt/smartfriend-suite/data/smartfriend_unified.db#/opt/smartfriend-suite/var/db/smartfriend_unified.db#g' "$local_path" || true
    sed -i 's#/opt/smartfrind/data/db/smartfriend_unified.db#/opt/smartfriend-suite/var/db/smartfriend_unified.db#g' "$local_path" || true
    sed -i 's#/opt/smartfrind/data/smartfriend_unified.db#/opt/smartfriend-suite/var/db/smartfriend_unified.db#g' "$local_path" || true

    ok "تحديث مسارات DB (إن وجدت) إلى المسار الرسمي في السيوت" | teeout
    echo | teeout
done

log "إعادة تحميل systemd بعد التعديلات..." | teeout
systemctl daemon-reload
ok "تم daemon-reload" | teeout

# إعادة تفعيل وتشغيل الوحدات بعد إعادة التسميات/المسارات
log "إعادة تفعيل وتشغيل وحدات smartfrind-* (ما عدا وحدات الإعداد)..." | teeout
for u in "${UNITS[@]}"; do
    if skip_unit "$u"; then
        continue
    fi

    if systemctl enable "$u" >>"$REPORT" 2>&1; then
        ok "enable للوحدة: $u" | teeout
    else
        warn "فشل enable للوحدة: $u" | teeout
    fi

    if systemctl restart "$u" >>"$REPORT" 2>&1; then
        ok "restart للوحدة: $u" | teeout
    else
        warn "فشل restart للوحدة: $u" | teeout
    fi
done

echo | teeout
log "تشغيل تقرير sf_complete_status.sh إن وُجد لعرض الصورة الكاملة بعد الدمج..." | teeout

if [ -x /root/sf_complete_status.sh ]; then
    bash /root/sf_complete_status.sh | tee -a "$REPORT" || warn "فشل تشغيل sf_complete_status.sh" | teeout
else
    warn "/root/sf_complete_status.sh غير موجود أو غير تنفيذي – تم التخطي." | teeout
fi

echo | teeout
ok "اكتمل توحيد التسمية والربط بالسيوت. التقرير في: $REPORT" | teeout
