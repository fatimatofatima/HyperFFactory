#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

AUDIT_ROOT="/root/sf_audit"
mkdir -p "$AUDIT_ROOT"

TS="$(date '+%Y%m%d_%H%M%S')"
BASE="${AUDIT_ROOT}/legacy_brain_myfriend_${TS}"

run_log="${BASE}_run.log"
log() { echo "[$(date '+%F %T')] $*" | tee -a "$run_log"; }

BRAIN_DIR="/opt/BRAIN_CORE"
MYFRIEND_DIR="/opt/MyFriend"

brain_dirs="${BASE}_brain_dirs.txt"
brain_systemd="${BASE}_brain_systemd.txt"
brain_refs="${BASE}_brain_refs.txt"
brain_ps="${BASE}_brain_ps.txt"

my_dirs="${BASE}_myfriend_dirs.txt"
my_systemd="${BASE}_myfriend_systemd.txt"
my_refs="${BASE}_myfriend_refs.txt"
my_ps="${BASE}_myfriend_ps.txt"

file_patterns='( -name "*.service" -o -name "*.sh" -o -name "*.py" -o -name "*.env" -o -name "*.ini" -o -name "*.conf" -o -name "*.yml" -o -name "*.yaml" )'

scan_root() {
    local root="$1"
    local pattern="$2"
    if [ ! -d "$root" ]; then
        echo "## ROOT: $root" 
        echo "(root not found)"
        return 0
    fi

    echo "## ROOT: $root"
    # نستخدم find + xargs لضبط الأنواع
    eval "find \"$root\" -maxdepth 8 -type f $file_patterns -print0" \
      | xargs -0 grep -nH "$pattern" 2>/dev/null || echo "(no hits under $root)"
    echo
}

log "=== Legacy audit: BRAIN_CORE + MyFriend ==="
log "Timestamp: $TS"
log "Reports base: $BASE"
log

########################
# 1) BRAIN_CORE: هيكل المجلد
########################
{
    echo "=== /opt/BRAIN_CORE basic info ==="
    if [ -d "$BRAIN_DIR" ]; then
        du -sh "$BRAIN_DIR" 2>/dev/null || true
        echo
        echo "--- level-1/2 structure ---"
        find "$BRAIN_DIR" -maxdepth 2 -mindepth 1 -printf '%y %p\n' | sort
    else
        echo "NOT_FOUND: $BRAIN_DIR"
    fi
} >"$brain_dirs"

########################
# 2) BRAIN_CORE: systemd
########################
{
    echo "# systemd units with BRAIN_CORE in name"
    systemctl list-units --all | grep -i 'BRAIN_CORE' || echo "(none)"
    echo
    echo "# systemd unit files containing BRAIN_CORE"
    grep -Rni "BRAIN_CORE" /etc/systemd/system /lib/systemd/system 2>/dev/null || echo "(none)"
} >"$brain_systemd"

########################
# 3) BRAIN_CORE: مراجع الكود/الإعدادات
########################
{
    scan_root "/opt" "BRAIN_CORE"
    scan_root "/srv" "BRAIN_CORE"
    scan_root "/etc" "BRAIN_CORE"
} >"$brain_refs"

########################
# 4) BRAIN_CORE: العمليات الجارية
########################
{
    echo "ps aux | grep -Ei 'BRAIN_CORE|/opt/BRAIN_CORE' (excluding grep)"
    ps aux | grep -Ei 'BRAIN_CORE|/opt/BRAIN_CORE' | grep -v grep || echo "(no running processes related)"
} >"$brain_ps"


########################
# 5) MyFriend: هيكل المجلد
########################
{
    echo "=== /opt/MyFriend basic info ==="
    if [ -d "$MYFRIEND_DIR" ]; then
        du -sh "$MYFRIEND_DIR" 2>/dev/null || true
        echo
        echo "--- level-1/2 structure ---"
        find "$MYFRIEND_DIR" -maxdepth 2 -mindepth 1 -printf '%y %p\n' | sort
    else
        echo "NOT_FOUND: $MYFRIEND_DIR"
    fi
} >"$my_dirs"

########################
# 6) MyFriend: systemd
########################
{
    echo "# systemd units with MyFriend in name"
    systemctl list-units --all | grep -i 'myfriend' || echo "(none)"
    echo
    echo "# systemd unit files containing /opt/MyFriend أو MyFriend"
    grep -Rni "/opt/MyFriend" /etc/systemd/system /lib/systemd/system 2>/dev/null || true
    grep -Rni "MyFriend" /etc/systemd/system /lib/systemd/system 2>/dev/null || echo "(none)"
} >"$my_systemd"

########################
# 7) MyFriend: مراجع الكود/الإعدادات
########################
{
    scan_root "/opt" "MyFriend"
    scan_root "/srv" "MyFriend"
    scan_root "/etc" "MyFriend"
} >"$my_refs"

########################
# 8) MyFriend: العمليات الجارية
########################
{
    echo "ps aux | grep -Ei 'MyFriend|/opt/MyFriend' (excluding grep)"
    ps aux | grep -Ei 'MyFriend|/opt/MyFriend' | grep -v grep || echo "(no running processes related)"
} >"$my_ps"

log "Generated reports:"
log "  BRAIN_CORE dirs     : $brain_dirs"
log "  BRAIN_CORE systemd  : $brain_systemd"
log "  BRAIN_CORE refs     : $brain_refs"
log "  BRAIN_CORE ps       : $brain_ps"
log "  MyFriend dirs       : $my_dirs"
log "  MyFriend systemd    : $my_systemd"
log "  MyFriend refs       : $my_refs"
log "  MyFriend ps         : $my_ps"

log "=== Audit finished (no changes applied to system) ==="
