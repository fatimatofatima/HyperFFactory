#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

STAMP="$(date +%Y%m%d_%H%M%S)"
DIAG_DIR="/opt/smartfriend-suite/logs/diag"
mkdir -p "$DIAG_DIR"

SUMMARY_BOTS_PROBLEMS=""
SUMMARY_RESTARTED=""
SUMMARY_FAILED_RESTART=""

is_bot_service() {
    case "$1" in
        *telegram*|*bot*|*smartfrind-bot*|*sf-smartfrind.service*|*sf-smartfriend.service*|*sf-smartfactory.service*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

diag_service() {
    svc="$1"

    active_state="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"
    failed_state="$(systemctl is-failed "$svc" 2>/dev/null || echo "unknown")"

    log "فحص الخدمة: $svc (active=$active_state, failed=$failed_state)"

    # لو الخدمة شغالة ومش failed نكتفي بالفحص
    if [ "$active_state" = "active" ] && [ "$failed_state" != "failed" ]; then
        success "الخدمة $svc تعمل بشكل طبيعي."
        return 0
    fi

    diag_file="$DIAG_DIR/${svc}_${STAMP}.log"
    if ! journalctl -xeu "$svc" -n 80 &>"$diag_file"; then
        warn "تعذّر قراءة journalctl لـ $svc – ربما لا يوجد لوج."
    else
        log "تم حفظ لوج $svc في: $diag_file"
    fi

    # تحليل الأخطاء الشائعة
    invalid_token=0
    unset_token=0
    other_error=""

    if grep -q 'InvalidToken' "$diag_file" 2>/dev/null; then
        invalid_token=1
    fi
    if grep -q 'TG_BOT_TOKEN غير مضبوط' "$diag_file" 2>/dev/null; then
        unset_token=1
    fi

    if [ $invalid_token -eq 1 ] || [ $unset_token -eq 1 ]; then
        # دي خدمات تيليجرام ببوت مكسور – نوقفها ونبلّغ المستخدم يعدّل التوكن
        warn "تم اكتشاف مشكلة في توكن تيليجرام داخل الخدمة $svc."
        if [ $invalid_token -eq 1 ]; then
            warn "النوع: InvalidToken (التوكن مرفوض من تيليجرام)."
            SUMMARY_BOTS_PROBLEMS="${SUMMARY_BOTS_PROBLEMS}- $svc: InvalidToken – أوقفنا الخدمة، عدّل التوكن ثم شغّلها يدويًا.\n"
        fi
        if [ $unset_token -eq 1 ]; then
            warn "النوع: TG_BOT_TOKEN غير مضبوط في البيئة."
            SUMMARY_BOTS_PROBLEMS="${SUMMARY_BOTS_PROBLEMS}- $svc: TG_BOT_TOKEN غير مضبوط – أوقفنا الخدمة، اضبط المتغير ثم شغّلها يدويًا.\n"
        fi

        # إيقاف الخدمة عشان نوقف إعادة التشغيل اللانهائي
        if systemctl is-active "$svc" &>/dev/null; then
            systemctl stop "$svc" || true
            warn "تم إيقاف الخدمة $svc مؤقتًا لمنع loop إعادة التشغيل."
        fi
        return 0
    fi

    # لو مش بوت تيليجرام لكن في حالة failed نحاول restart
    if [ "$failed_state" = "failed" ]; then
        if is_bot_service "$svc"; then
            # بوت بدون InvalidToken واضح – ما نغامرش، نكتفي بالتشخيص
            warn "الخدمة $svc بوت تيليجرام فاشل بدون InvalidToken صريح – راجع اللوج يدويًا: $diag_file"
            SUMMARY_BOTS_PROBLEMS="${SUMMARY_BOTS_PROBLEMS}- $svc: فشل بوت تيليجرام – راجع $diag_file يدويًا.\n"
            return 0
        fi

        warn "الخدمة $svc في حالة failed – سيتم محاولة إعادة التشغيل مرة واحدة..."
        if systemctl restart "$svc" 2>/dev/null; then
            sleep 2
            new_state="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"
            if [ "$new_state" = "active" ]; then
                success "تم إصلاح الخدمة $svc (active بعد restart)."
                SUMMARY_RESTARTED="${SUMMARY_RESTARTED}- $svc: تم إعادة التشغيل بنجاح.\n"
            else
                warn "الخدمة $svc ما زالت ليست active بعد restart (state=$new_state). راجع: $diag_file"
                SUMMARY_FAILED_RESTART="${SUMMARY_FAILED_RESTART}- $svc: فشل restart – راجع $diag_file.\n"
            fi
        else
            error "فشل تشغيل systemctl restart لـ $svc – راجع: $diag_file"
            SUMMARY_FAILED_RESTART="${SUMMARY_FAILED_RESTART}- $svc: خطأ عند محاولة restart (systemctl).\n"
        fi
    else
        # حالات activating/inactive – نكتفي بالتشخيص وعدم العبث
        warn "الخدمة $svc ليست failed (active=$active_state, failed=$failed_state) – تم الاكتفاء بالتشخيص فقط."
    fi
}

log "=== SmartFriend Suite Doctor – فحص وإصلاح أساسي للخدمات ==="
echo

# تجميع قائمة كل خدمات السيوت (service units فقط)
log "جمع قائمة خدمات sf-*/smartfrind-*/smartfriend-* من systemd..."
mapfile -t SF_SERVICES < <(
  systemctl list-units --type=service 'sf-*' 'smartfrind-*' 'smartfriend-*' --all --no-legend \
    | awk '{print $1}' | sort -u
)

if [ "${#SF_SERVICES[@]}" -eq 0 ]; then
    error "لم يتم العثور على أي خدمات تبدأ بـ sf-* أو smartfrind-* أو smartfriend-*."
    exit 1
fi

log "تم العثور على ${#SF_SERVICES[@]} خدمة تابعة للسيوت:"
for s in "${SF_SERVICES[@]}"; do
    echo " - $s"
done
echo

log "بدء الفحص التفصيلي لكل خدمة..."
echo

for svc in "${SF_SERVICES[@]}"; do
    diag_service "$svc"
    echo
done

echo
log "=== ملخص ما تم ==="

if [ -n "$SUMMARY_BOTS_PROBLEMS" ]; then
    echo -e "${YELLOW}❗ مشاكل بوتات تيليجرام (تحتاج تعديل توكن/متغيرات يدويًا):${NC}"
    echo -e "$SUMMARY_BOTS_PROBLEMS"
else
    success "لا توجد أخطاء توكن تيليجرام مكتشفة في هذه الجولة."
fi

if [ -n "$SUMMARY_RESTARTED" ]; then
    echo -e "${GREEN}✅ الخدمات التي تم إعادة تشغيلها بنجاح:${NC}"
    echo -e "$SUMMARY_RESTARTED"
fi

if [ -n "$SUMMARY_FAILED_RESTART" ]; then
    echo -e "${RED}⚠️ الخدمات التي ما زالت تحتاج تدخل يدوي بعد فشل restart:${NC}"
    echo -e "$SUMMARY_FAILED_RESTART"
fi

echo
log "تم حفظ جميع لوجات التشخيص في: $DIAG_DIR (بتاريخ $STAMP)"
log "انتهى الفحص الأساسي. راجع الملخص أعلاه ثم عدّل التوكنات/الإعدادات حسب الحاجة."
