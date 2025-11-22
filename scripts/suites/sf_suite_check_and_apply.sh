#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ================== إعدادات السلوك ==================
: "${DRY_RUN:=1}"          # 1 = فحص فقط، 0 = تنفيذ فعلي
: "${APPLY_SUITE:=0}"      # 1 = تشغيل سكربتات السيوت
: "${FREEZE_LEGACY:=0}"    # 1 = تشغيل تجميد smartfrind-* (إذا متاح)
: "${FIX_NGINX:=0}"        # 1 = تشغيل سكربت ربط Nginx بالسيوت (إذا متاح)

DB_MAIN="/opt/smartfriend-suite/var/db/smartfriend_unified.db"

log()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
info()   { log "INFO  - $*"; }
warn()   { log "WARN  - $*"; }
error()  { log "ERROR - $*"; }
section(){ echo; echo "========== $* =========="; }

run_cmd() {
    local desc="$1"; shift
    info "$desc"
    if (( DRY_RUN )); then
        echo "DRY_RUN=1 → لن يتم تنفيذ الأمر، فقط عرض:"
        echo "           $*"
    else
        "$@"
    fi
}

find_script() {
    local name="$1"
    local path=""
    for d in "/root" "/opt/smartfriend-suite" "/opt/smartfriend-suite/bin"; do
        if [ -x "$d/$name" ]; then
            path="$d/$name"
            break
        fi
    done
    echo "$path"
}

check_env_snapshot() {
    section "فحص عام للنظام"
    uname -a || true
    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -a 2>/dev/null || true
    fi

    echo
    info "حالة المساحة على /"
    df -h / || true

    echo
    info "حالة الذاكرة"
    free -h || true

    echo
    info "معلومات عن المستخدم الحالي والمسار"
    id || true
    pwd || true
}

check_db_status() {
    section "فحص قاعدة البيانات الموحّدة للسيوت"
    if [ -f "$DB_MAIN" ]; then
        info "الملف موجود: $DB_MAIN"
        stat "$DB_MAIN" 2>/dev/null || ls -l "$DB_MAIN" || true

        # محاولة اكتشاف الروابط (hardlinks) داخل /opt/smartfriend-suite فقط
        if command -v stat >/dev/null 2>&1; then
            local inode
            inode="$(stat -c '%i' "$DB_MAIN" 2>/dev/null || echo "")"
            if [ -n "$inode" ]; then
                echo
                info "الملفات المشاركة في نفس inode داخل /opt/smartfriend-suite (روابط موحّدة):"
                find /opt/smartfriend-suite -xdev -inum "$inode" -maxdepth 6 -type f 2>/dev/null || true
            fi
        fi
    else
        warn "قاعدة البيانات الموحّدة غير موجودة: $DB_MAIN"
    fi
}

check_services_status() {
    section "فحص خدمات sf-* و smartfrind-* (list-units)"
    systemctl list-units 'sf-*' 'smartfrind-*' --type=service --all --no-pager || true

    echo
    section "الوحدات الفعالة فعليًا smartfrind-* (legacy running)"
    systemctl list-units 'smartfrind-*' --type=service --state=active,running --no-pager || true

    echo
    section "ملفات الوحدات (list-unit-files)"
    systemctl list-unit-files 'sf-*' 'smartfrind-*' --type=service --no-pager || true
}

check_ports_and_http() {
    section "فحص البورتات الأساسية للسيوت"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn | grep -E ':(8210|8211|8214|8215|8220|8383|8390)' || echo "لا توجد بورتات مستهدفة مفتوحة حاليًا."
    else
        warn "الأمر ss غير متوفر."
    fi

    echo
    section "فحص Nginx (nginx -t)"
    if command -v nginx >/dev/null 2>&1; then
        nginx -t || warn "nginx -t فشل أو غير مضبوط."
    else
        warn "nginx غير مُثبّت أو غير متوفر في PATH."
    fi

    echo
    section "اختبار واجهات HTTP الداخلية (curl)"
    if ! command -v curl >/dev/null 2>&1; then
        warn "curl غير متوفر؛ لن يتم اختبار HTTP."
        return
    fi

    local urls=(
        "http://127.0.0.1:8383/health"
        "http://127.0.0.1:8214/health"
        "http://127.0.0.1:8390/health"
        "http://127.0.0.1/unified/health"
        "http://127.0.0.1/memory/health"
        "http://127.0.0.1/ffactory/docs"
    )

    for u in "${urls[@]}"; do
        echo
        info "طلب: $u"
        curl -sS -m 5 "$u" || warn "فشل الوصول إلى: $u"
    done
}

apply_suite_scripts() {
    section "تنفيذ سكربتات السيوت (بحسب المتاح والخيارات)"

    if ! (( APPLY_SUITE )); then
        info "APPLY_SUITE=0 → لن يتم تشغيل أي سكربت ترويجي، فقط الفحص."
        return
    fi

    local unify promote_core promote_suite freeze_legacy nginx_switch

    unify="$(find_script sf_suite_unify_all.sh)"
    promote_core="$(find_script sf_suite_promote_core.sh)"
    promote_suite="$(find_script sf_suite_promote_suite.sh)"
    freeze_legacy="$(find_script sf_suite_freeze_legacy.sh)"
    nginx_switch="$(find_script sf_suite_nginx_switch_to_suite.sh)"

    if [ -n "$unify" ]; then
        info "تم العثور على sf_suite_unify_all.sh في: $unify"
        run_cmd "تشغيل sf_suite_unify_all.sh مع --include-critical" \
            "$unify" --include-critical
        return
    else
        warn "sf_suite_unify_all.sh غير موجود؛ سيتم استخدام السكربتات المنفصلة إن توفرت."
    fi

    if [ -n "$promote_core" ]; then
        run_cmd "تشغيل sf_suite_promote_core.sh" "$promote_core"
    else
        warn "sf_suite_promote_core.sh غير موجود."
    fi

    if [ -n "$promote_suite" ]; then
        run_cmd "تشغيل sf_suite_promote_suite.sh" "$promote_suite"
    else
        warn "sf_suite_promote_suite.sh غير موجود."
    fi

    if (( FREEZE_LEGACY )); then
        if [ -n "$freeze_legacy" ]; then
            run_cmd "تشغيل sf_suite_freeze_legacy.sh (تجميد smartfrind-*)" "$freeze_legacy"
        else
            warn "sf_suite_freeze_legacy.sh غير موجود بالرغم من FREEZE_LEGACY=1."
        fi
    else
        info "FREEZE_LEGACY=0 → لن يتم تشغيل سكربت تجميد legacy."
    fi

    if (( FIX_NGINX )); then
        if [ -n "$nginx_switch" ]; then
            run_cmd "تشغيل sf_suite_nginx_switch_to_suite.sh (تبديل Nginx للسيوت)" "$nginx_switch"
        else
            warn "sf_suite_nginx_switch_to_suite.sh غير موجود بالرغم من FIX_NGINX=1."
        fi
    else
        info "FIX_NGINX=0 → لن يتم تشغيل سكربت ربط Nginx بالسيوت."
    fi
}

post_check_summary() {
    section "إعادة الفحص المختصر بعد التنفيذ (خدمات وبورتات)"
    check_services_status
    check_ports_and_http
}

main() {
    section "وضع التشغيل الحالي للسكربت"
    echo "DRY_RUN      = $DRY_RUN   (1 = فحص فقط، 0 = تنفيذ فعلي)"
    echo "APPLY_SUITE  = $APPLY_SUITE   (تشغيل سكربتات الترويج والتوحيد)"
    echo "FREEZE_LEGACY= $FREEZE_LEGACY (تجميد smartfrind-* إن أمكن)"
    echo "FIX_NGINX    = $FIX_NGINX     (ربط Nginx بالسيوت إن أمكن)"

    check_env_snapshot
    check_db_status
    check_services_status
    check_ports_and_http

    apply_suite_scripts

    if (( APPLY_SUITE )) && ! (( DRY_RUN )); then
        post_check_summary
    else
        section "لن يتم تنفيذ فحص ما بعد التنفيذ لأن (APPLY_SUITE=0 أو DRY_RUN=1)"
    fi

    echo
    section "انتهى السكربت sf_suite_check_and_apply.sh"
    info "يمكنك تعديل DRY_RUN/APPLY_SUITE/FREEZE_LEGACY/FIX_NGINX حسب المطلوب ثم إعادة التشغيل."
}

main "$@"
