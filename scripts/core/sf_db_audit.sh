#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_audit"
LOG="${OUT_DIR}/sf_db_audit_${TS}.log"

mkdir -p "$OUT_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
sec(){ echo -e "\n===== $* =====" | tee -a "$LOG"; }

sec "DB audit started"
log "Timestamp: ${TS}"
log "Host: $(hostname)"
log "Kernel: $(uname -r)"

# تحقق من وجود sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
  sec "sqlite3 not found"
  log "ERROR: sqlite3 غير مثبت. ثبّت الحزمة sqlite3 ثم أعد تشغيل السكربت."
  exit 1
fi

# تجميع قائمة قواعد البيانات المستهدفة
sec "Collecting target SQLite DBs"

SUITE_DB_DIR="/opt/smartfriend-suite/var/db"
BC_DB_DIR="/opt/BRAIN_CORE/memory"

declare -a DBS=()

add_db() {
  local path="$1"
  if [ -f "$path" ]; then
    log "Found DB candidate: $path"
    DBS+=("$path")
  fi
}

# قواعد بيانات SmartFriend Suite
add_db "${SUITE_DB_DIR}/smartfriend_unified.db"

if [ -d "$SUITE_DB_DIR" ]; then
  while IFS= read -r -d '' f; do
    add_db "$f"
  done < <(find "$SUITE_DB_DIR" -maxdepth 1 -type f -name '*.db' -print0 || true)
else
  log "Note: ${SUITE_DB_DIR} does not exist."
fi

# قواعد بيانات BRAIN_CORE
add_db "${BC_DB_DIR}/shared.db"

if [ -d "$BC_DB_DIR" ]; then
  while IFS= read -r -d '' f; do
    add_db "$f"
  done < <(find "$BC_DB_DIR" -maxdepth 1 -type f -name '*.db' -print0 || true)
else
  log "Note: ${BC_DB_DIR} does not exist."
fi

# إزالة التكرار
declare -A SEEN=()
declare -a FINAL_DBS=()

for db in "${DBS[@]}"; do
  if [[ -z "${SEEN[$db]+x}" ]]; then
    SEEN["$db"]=1
    FINAL_DBS+=("$db")
  fi
done

if [ "${#FINAL_DBS[@]}" -eq 0 ]; then
  sec "No DBs found"
  log "لم يتم العثور على أي ملفات SQLite في المسارات المستهدفة."
  log "تم إنهاء الفحص بدون تغييرات."
  exit 0
fi

sec "Target DB list"
for db in "${FINAL_DBS[@]}"; do
  log "DB: $db"
done

# دالة فحص قاعدة بيانات واحدة
audit_db() {
  local db="$1"

  sec "Auditing DB: $db"

  if [ ! -f "$db" ]; then
    log "WARN: الملف غير موجود: $db (تخطّي)"
    return 0
  fi

  log "File info:"
  ls -lh "$db" | tee -a "$LOG"

  log "Owner & permissions:"
  stat "$db" 2>/dev/null | tee -a "$LOG" || log "stat failed (non-critical)."

  log "PRAGMA quick_check:"
  if ! sqlite3 "$db" "PRAGMA quick_check;" >>"$LOG" 2>&1; then
    log "ERROR: quick_check فشل لهذه القاعدة. راجع السطور السابقة في اللوج."
  fi

  log "Listing tables:"
  if ! sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" >>"$LOG" 2>&1; then
    log "ERROR: فشل في قراءة قائمة الجداول."
  fi

  local tables
  tables="$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null || true)"

  if [ -z "$tables" ]; then
    log "No tables found or failed to read tables (قد تكون القاعدة فارغة أو تالفة)."
    return 0
  fi

  log "Row counts per table:"
  local t count
  for t in $tables; do
    count="$(sqlite3 "$db" "SELECT COUNT(*) FROM \"$t\";" 2>/dev/null || echo "ERR")"
    log "  $t: $count"
  done
}

# تنفيذ الفحص لكل قاعدة بيانات
for db in "${FINAL_DBS[@]}"; do
  audit_db "$db"
done

sec "Summary"
log "Total DBs audited: ${#FINAL_DBS[@]}"
for db in "${FINAL_DBS[@]}"; do
  log "  - $db"
done

sec "DB audit finished"
log "Output log: ${LOG}"
