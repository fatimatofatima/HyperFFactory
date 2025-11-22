#!/usr/bin/env bash
set -Eeuo pipefail

SUITE_ROOT="/opt/smartfriend-suite"
PATTERN='^(sf-|smartfriend|smartfrind)'

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()      { echo -e "${BLUE}[*]${NC} $*"; }
ok()       { echo -e "${GREEN}[✓]${NC} $*"; }
warn()     { echo -e "${YELLOW}[!]${NC} $*"; }
err()      { echo -e "${RED}[✗]${NC} $*"; }

get_unit_file() {
    systemctl show -p FragmentPath --value "$1" 2>/dev/null || true
}

fix_workdir_for_unit() {
    local svc="$1"
    local unit_file
    unit_file="$(get_unit_file "$svc")"

    # لا يوجد ملف خدمة حقيقي
    if [[ -z "$unit_file" || ! -f "$unit_file" ]]; then
        warn "تخطي $svc (لا يوجد unit file حقيقي)"
        return
    fi

    # لا نلمس أي شيء فيه ffactory
    if grep -q "/opt/ffactory" "$unit_file"; then
        warn "تخطي $svc (يمس ffactory)"
        return
    fi

    # نتأكد إنه خدمة للسويت فعلاً
    if ! grep -q "$SUITE_ROOT" "$unit_file"; then
        # بعض الخدمات سكربتاتها في /usr/local بس للسويت – نخلي WD السويت
        warn "تعيين WorkingDirectory للسويت لـ $svc (Exec خارج السويت)"
    fi

    local current
    current="$(grep -m1 '^WorkingDirectory=' "$unit_file" 2>/dev/null | cut -d= -f2- || true)"

    # لو فيه WorkingDirectory ومش فاضي → نسيبه
    if [[ -n "$current" ]]; then
        ok "WorkingDirectory مضبوط مسبقاً لـ $svc: $current"
        return
    fi

    # نجيب سطر ExecStart من ملف الخدمة نفسه (مش من systemctl show)
    local exec_line
    exec_line="$(grep -m1 '^ExecStart=' "$unit_file" 2>/dev/null | cut -d= -f2- || true)"

    local new_wd="$SUITE_ROOT"

    if echo "$exec_line" | grep -q "$SUITE_ROOT"; then
        # ناخد أول path داخل /opt/smartfriend-suite
        local path_in_suite
        path_in_suite="$(echo "$exec_line" | tr ' ' '\n' | grep "^$SUITE_ROOT" | head -1 || true)"
        if [[ -n "$path_in_suite" ]]; then
            new_wd="$(dirname "$path_in_suite")"
        fi
    fi

    # لو لسه مفيش Exec واضح، نخليها جذر السويت
    if [[ -z "$new_wd" ]]; then
        new_wd="$SUITE_ROOT"
    fi

    # نضيف أو نعدل WorkingDirectory في ملف الخدمة
    if grep -q '^WorkingDirectory=' "$unit_file"; then
        sed -i "s|^WorkingDirectory=.*|WorkingDirectory=$new_wd|" "$unit_file"
    else
        if grep -q '^\[Service\]' "$unit_file"; then
            sed -i "s/^\[Service\]/[Service]\nWorkingDirectory=$new_wd/" "$unit_file"
        else
            # نضيف بلوك Service بسيط لو مش موجود (حالة نادرة)
            printf '\n[Service]\nWorkingDirectory=%s\n' "$new_wd" >> "$unit_file"
        fi
    fi

    ok "ضبط WorkingDirectory لـ $svc → $new_wd"
}

start_services() {
    log "إعادة تحميل systemd..."
    systemctl daemon-reload

    log "بدء/إعادة تشغيل كل خدمات السويت (بدون ffactory)..."

    local services
    services="$(systemctl list-unit-files --type=service 2>/dev/null | awk "/$PATTERN/ {print \$1}")"

    for svc in $services; do
        # تخطي الـ template units
        [[ "$svc" == *"@"* ]] && continue

        local unit_file
        unit_file="$(get_unit_file "$svc")"

        # لو الخدمة تمس ffactory نتخطاها
        if [[ -n "$unit_file" ]] && grep -q "/opt/ffactory" "$unit_file" 2>/dev/null; then
            warn "تخطي $svc (يمس ffactory)"
            continue
        fi

        # نحاول تشغيل/إعادة تشغيل الخدمة
        if systemctl restart "$svc" 2>/dev/null; then
            ok "تم تشغيل/إعادة تشغيل $svc"
        else
            err "فشل تشغيل $svc"
        fi
    done
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
    echo "🤖 إصلاح وتشغيل خدمات SmartFriend Suite (بدون لمس ffactory)"
    echo

    local services
    services="$(systemctl list-unit-files --type=service 2>/dev/null | awk "/$PATTERN/ {print \$1}")"

    if [[ -z "$services" ]]; then
        err "لا توجد خدمات sf-/smartfriend-/smartfrind مسجلة"
        exit 1
    fi

    log "عدد الخدمات المستهدفة: $(echo "$services" | wc -l)"

    # 1) إصلاح WorkingDirectory
    for svc in $services; do
        [[ "$svc" == *"@"* ]] && continue
        fix_workdir_for_unit "$svc"
    done

    # 2) تشغيل / إعادة تشغيل
    start_services

    echo
    ok "انتهى إصلاح وتشغيل خدمات السويت"
    echo "💡 راجع حالة الخدمات بـ:  /root/sf_check_services.sh"
}

main "\$@"
