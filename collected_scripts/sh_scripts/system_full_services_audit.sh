#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

section()  { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()     { echo -e "${CYAN}[*] $*${NC}"; }
warn()     { echo -e "${YELLOW}[!] $*${NC}"; }
ok()       { echo -e "${GREEN}[OK] $*${NC}"; }

main() {
    ########################################
    # 1) System summary
    ########################################
    section "System summary"

    echo "Hostname    : $(hostname)"
    if command -v lsb_release >/dev/null 2>&1; then
        echo "Distro      : $(lsb_release -ds)"
    else
        echo "Distro      : $(grep -m1 PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '\"')"
    fi
    echo "Kernel      : $(uname -r)"
    echo "Uptime (raw): $(uptime)"
    echo "Uptime nice : $(uptime -p 2>/dev/null || echo 'n/a')"

    echo
    echo "Disk /:"
    df -h / || true

    echo
    echo "Memory:"
    free -h || true

    ########################################
    # 2) Global services stats
    ########################################
    section "Services global stats"

    local total active inactive failed
    total=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | wc -l || echo 0)
    active=$(systemctl list-units --type=service --state=active --no-legend 2>/dev/null | wc -l || echo 0)
    inactive=$(systemctl list-units --type=service --state=inactive --no-legend 2>/dev/null | wc -l || echo 0)
    failed=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | wc -l || echo 0)

    echo "Total   : $total"
    echo "Active  : $active"
    echo "Inactive: $inactive"
    echo "Failed  : $failed"

    echo
    echo "By ACTIVE state (all services):"
    systemctl list-units --type=service --all --no-legend 2>/dev/null \
      | awk '{cnt[$3]++} END {for (s in cnt) printf "  %-12s : %d\n", s, cnt[s]}' \
      | sort || true

    ########################################
    # 3) Compact table of all services
    ########################################
    section "All services table (UNIT / ACTIVE / SUB)"

    printf "%-45s %-10s %-12s\n" "UNIT" "ACTIVE" "SUB"
    printf "%-45s %-10s %-12s\n" "----" "------" "---"

    systemctl list-units --type=service --all --no-legend 2>/dev/null \
      | awk '{printf "%-45s %-10s %-12s\n", $1, $3, $4}' \
      | sort

    ########################################
    # 4) Focus on key prefixes
    ########################################
    section "Key service groups (sf / smartfriend / smartfrind / ff / ffactory)"

    local prefixes=("sf-" "smartfriend-" "smartfrind-" "ff-" "ffactory")

    for p in "${prefixes[@]}"; do
        info "Pattern: ${p}*.service"

        local units
        units=$(systemctl list-unit-files "${p}*.service" --no-legend 2>/dev/null | awk '{print $1}' | sort -u || true)

        if [ -z "${units}" ]; then
            echo "  (no units found)"
            continue
        fi

        printf "  %-40s %-10s %-10s %-10s\n" "UNIT" "ENABLED" "ACTIVE" "SUB"
        printf "  %-40s %-10s %-10s %-10s\n" "----" "-------" "------" "---"

        local u
        while read -r u; do
            [ -z "$u" ] && continue
            local enabled active_state sub_state line

            enabled=$(systemctl is-enabled "$u" 2>/dev/null || echo "-")
            line=$(systemctl list-units "$u" --type=service --all --no-legend 2>/dev/null || true)

            if [ -z "$line" ]; then
                active_state="-"
                sub_state="-"
            else
                active_state=$(echo "$line" | awk '{print $3}')
                sub_state=$(echo "$line" | awk '{print $4}')
            fi

            printf "  %-40s %-10s %-10s %-10s\n" "$u" "$enabled" "$active_state" "$sub_state"
        done <<< "$units"

        echo
    done

    ########################################
    # 5) Failed services list
    ########################################
    section "Failed services (systemctl --failed)"

    systemctl --failed --type=service --no-legend 2>/dev/null || echo "No failed services or unable to read."

    ########################################
    # 6) Failed services details
    ########################################
    section "Failed services details (status + last journal lines)"

    local failed_units
    failed_units=$(systemctl --failed --type=service --no-legend 2>/dev/null | awk '{print $1}' | sort -u || true)

    if [ -z "$failed_units" ]; then
        ok "No failed services."
    else
        local fu
        for fu in $failed_units; do
            echo
            echo "------------------------------ $fu ------------------------------"
            systemctl status "$fu" --no-pager -l 2>/dev/null | sed -n '1,25p' || warn "cannot read status for $fu"
            echo
            echo "Last 20 journal lines for $fu:"
            journalctl -u "$fu" -n 20 --no-pager 2>/dev/null || warn "no journal for $fu or rotated."
        done
    fi

    ########################################
    # 7) Timers overview
    ########################################
    section "All timers (overview)"

    systemctl list-timers --all --no-pager 2>/dev/null || true

    ########################################
    # End
    ########################################
    section "Note"
    echo "Read-only audit. No restart / enable / disable done."
}

main "$@"
