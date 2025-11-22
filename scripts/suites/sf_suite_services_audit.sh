#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()      { echo -e "[$(date '+%F %T')] $*"; }
section()  { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()     { echo -e "${CYAN}ℹ️  $*${NC}"; }
warning()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
error()    { echo -e "${RED}❌ $*${NC}"; }
success()  { echo -e "${GREEN}✅ $*${NC}"; }

main() {
    section "1) البحث عن كل وحدات systemd التي تشير إلى ${APP_ROOT} (بدون ff)"
    mapfile -t UNIT_FILES < <(grep -Rl "${APP_ROOT}" /etc/systemd/system /lib/systemd/system 2>/dev/null | sort -u || true)

    if [ "${#UNIT_FILES[@]}" -eq 0 ]; then
        warning "لا توجد وحدات systemd تشير إلى ${APP_ROOT}"
        exit 0
    fi

    declare -A SEEN
    UNITS=()

    for f in "${UNIT_FILES[@]}"; do
        base="$(basename "$f")"
        case "$base" in
            *.service|*.timer) ;;
            *) continue ;;
        esac

        # استبعاد خدمات ff / ffactory / ff_*
        case "$base" in
            ff*|ffactory*|ff_* )
                continue
                ;;
        esac

        # إزالة .service/.timer للصيغة القياسية
        unit_name="$base"
        SEEN["$unit_name"]=1
    done

    if [ "${#SEEN[@]}" -eq 0 ]; then
        warning "لم يتم العثور على وحدات تخص السويت غير ff."
        exit 0
    fi

    for k in "${!SEEN[@]}"; do
        UNITS+=("$k")
    done

    IFS=$'\n' UNITS=($(sort <<<"${UNITS[*]}"))
    unset IFS

    section "2) قائمة الوحدات المرتبطة بالسويت (بدون ff)"
    for u in "${UNITS[@]}"; do
        echo " - $u"
    done

    section "3) ملخص سريع لحالة كل وحدة"
    ACTIVE_OK=0
    ACTIVE_FAILED=0
    ACTIVE_INACTIVE=0

    for u in "${UNITS[@]}"; do
        state="$(systemctl is-active "$u" 2>/dev/null || echo "unknown")"
        sub="$(systemctl is-failed "$u" 2>/dev/null || echo "n/a")"

        case "$state" in
            active)
                ACTIVE_OK=$((ACTIVE_OK+1))
                ;;
            failed)
                ACTIVE_FAILED=$((ACTIVE_FAILED+1))
                ;;
            inactive)
                ACTIVE_INACTIVE=$((ACTIVE_INACTIVE+1))
                ;;
        esac

        printf "%-35s  state=%-10s  failed=%s\n" "$u" "$state" "$sub"
    done

    echo
    success "إحصائيات:"
    echo "  active   : $ACTIVE_OK"
    echo "  inactive : $ACTIVE_INACTIVE"
    echo "  failed   : $ACTIVE_FAILED"

    section "4) systemctl list-unit-files للوحدات المستهدفة"
    for u in "${UNITS[@]}"; do
        info "unit-file: $u"
        systemctl list-unit-files "$u" --no-pager || warning "فشل قراءة list-unit-files لـ $u"
    done

    section "5) systemctl status (أول 15 سطر) لكل وحدة"
    for u in "${UNITS[@]}"; do
        info "status: $u"
        systemctl status "$u" --no-pager -l | sed -n '1,15p' || warning "فشل قراءة status لـ $u"
        echo
    done

    section "6) journalctl -u (آخر 20 سطر) لكل وحدة"
    for u in "${UNITS[@]}"; do
        info "journalctl -u $u (آخر 20 سطر)"
        journalctl -u "$u" -n 20 --no-pager || warning "فشل قراءة journal لـ $u"
        echo
    done

    success "انتهى فحص خدمات السويت المرتبطة بـ ${APP_ROOT} بدون المساس بأي ff*."
}

main "$@"
