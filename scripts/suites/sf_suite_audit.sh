#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان بسيطة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_ROOT="/opt/smartfriend-suite"

section() { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()    { echo -e "${CYAN}[*] $*${NC}"; }
ok()      { echo -e "${GREEN}[✓] $*${NC}"; }
warn()    { echo -e "${YELLOW}[!] $*${NC}"; }
bad()     { echo -e "${RED}[✗] $*${NC}"; }

main() {
    shopt -s nullglob

    section "تهيئة الفحص"
    echo "APP_ROOT = ${APP_ROOT}"
    echo "نطاق الخدمات: sf-*.service + smartfrind-*.service من /etc/systemd/system"

    local service_files=(
        /etc/systemd/system/sf-*.service
        /etc/systemd/system/smartfrind-*.service
    )

    if [ ${#service_files[@]} -eq 0 ]; then
        bad "لا توجد خدمات sf-* أو smartfrind-* في /etc/systemd/system/"
        exit 0
    fi

    local total=0 ok_count=0 ff_count=0 foreign_opt_count=0 nowd_count=0

    section "فحص كل خدمة"
    for file in "${service_files[@]}"; do
        [ -f "$file" ] || continue
        total=$((total+1))

        local name
        name="$(basename "$file")"

        # استخراج WorkingDirectory و ExecStart
        local wd_lines exec_lines
        wd_lines="$(grep -E '^WorkingDirectory=' "$file" || true)"
        exec_lines="$(grep -E '^ExecStart=' "$file" || true)"

        local has_wd=false
        local touch_ffactory=false
        local touch_foreign_opt=false

        if [[ -n "$wd_lines" ]]; then
            has_wd=true
        fi

        # نبحث عن أي إشارة لـ /opt/ffactory
        if grep -q '/opt/ffactory' "$file"; then
            touch_ffactory=true
        fi

        # أي مسار /opt/ ليس smartfriend-suite ولا ffactory = FOREIGN_OPT
        if grep -E '/opt/' "$file" | grep -v '/opt/smartfriend-suite' | grep -v '/opt/ffactory' >/dev/null 2>&1; then
            touch_foreign_opt=true
        fi

        # تصنيف الحالة
        local status=""
        if "$touch_ffactory"; then
            status="FFACTORY"
            ff_count=$((ff_count+1))
        elif "$touch_foreign_opt"; then
            status="FOREIGN_OPT"
            foreign_opt_count=$((foreign_opt_count+1))
        else
            status="LOCAL"
            ok_count=$((ok_count+1))
        fi

        if ! "$has_wd"; then
            status="${status}+NO_WD"
            nowd_count=$((nowd_count+1))
        fi

        # طباعة مختصرة
        case "$status" in
            LOCAL)
                ok "خدمة محلية داخل السويت: $name"
                ;;
            LOCAL+NO_WD)
                warn "خدمة داخل السويت لكن بدون WorkingDirectory: $name"
                ;;
            FFACTORY*)
                bad "خدمة تلمس /opt/ffactory (خارج نطاقنا): $name"
                ;;
            FOREIGN_OPT*)
                warn "خدمة تلمس /opt/ خارج smartfriend-suite: $name"
                ;;
            *)
                warn "خدمة بحاجة مراجعة: $name (status=$status)"
                ;;
        esac

        # عرض محتوى مهم للخدمة
        echo "   ملف الخدمة: $file"
        if [[ -n "$wd_lines" ]]; then
            echo "   WorkingDirectory:"
            echo "      $wd_lines"
        else
            echo "   WorkingDirectory: (غير مُعرّف)"
        fi

        if [[ -n "$exec_lines" ]]; then
            echo "   ExecStart:"
            echo "$exec_lines" | sed 's/^/      /'
        else
            echo "   ExecStart: (غير موجود)"
        fi
    done

    section "ملخص الفحص"
    echo "إجمالي الخدمات المفحوصة:  $total"
    echo "خدمات LOCAL (داخل السويت فقط):        $ok_count"
    echo "خدمات تلمس /opt/ffactory:             $ff_count"
    echo "خدمات تلمس /opt/ خارج السويت/ffactory: $foreign_opt_count"
    echo "خدمات بدون WorkingDirectory:          $nowd_count"

    echo
    ok "الفحص قراءة فقط – لا يوجد أي تعديل على systemd ولا على ffactory"
}

main "$@"
