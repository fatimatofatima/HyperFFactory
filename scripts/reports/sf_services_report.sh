#!/usr/bin/env bash
set -Eeuo pipefail

LANG=C
SUITE_ROOT="/opt/smartfriend-suite"
OUT_DIR="/root/sf_service_reports_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

get_prop() {
    local svc="$1" key="$2"
    systemctl show -p "$key" --value "$svc" 2>/dev/null || true
}

analyze_service() {
    local svc="$1"
    local idx_file="$OUT_DIR/INDEX.txt"
    local rep_file="$OUT_DIR/${svc}.report.txt"

    local ActiveState Result ExecMainStatus ExecMainCode
    local FragmentPath WorkingDirectory ExecStart main_bin severity issues

    ActiveState="$(get_prop "$svc" ActiveState)"
    Result="$(get_prop "$svc" Result)"
    ExecMainStatus="$(get_prop "$svc" ExecMainStatus)"
    ExecMainCode="$(get_prop "$svc" ExecMainCode)"
    FragmentPath="$(get_prop "$svc" FragmentPath)"
    WorkingDirectory="$(get_prop "$svc" WorkingDirectory)"
    ExecStart="$(get_prop "$svc" ExecStart)"

    main_bin="$(sed -n 's/.*path=\([^ ;]*\).*/\1/p' <<<"$ExecStart" | head -n1 || true)"

    severity="OK"
    issues=""

    if [[ "$ActiveState" == "failed" || "$Result" == "failed" ]]; then
        severity="FAILED"
    elif [[ "$ActiveState" != "active" ]]; then
        severity="INACTIVE"
    fi

    if [[ -n "$ExecMainStatus" && "$ExecMainStatus" != "0" ]]; then
        [[ "$severity" == "OK" ]] && severity="WARN"
    fi

    # تحليلات إضافية
    if [[ -z "$FragmentPath" || ! -f "$FragmentPath" ]]; then
        issues+="unit-file-missing;"
        [[ "$severity" == "OK" ]] && severity="WARN"
    fi

    if [[ -n "$WorkingDirectory" && ! -d "$WorkingDirectory" ]]; then
        issues+="workdir-missing;"
        [[ "$severity" == "OK" ]] && severity="WARN"
    fi

    if [[ -z "$WorkingDirectory" && "$ExecStart" == *"$SUITE_ROOT"* ]]; then
        issues+="workdir-empty-suite;"
        [[ "$severity" == "OK" ]] && severity="WARN"
    fi

    if [[ -n "$main_bin" && ! -x "$main_bin" ]]; then
        issues+="exec-missing-or-not-executable;"
        [[ "$severity" == "OK" ]] && severity="WARN"
    fi

    if [[ "$ExecMainStatus" == "203" ]]; then
        issues+="exec-203-EXEC;"
        severity="FAILED"
    fi

    if [[ "$ExecMainStatus" == "200" ]]; then
        issues+="exec-200-CHDIR;"
        [[ "$severity" == "OK" ]] && severity="FAILED"
    fi

    if [[ "$Result" == "resources" ]]; then
        issues+="result-resources;"
        [[ "$severity" == "OK" ]] && severity="FAILED"
    fi

    # كتابة رأس التقرير
    {
        echo "================================================================="
        echo "Service      : $svc"
        echo "Severity     : $severity"
        echo "ActiveState  : ${ActiveState:-<unknown>}"
        echo "Result       : ${Result:-<unknown>}"
        echo "ExecStatus   : code=${ExecMainCode:-?} status=${ExecMainStatus:-?}"
        echo "UnitFile     : ${FragmentPath:-<none>}"
        echo "WorkingDir   : ${WorkingDirectory:-<empty>}"
        echo "ExecStartBin : ${main_bin:-<unknown>}"
        echo "IssuesFlags  : ${issues:-<none>}"
        echo "GeneratedAt  : $(date '+%F %T')"
        echo "================================================================="
        echo
        echo "### systemctl cat $svc"
        echo "-----------------------------------------------------------------"
        systemctl cat "$svc" 2>&1 || echo "<systemctl cat failed>"
        echo
        echo "### journalctl -u $svc (last 80 lines)"
        echo "-----------------------------------------------------------------"
        journalctl -u "$svc" -n 80 --no-pager 2>&1 || echo "<journalctl failed>"
        echo
    } > "$rep_file"

    # سطر في الـ INDEX
    echo -e "$svc\t$severity\t$ActiveState\t$Result\t$issues" >> "$idx_file"
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
    echo "🤖 إنشاء تقارير تفصيلية لكل خدمات SmartFriend Suite"
    echo

    log "مجلد التقارير: $OUT_DIR"

    local services
    services="$(systemctl list-unit-files --type=service 2>/dev/null \
        | awk '/^(sf-|smartfriend|smartfrind)/ {print $1}' \
        | sort -u)"

    if [[ -z "$services" ]]; then
        echo "لا توجد خدمات مطابقة للنمط."
        exit 1
    fi

    log "عدد الخدمات: $(echo "$services" | wc -l)"

    echo -e "SERVICE\tSEVERITY\tACTIVE\tRESULT\tISSUES" > "$OUT_DIR/INDEX.txt"

    while read -r svc; do
        [[ -z "$svc" ]] && continue
        log "تحليل $svc"
        analyze_service "$svc"
    done <<< "$services"

    ok "تم إنشاء التقارير في: $OUT_DIR"
    echo
    echo "ملف الفهرس: $OUT_DIR/INDEX.txt"
    echo "مثال لقراءة تقرير خدمة:"
    echo "  less $OUT_DIR/smartfrind-unified.service.report.txt"
}

main "$@"
