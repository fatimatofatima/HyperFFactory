#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان للتنسيق
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

STAMP="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="/root/sf_reports/${STAMP}"
mkdir -p "$REPORT_DIR"

is_bot_service() {
    case "$1" in
        *bot*|*telegram* )
            return 0 ;;
        *sf-telegram*|*sf-bot* )
            return 0 ;;
        *)
            return 1 ;;
    esac
}

log "=== SmartFriend Suite – فحص/إصلاح/تشغيل شامل للخدمات ==="
echo

# 0) عرض ملخص سريع لحالة الخدمات قبل الإصلاح
log "0️⃣ ملخص سريع قبل الإصلاح:"
echo "— الخدمات النشطة الآن (أول 20 سطر):"
systemctl list-units --type=service --state=running --no-pager | head -20
echo

echo "— الخدمات الفاشلة الحالية (كل النظام):"
systemctl list-units --type=service --state=failed --no-pager || true
echo

# 1) تجميع الخدمات الفاشلة الخاصة بالسيوت فقط
log "1️⃣ جمع قائمة الخدمات الفاشلة داخل نطاق السيوت (sf-*, smartfrind-*, smartfriend-*)..."

mapfile -t FAILED_SERVICES < <(
  systemctl list-units --type=service --state=failed --no-legend --no-pager \
    | awk '{print $1}' \
    | grep -E '^(sf-|smartfrind-|smartfriend-)' \
    | sort -u
)

if [ "${#FAILED_SERVICES[@]}" -eq 0 ]; then
    success "لا توجد خدمات فاشلة حاليًا داخل نطاق السيوت."
    exit 0
fi

warn "الخدمات الفاشلة المكتشفة:"
i=1
for s in "${FAILED_SERVICES[@]}"; do
    echo "  $i) $s"
    i=$((i+1))
done
echo

# متغيرات للملخص النهائي
FIXED_SERVICES=""
SKIPPED_SERVICES=""
STILL_FAILED_SERVICES=""
TELEGRAM_ISSUES=""

# 2) تشخيص وإصلاح كل خدمة فاشلة
for svc in "${FAILED_SERVICES[@]}"; do
    echo
    echo "---------------------------------------------------"
    echo "📌 الخدمة: $svc"
    echo "---------------------------------------------------"

    STATUS_FILE="${REPORT_DIR}/${svc}_status.log"
    JOURNAL_FILE="${REPORT_DIR}/${svc}_journal.log"

    # حفظ systemctl status
    if systemctl status "$svc" --no-pager -l > "$STATUS_FILE" 2>&1; then
        log "تم حفظ systemctl status في: $STATUS_FILE"
    else
        warn "تعذر الحصول على systemctl status لـ $svc"
    fi

    # حفظ آخر 80 سطر من journalctl
    if journalctl -u "$svc" -n 80 --no-pager > "$JOURNAL_FILE" 2>&1; then
        log "تم حفظ journalctl -n80 في: $JOURNAL_FILE"
    else
        warn "تعذر الحصول على journalctl لـ $svc"
    fi

    # تحليل اللوج لاكتشاف أخطاء التليجرام/التوكن
    invalid_token=0
    token_problem=0

    if grep -qi 'InvalidToken' "$JOURNAL_FILE" 2>/dev/null; then
        invalid_token=1
    fi
    if grep -qi 'TELEGRAM_BOT_TOKEN' "$JOURNAL_FILE" 2>/dev/null; then
        token_problem=1
    fi

    if is_bot_service "$svc" && { [ "$invalid_token" -eq 1 ] || [ "$token_problem" -eq 1 ]; }; then
        warn "تم اكتشاف مشكلة توكن/تيليجرام في الخدمة: $svc"
        warn "سيتم إيقافها مؤقتًا لمنع loop إعادة التشغيل – مطلوب تعديل التوكن يدويًا ثم تشغيلها يدويًا."

        systemctl stop "$svc" 2>/dev/null || true

        TELEGRAM_ISSUES+="- $svc: مشكلة في توكن تيليجرام (راجع: $STATUS_FILE / $JOURNAL_FILE)\n"
        SKIPPED_SERVICES+="- $svc (بوت تيليجرام – تم إيقافه، يحتاج تعديل توكن يدويًا)\n"
        continue
    fi

    # لو ليست بوت متأكد منه – نحاول Restart
    warn "محاولة إعادة تشغيل الخدمة: $svc ..."
    if systemctl restart "$svc" 2>>"$STATUS_FILE"; then
        sleep 2
        new_state="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"
        if [ "$new_state" = "active" ]; then
            success "تم إصلاح وتشغيل $svc (state=active)."
            FIXED_SERVICES+="- $svc\n"
        else
            warn "ما زالت الخدمة ليست active بعد restart (state=$new_state) – تحتاج مراجعة يدوية."
            STILL_FAILED_SERVICES+="- $svc (state=$new_state – راجع: $STATUS_FILE / $JOURNAL_FILE)\n"
        fi
    else
        error "فشل systemctl restart لـ $svc – راجع التقارير."
        STILL_FAILED_SERVICES+="- $svc (فشل restart – راجع: $STATUS_FILE / $JOURNAL_FILE)\n"
    fi
done

echo
log "3️⃣ ملخص بعد محاولة الإصلاح:"

if [ -n "$FIXED_SERVICES" ]; then
    echo -e "${GREEN}🟢 الخدمات التي تم تشغيلها بنجاح:${NC}"
    echo -e "$FIXED_SERVICES"
fi

if [ -n "$TELEGRAM_ISSUES" ]; then
    echo -e "${YELLOW}🤖 خدمات بوت/تيليجرام بها مشاكل توكن (تحتاج تعديل يدوي):${NC}"
    echo -e "$TELEGRAM_ISSUES"
fi

if [ -n "$STILL_FAILED_SERVICES" ]; then
    echo -e "${RED}🔴 خدمات ما زالت تحتاج تدخل يدوي بعد محاولة الإصلاح:${NC}"
    echo -e "$STILL_FAILED_SERVICES"
fi

if [ -z "$FIXED_SERVICES" ] && [ -z "$TELEGRAM_ISSUES" ] && [ -z "$STILL_FAILED_SERVICES" ]; then
    warn "لم يتم تعديل أي حالة – راجع التقارير يدويًا."
fi

echo
log "4️⃣ حالة الخدمات الفاشلة الآن (بعد الإصلاح):"
systemctl list-units --type=service --state=failed --no-pager | grep -E '^(sf-|smartfrind-|smartfriend-)' || true

echo
log "📁 تم حفظ كل تقارير التشخيص في: $REPORT_DIR"
log "استخدم مثلاً:  less ${REPORT_DIR}/sf-backup.service_status.log  لمراجعة خدمة معينة."
success "انتهى سكربت الفحص/الإصلاح/التشغيل."
