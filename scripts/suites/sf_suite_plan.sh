#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
APP_ROOT="/opt/smartfriend-suite"
REPORT_DIR="${APP_ROOT}/reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="${REPORT_DIR}/sf_suite_plan_${TS}.txt"

divider() {
  echo "==================================================" | tee -a "$REPORT_FILE"
}

section() {
  divider
  echo "$1" | tee -a "$REPORT_FILE"
  divider
}

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$REPORT_FILE"
}

header() {
  divider
  echo "      SmartFriend Suite - خطة تنفيذ وتشخيص" | tee -a "$REPORT_FILE"
  divider
  echo "التاريخ : $(date)" | tee -a "$REPORT_FILE"
  echo "السيرفر : $(hostname)" | tee -a "$REPORT_FILE"
}

# =========================
# 1) حالة النظام
# =========================
system_section() {
  section "1) حالة النظام (Uptime / Load / Memory / Disk)"

  log "=== UPTIME / LOAD ==="
  uptime | tee -a "$REPORT_FILE"

  log "=== MEMORY (free -h) ==="
  free -h | tee -a "$REPORT_FILE"

  log "=== DISK USAGE (/, ${APP_ROOT}) ==="
  df -h / "${APP_ROOT}" | tee -a "$REPORT_FILE"
}

# =========================
# 2) خدمات SmartFriend
# =========================
services_section() {
  section "2) حصر وحدات SmartFriend (systemd units)"

  log "=== كل الوحدات المعرفة (list-unit-files) ==="
  systemctl list-unit-files 'sf-*' 'smartfrind-*' 'smartfriend-*' | tee -a "$REPORT_FILE"

  log "=== حالة الوحدات (status مختصر) ==="
  for u in $(systemctl list-units --type=service 'sf-*' 'smartfrind-*' 'smartfriend-*' --no-legend --all | awk '{print $1}' | sort -u); do
    echo "---- ${u} ----" | tee -a "$REPORT_FILE"
    systemctl status "$u" --no-pager | sed 's/^/    /' | tee -a "$REPORT_FILE"
    echo | tee -a "$REPORT_FILE"
  done
}

# =========================
# 3) قواعد البيانات
# =========================
db_section() {
  section "3) حصر قواعد البيانات (DB Inventory تحت ${APP_ROOT}/var/db)"

  DB_ROOT="${APP_ROOT}/var/db"

  if [[ ! -d "$DB_ROOT" ]]; then
    log "⚠️ مجلد قواعد البيانات غير موجود: $DB_ROOT"
    return 0
  fi

  log "📂 فحص المجلد: $DB_ROOT"

  mapfile -t DBS < <(find "$DB_ROOT" -maxdepth 3 -type f -name '*.db' | sort || true)

  if [[ "${#DBS[@]}" -eq 0 ]]; then
    log "ℹ️ لا توجد ملفات .db تحت $DB_ROOT"
    return 0
  fi

  log "✅ تم العثور على ${#DBS[@]} ملف قاعدة بيانات:"
  for db in "${DBS[@]}"; do
    echo "--------------------------------------------------" | tee -a "$REPORT_FILE"
    echo "📄 DB: $db" | tee -a "$REPORT_FILE"
    du -h "$db" 2>/dev/null | tee -a "$REPORT_FILE" || true

    if command -v sqlite3 >/dev/null 2>&1; then
      echo "   الجداول والسجلات:" | tee -a "$REPORT_FILE"
      TABLES=$(sqlite3 "$db" ".tables" 2>/dev/null || true)
      if [[ -z "$TABLES" ]]; then
        echo "   (لا توجد جداول أو تعذر قراءتها)" | tee -a "$REPORT_FILE"
      else
        for tbl in $TABLES; do
          ROWS=$(sqlite3 "$db" "SELECT COUNT(*) FROM \"$tbl\";" 2>/dev/null || echo "?")
          echo "   - جدول: $tbl => عدد السجلات: $ROWS" | tee -a "$REPORT_FILE"
        done
      fi
    else
      echo "   (sqlite3 غير متوفر – لا يمكن عدّ الجداول/السجلات حالياً)" | tee -a "$REPORT_FILE"
      echo "   ✔ فقط تم حصر الملف وحجمه." | tee -a "$REPORT_FILE"
    fi
  done

  section "4) ملخص قواعد البيانات"
  echo "إجمالي عدد ملفات قواعد البيانات (.db): ${#DBS[@]}" | tee -a "$REPORT_FILE"
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ملاحظة: لتفعيل عدّ الجداول والسجلات، قم بتثبيت sqlite3 ثم إعادة تشغيل السكربت:" | tee -a "$REPORT_FILE"
    echo "  apt-get update && apt-get install -y sqlite3" | tee -a "$REPORT_FILE"
  fi
}

# =========================
# MAIN
# =========================
header
system_section
services_section
db_section

echo | tee -a "$REPORT_FILE"
log "تم إنشاء التقرير: $REPORT_FILE"
