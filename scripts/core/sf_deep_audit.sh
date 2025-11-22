#!/usr/bin/env bash
set -Eeuo pipefail

OUT_BASE="/opt/report"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${OUT_BASE}/sf_deep_audit_${TS}"
SYS_FILE="${OUT_DIR}/system_snapshot.txt"
ARCHIVE="${OUT_BASE}/sf_deep_audit_${TS}.tar.gz"

mkdir -p "${OUT_DIR}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "إنشاء Snapshot للنظام في: ${SYS_FILE}"

{
    echo "==== DATE ===="
    date
    echo

    echo "==== UNAME ===="
    uname -a
    echo

    echo "==== LSB_RELEASE ===="
    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -a || true
    else
        echo "lsb_release غير مثبت"
    fi
    echo

    echo "==== UPTIME ===="
    uptime || true
    echo

    echo "==== DF -H ===="
    df -h || true
    echo

    echo "==== FREE -H ===="
    free -h || true
    echo

    echo "==== TOP PROCESSES (by mem) ===="
    ps aux --sort=-%mem | head -n 25 || true
    echo

    echo "==== SYSTEMD SERVICES (active) ===="
    systemctl list-units --type=service --state=running || true
    echo
} > "${SYS_FILE}"

log "تجهيز قائمة المسارات المستهدفة للفحص"

CANDIDATES=(
    "/opt/smartfriend-suite"
    "/opt/smartfrind"
    "/opt/ffactory"
    "/srv/factory"
    "/root/Psmart"
    "/etc/smartfriend"
    "/opt"
)

ROOTS=()
for d in "${CANDIDATES[@]}"; do
    if [ -d "$d" ]; then
        ROOTS+=("$d")
    fi
done

if [ "${#ROOTS[@]}" -eq 0 ]; then
    log "لم يتم العثور على أي مسارات من القائمة. سيتم استخدام /opt كخيار افتراضي."
    ROOTS=("/opt")
fi

log "المسارات التي سيتم فحصها:"
for r in "${ROOTS[@]}"; do
    echo "  - $r"
done

log "تشغيل سكربت البايثون /root/sf_deep_audit.py"
python3 /root/sf_deep_audit.py "${OUT_DIR}" "${ROOTS[@]}"

log "إنشاء أرشيف التقرير: ${ARCHIVE}"
cd "${OUT_BASE}"
tar -czf "${ARCHIVE}" "$(basename "${OUT_DIR}")"

log "اكتمل الفحص الشامل."
log "مسار مجلد التقرير: ${OUT_DIR}"
log "ملف الأرشيف المضغوط: ${ARCHIVE}"
