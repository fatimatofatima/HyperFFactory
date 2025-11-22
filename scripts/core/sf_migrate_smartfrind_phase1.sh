#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="/root/sf_reports"
REPORT="${REPORT_DIR}/smartfrind_phase1_${TS}.txt"

mkdir -p "$REPORT_DIR"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$REPORT"
}

log "=== SmartFrind → SmartFriend-Suite Inventory (Phase 1) ==="
log

# --------------------------------------------------
# 1) مسارات وأحجام SmartFrind
# --------------------------------------------------
{
    echo "1) Directories & sizes"
    echo "----------------------"
    DIRS=(
        "/opt/smartfrind"
        "/opt/smartfrind_unified"
        "/opt/smartfriend-suite/smartfrind"
        "/var/lib/smartfrind"
        "/var/log/smartfrind"
        "/var/backups/smartfrind"
        "/var/backups/smartfrind_20251106_104852"
        "/var/backups/smartfrind_20251106_104950"
        "/var/backups/smartfrind_20251106_105126"
        "/var/backups/smartfrind_20251106_110037"
        "/var/backups/smartfrind_20251106_114241"
    )

    for d in "${DIRS[@]}"; do
        if [ -d "$d" ]; then
            SIZE="$(du -sh "$d" 2>/dev/null | awk '{print $1}')"
            echo " - $d  (size: ${SIZE:-unknown})"
        fi
    done
    echo
} | tee -a "$REPORT"

# --------------------------------------------------
# 2) شجرة /opt/smartfrind
# --------------------------------------------------
if [ -d "/opt/smartfrind" ]; then
    {
        echo "2) /opt/smartfrind tree (level 2)"
        echo "---------------------------------"
        if command -v tree >/dev/null 2>&1; then
            tree -L 2 "/opt/smartfrind"
        else
            find "/opt/smartfrind" -maxdepth 2 -mindepth 1 -type d | sort
        fi
        echo
    } | tee -a "$REPORT"
fi

# --------------------------------------------------
# 3) شجرة /opt/smartfriend-suite/smartfrind
# --------------------------------------------------
if [ -d "/opt/smartfriend-suite/smartfrind" ]; then
    {
        echo "3) /opt/smartfriend-suite/smartfrind tree (level 2)"
        echo "---------------------------------------------------"
        if command -v tree >/dev/null 2>&1; then
            tree -L 2 "/opt/smartfriend-suite/smartfrind"
        else
            find "/opt/smartfriend-suite/smartfrind" -maxdepth 2 -mindepth 1 -type d | sort
        fi
        echo
    } | tee -a "$REPORT"
fi

# --------------------------------------------------
# 4) وضع الـ venv لـ SmartFrind
# --------------------------------------------------
VENV_PY="/opt/smartfrind/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
    {
        echo "4) SmartFrind venv"
        echo "------------------"
        echo "Python:"
        "$VENV_PY" -V 2>&1 || true
        echo
        echo "pip list (first 40):"
        "$VENV_PY" -m pip list --format=freeze 2>/dev/null | head -n 40 || true
        echo
    } | tee -a "$REPORT"
fi

# --------------------------------------------------
# 5) systemd units (smartfrind*/smartfriend*)
# --------------------------------------------------
{
    echo "5) systemd units (smartfrind*/smartfriend*)"
    echo "------------------------------------------"
    echo
    echo "== list-unit-files =="
    systemctl list-unit-files 'smartfrind*' 'smartfriend*' 2>/dev/null || true
    echo
    echo "== status (short) =="
    UNITS="$(systemctl list-units 'smartfrind*' 'smartfriend*' --all --no-legend 2>/dev/null | awk '{print $1}' | sort -u || true)"
    for u in $UNITS; do
        echo "---- $u ----"
        systemctl status "$u" --no-pager -n 3 2>/dev/null || echo "status failed for $u"
        echo
    done
} | tee -a "$REPORT"

# --------------------------------------------------
# 6) قواعد البيانات (*.db / *.sqlite*)
# --------------------------------------------------
{
    echo "6) Databases under /var/lib/smartfrind & /var/backups"
    echo "-----------------------------------------------------"
    DB_ROOTS=(
        "/var/lib/smartfrind"
        "/var/backups"
    )
    for root in "${DB_ROOTS[@]}"; do
        if [ -d "$root" ]; then
            echo
            echo "Root: $root"
            find "$root" -maxdepth 4 -type f \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) 2>/dev/null \
            | while read -r f; do
                SZ="$(du -h "$f" 2>/dev/null | awk '{print $1}')"
                echo " - $f  (size: ${SZ:-?})"
            done
        fi
    done
    echo
} | tee -a "$REPORT"

log "=== Phase 1 inventory completed ==="
echo "Report written to: $REPORT"
