#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }

log "=== SmartFrind Legacy – تشخيص الخدمات القديمة (smartfrind-*) ==="

echo
log "--- [1] قائمة ملفات الوحدات smartfrind-*.service ---"
systemctl list-unit-files 'smartfrind-*.service' --no-pager --no-legend 2>/dev/null || true

echo
log "--- [2] حالة مختصرة لكل وحدة smartfrind-*.service ---"
for u in $(systemctl list-unit-files 'smartfrind-*.service' --no-legend 2>/dev/null | awk '{print $1}'); do
    echo "------------------------------------------------------------"
    echo "[$u]"
    systemctl status "$u" --no-pager -n 5 || true
done

echo
log "--- [3] ExecStart من ملفات الوحدات (grep على /etc/systemd/system) ---"
for f in /etc/systemd/system/smartfrind-*.service; do
    [ -f "$f" ] || continue
    echo "------------------------------------------------------------"
    echo "[$f]"
    grep -E '^(Description|ExecStart)' "$f" || true
done

echo
log "--- [4] البحث عن smartfriend_unified.db داخل /opt/smartfrind ---"
grep -R "smartfriend_unified.db" /opt/smartfrind 2>/dev/null | head -n 40 || \
    warn "لا يوجد أي إشارة مباشرة لـ smartfriend_unified.db داخل /opt/smartfrind (مبدئياً)."

echo
log "--- [5] البحث عن sqlite/DB داخل /opt/smartfrind/app ---"
grep -R "sqlite" /opt/smartfrind/app 2>/dev/null | head -n 40 || \
    warn "لا توجد أسطر sqlite ظاهرة في أول 40 سطر بحث – قد تكون الـ DB معرفة في env أو config آخر."

echo
log "=== انتهى sf_legacy_diag.sh – لا تعديلات تمت، فقط تقرير. ==="
