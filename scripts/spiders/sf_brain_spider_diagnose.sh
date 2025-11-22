#!/usr/bin/env bash
set -Eeuo pipefail

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

APP_ROOT="/opt/smartfriend-suite"
SCRIPTS_DIR="$APP_ROOT/scripts"
UNITS=(sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint)

main() {
    section "1) حالة خدمات Brain (systemctl status سريع)"
    for u in "${UNITS[@]}"; do
        info "خدمة: $u"
        systemctl status "$u" --no-pager -l | sed -n '1,15p' || warning "فشل قراءة حالة $u"
        echo
    done

    section "2) آخر لوج من journalctl لكل خدمة Brain"
    for u in "${UNITS[@]}"; do
        info "journalctl -u $u (آخر 20 سطر)"
        journalctl -u "$u" -n 20 --no-pager || warning "لا يوجد لوج لـ $u"
        echo
    done

    section "3) قراءة ملفات وحدات systemd للـ Brain (ExecStart بالكامل)"
    for u in "${UNITS[@]}"; do
        info "unit file: /etc/systemd/system/${u}.service"
        if [ -f "/etc/systemd/system/${u}.service" ]; then
            sed -n '1,80p' "/etc/systemd/system/${u}.service" | sed 's/^/    /'
        else
            warning "unit غير موجود: /etc/systemd/system/${u}.service"
        fi
        echo
    done

    section "4) فحص سكربتات Brain نفسها (وجود + صلاحيات + shebang)"
    if [ -d "$SCRIPTS_DIR" ]; then
        ls -ld "$APP_ROOT" "$SCRIPTS_DIR" 2>/dev/null || true
        echo
        for f in "$SCRIPTS_DIR"/sf_brain_*.sh; do
            [ -e "$f" ] || continue
            info "ملف: $f"
            ls -l "$f"
            echo "---- أول 5 أسطر ----"
            head -n 5 "$f"
            echo
        done
    else
        error "مجلد السكربتات غير موجود: $SCRIPTS_DIR"
    fi

    section "5) تجربة تشغيل سكربتات Brain يدويًا كمستخدم smartfriend-suite (بدون إصلاح)"
    for f in "$SCRIPTS_DIR"/sf_brain_*.sh; do
        [ -e "$f" ] || continue
        info "تشغيل تجريبي: $f (كمستخدم smartfriend-suite)"
        if id smartfriend-suite >/dev/null 2>&1; then
            sudo -u smartfriend-suite bash -lc "$f" >/tmp/brain_test_$(basename "$f").log 2>&1 || true
            echo "  • exit code = $?"
            echo "  • أول 10 أسطر من خروج السكربت:"
            sed -n '1,10p' "/tmp/brain_test_$(basename "$f").log" || true
        else
            warning "المستخدم smartfriend-suite غير موجود (لن يمكن محاكاة systemd)"
        fi
        echo
    done

    section "6) البحث عن خدمات السبيدر (sf-spider.*)"
    info "systemctl list-units 'sf-spider*'"
    systemctl list-units 'sf-spider*' --no-pager || warning "لا توجد وحدات تعمل باسم sf-spider* حالياً"
    echo

    info "systemctl list-unit-files 'sf-spider*'"
    systemctl list-unit-files 'sf-spider*' --no-pager || warning "لا توجد unit-files مسجلة باسم sf-spider*"
    echo

    if [ -f "/etc/systemd/system/sf-spider.service" ]; then
        info "محتوى /etc/systemd/system/sf-spider.service:"
        sed -n '1,80p' /etc/systemd/system/sf-spider.service | sed 's/^/    /'
        echo
    fi

    if [ -f "/etc/systemd/system/sf-spider.timer" ]; then
        info "محتوى /etc/systemd/system/sf-spider.timer:"
        sed -n '1,80p' /etc/systemd/system/sf-spider.timer | sed 's/^/    /'
        echo
    fi

    section "7) البحث عن كود السبيدر داخل /opt/smartfriend-suite"
    info "أول 30 نتيجة لملفات فيها كلمة spider ضمن السويت:"
    find "$APP_ROOT" -maxdepth 8 \( -iname '*spider*.py' -o -iname '*spider*.sh' -o -iname '*spider*' \) 2>/dev/null | head -n 30

    echo
    success "انتهى فحص Brain + Spider. استخدم النتائج قبل أي تعديل أو إصلاح."
}

main "$@"
