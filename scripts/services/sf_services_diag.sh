#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C

PATTERN='^(sf-|smartfriend|smartfrind)'
SUITE_ROOT="/opt/smartfriend-suite"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

section()  { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()     { echo -e "${CYAN}[*] $*${NC}"; }
ok()       { echo -e "${GREEN}[✓] $*${NC}"; }
warn()     { echo -e "  ${YELLOW}WARN:${NC} $*"; }
err()      { echo -e "  ${RED}ERR:${NC}  $*"; }

TOTAL=0
ACTIVE_OK=0
FAILED_CNT=0
INACTIVE_CNT=0

WARN_CNT=0

MAP_FILE="$(mktemp /tmp/sf_services_map.XXXXXX)"
trap 'rm -f "$MAP_FILE"' EXIT

diag_service() {
    local svc="$1"
    TOTAL=$((TOTAL+1))

    local active enabled
    active="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"
    enabled="$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")"

    local FragmentPath WorkingDirectory ExecStart Result ExecMainStatus ExecMainCode
    FragmentPath="$(systemctl show -p FragmentPath --value "$svc" 2>/dev/null || true)"
    WorkingDirectory="$(systemctl show -p WorkingDirectory --value "$svc" 2>/dev/null || true)"
    ExecStart="$(systemctl show -p ExecStart --value "$svc" 2>/dev/null || true)"
    Result="$(systemctl show -p Result --value "$svc" 2>/dev/null || true)"
    ExecMainStatus="$(systemctl show -p ExecMainStatus --value "$svc" 2>/dev/null || true)"
    ExecMainCode="$(systemctl show -p ExecMainCode --value "$svc" 2>/dev/null || true)"

    local main_bin=""
    if [[ -n "$ExecStart" ]]; then
        main_bin="$(sed -n 's/.*path=\([^ ;]*\).*/\1/p' <<<"$ExecStart" | head -n1 || true)"
    fi

    echo
    echo -e "${BLUE}--- $svc ---${NC}"
    echo "STATE   : active=${active}, enabled=${enabled}, result=${Result:-unknown}"
    echo "PATHS   : unit=${FragmentPath:-<none>}"
    echo "          workdir=${WorkingDirectory:-<empty>}"
    echo "          exec=${main_bin:-<unknown>}"
    echo "STATUS  : ExecMainCode=${ExecMainCode:-?}, ExecMainStatus=${ExecMainStatus:-?}"

    # تصنيف أساسي للحالة
    if [[ "$active" == "active" ]]; then
        ACTIVE_OK=$((ACTIVE_OK+1))
    elif [[ "$active" == "failed" || "$Result" == "failed" ]]; then
        FAILED_CNT=$((FAILED_CNT+1))
    elif [[ "$active" == "inactive" || "$active" == "dead" ]]; then
        INACTIVE_CNT=$((INACTIVE_CNT+1))
    fi

    # تحذيرات
    local has_issue=0

    # 1) unit file
    if [[ -z "$FragmentPath" || ! -f "$FragmentPath" ]]; then
        warn "unit file مفقود أو غير موجود فعليًا (FragmentPath=${FragmentPath:-<none>})"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    # 2) WorkingDirectory
    if [[ -n "$WorkingDirectory" && ! -d "$WorkingDirectory" ]]; then
        warn "مسار WorkingDirectory غير موجود على النظام: $WorkingDirectory"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    if [[ -z "$WorkingDirectory" && "$ExecStart" == *"$SUITE_ROOT"* ]]; then
        warn "WorkingDirectory فارغ رغم أن ExecStart داخل السويت – يُفضل ضبطه على مجلد السويت المناسب"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    # 3) ملف التنفيذ
    if [[ -n "$main_bin" && ! -x "$main_bin" ]]; then
        warn "ملف التنفيذ غير موجود أو غير قابل للتنفيذ: $main_bin"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    # 4) أخطاء CHDIR (كود 200)
    if [[ "$ExecMainStatus" == "200" && "$ExecMainCode" == "exited" ]]; then
        warn "فشل CHDIR (status=200/CHDIR) – مشكلة في WorkingDirectory أو المسار"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    # 5) خدمة template
    if [[ "$svc" == *"@"* ]]; then
        warn "خدمة template (وحدة عامة) – لا تعمل بمفردها، تحتاج instance مثل: ${svc%@.service}@NAME.service"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    # 6) خدمة فاشلة بدون سجلات واضحة
    if [[ "$active" == "failed" && -z "$ExecMainStatus" && -z "$ExecMainCode" ]]; then
        warn "الخدمة فاشلة لكن بدون كود تنفيذ واضح – راجع journalctl -u $svc"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    # 7) ExecStart خارج السويت وبدون WorkingDirectory
    if [[ -z "$WorkingDirectory" && -n "$main_bin" && "$main_bin" != "$SUITE_ROOT"* ]]; then
        # بعض السكربتات تحت /usr/local مسموحة، بس ننبه
        warn "لا يوجد WorkingDirectory محدد رغم أن التنفيذ $main_bin – تأكد أنه لا يعتمد على cwd"
        WARN_CNT=$((WARN_CNT+1)); has_issue=1
    fi

    if [[ "$has_issue" -eq 0 ]]; then
        ok "لا توجد مشاكل واضحة في تعريف الوحدة"
    fi

    # حفظ خريطة (binary -> services) لتحليل التعارضات
    if [[ -n "$main_bin" ]]; then
        echo "${main_bin}|${svc}" >> "$MAP_FILE"
    fi
}

main() {
    echo
    echo "   _____ _                 _   ______      _           _       _     "
    echo "  / ____| |               | | |  ____|    | |         (_)     | |    "
    echo " | (___ | |_ __ _ _ __ ___| |_| |__ _ __ | |__  _   _ _ _ __ | |_   "
    echo "  \\___ \\| __/ _\` | '__/ __| __|  __| '_ \\| '_ \\| | | | | '_ \\| __|  "
    echo "  ____) | || (_| | |  \\__ \\ |_| |  | | | | | | | |_| | | | | | |_   "
    echo " |_____/ \\__\\__,_|_|  |___/\\__|_|  |_| |_|_| |_|\\__,_|_|_| |_|\\__|  "
    echo
    echo "🤖 تشخيص شامل لخدمات SmartFriend Suite (sf-/smartfriend-/smartfrind)"
    echo

    section "جمع قائمة الخدمات المستهدفة"
    local services
    services="$(systemctl list-unit-files --type=service 2>/dev/null | awk "/$PATTERN/ {print \$1}")"

    if [[ -z "$services" ]]; then
        err "لا توجد خدمات مطابقة للنمط $PATTERN"
        exit 1
    fi

    info "إجمالي الخدمات المكتشفة: $(echo "$services" | wc -l)"

    section "تفاصيل كل خدمة وحالتها والتحذيرات"
    while read -r svc; do
        [[ -z "$svc" ]] && continue
        diag_service "$svc"
    done <<< "$services"

    section "ملخص رقمي"
    echo "إجمالي الخدمات   : $TOTAL"
    echo "نشطة (active)    : $ACTIVE_OK"
    echo "فاشلة (failed)   : $FAILED_CNT"
    echo "معطلة/ميتة       : $INACTIVE_CNT"
    echo "عدد التحذيرات    : $WARN_CNT"

    section "تحليل التعارضات (نفس ملف التنفيذ لأكثر من خدمة)"
    if [[ ! -s "$MAP_FILE" ]]; then
        echo "لا توجد بيانات تنفيذ لتحليلها."
        return 0
    fi

    # نجمّع الخدمات حسب ملف التنفيذ
    awk -F'|' 'NF==2 {bins[$1]=bins[$1]" "$2} END {
        for (b in bins) {
            n=split(bins[b], a, " ")
            if (n>1) {
                printf "ملف تنفيذ واحد: %s\n", b
                for (i=1; i<=n; i++) {
                    printf "  - %s\n", a[i]
                }
                printf "\n"
            }
        }
    }' "$MAP_FILE" || true

    echo
    echo "💡 لمزيد من التفاصيل عن خدمة معينة، استخدم مثلاً:"
    echo "   journalctl -u smartfriend-api.service -n 50 --no-pager"
    echo
}

main "$@"
