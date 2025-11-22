#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="/opt/smartfriend-suite/var/db"
REPORT_DIR="/opt/report"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORT_DIR/sf_brain_diag_${TS}.log"

log() { echo "[$(date '+%F %T')] $*"; }
section() {
  echo
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║ $*"
  echo "╚══════════════════════════════════════════════════════╝"
  echo
}

# توجيه الخرج للتقرير + الشاشة
exec > >(tee -a "$REPORT_FILE") 2>&1

section "SmartFriend Brain DB Diagnostics"
log "BASE_DIR = $BASE_DIR"
log "REPORT_FILE = $REPORT_FILE"

if [ ! -d "$BASE_DIR" ]; then
  log "WARNING: المجلد $BASE_DIR غير موجود"
  exit 1
fi

section "قائمة قواعد البيانات الموجودة"
find "$BASE_DIR" -maxdepth 1 -type f -name '*.db' -print | sort || true

DB_LIST=()
while IFS= read -r db; do
  DB_LIST+=("$db")
done < <(find "$BASE_DIR" -maxdepth 1 -type f -name '*.db' -print | sort || true)

if [ "${#DB_LIST[@]}" -eq 0 ]; then
  log "لا توجد ملفات .db في $BASE_DIR – لا يوجد شيء لفحصه."
  exit 0
fi

for db in "${DB_LIST[@]}"; do
  section "تشخيص القاعدة: $db"

  if ! command -v sqlite3 >/dev/null 2>&1; then
    log "ERROR: sqlite3 غير مثبت على النظام."
    exit 1
  fi

  log "حجم الملف:"
  ls -lh "$db" || true

  log "قائمة الجداول/views داخل القاعدة:"
  sqlite3 "$db" <<'SQL'
.headers on
.mode column
SELECT name AS object_name, type
FROM sqlite_master
WHERE type IN ('table','view')
ORDER BY type, name;
SQL

done

section "انتهاء التشخيص"
log "تم إنشاء التقرير في: $REPORT_FILE"
