#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="/root/sf_migration"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sf_migrate_phase2_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

log "===== بدء مرحلة ٢: نقل/دمج SmartFrind داخل smartfriend-suite (بدون symlink) ====="

SUITE_DIR="/opt/smartfriend-suite"
APP_DIR="$SUITE_DIR/smartfrind"
VENV_OLD="$APP_DIR/venv"
VENV_NEW="$SUITE_DIR/venv"

DB_VAR_DIR="$SUITE_DIR/var/db"
DB_VAR="$DB_VAR_DIR/smartfriend_unified.db"

BACKUP_ROOT="/var/backups/sf_migration_${TS}"
mkdir -p "$BACKUP_ROOT"

########################################
# A) توحيد قاعدة البيانات smartfriend_unified.db
########################################
log "[DB] بدء اختيار أكبر smartfriend_unified.db مرشح..."

DB_CANDIDATES=(
  "/opt/smartfriend-suite-backup-20251109-025421/data/smartfriend_unified.db"
  "/opt/smartfriend-suite-backup/data/smartfriend_unified.db"
  "/opt/smartfriend-suite/data/smartfriend_unified.db"
  "$DB_VAR"
)

BEST_DB=""
BEST_SIZE=0

for p in "${DB_CANDIDATES[@]}"; do
  if [ -f "$p" ]; then
    size=$(stat -c '%s' "$p" 2>/dev/null || echo 0)
    log "[DB] مرشح: $p (حجم: $size)"
    if [ "$size" -gt "$BEST_SIZE" ]; then
      BEST_SIZE="$size"
      BEST_DB="$p"
    fi
  fi
done

if [ -n "$BEST_DB" ]; then
  log "[DB] اختيار أكبر قاعدة بيانات: $BEST_DB (حجم: $BEST_SIZE)"
  mkdir -p "$DB_VAR_DIR"
  if [ -f "$DB_VAR" ]; then
    log "[DB] نسخ النسخة الحالية إلى النسخ الاحتياطية: $BACKUP_ROOT/original_smartfriend_unified.db"
    cp -a "$DB_VAR" "$BACKUP_ROOT/original_smartfriend_unified.db"
  fi
  log "[DB] نسخ قاعدة البيانات المختارة إلى: $DB_VAR"
  cp -a "$BEST_DB" "$DB_VAR"
else
  log "[DB] تحذير: لم يتم العثور على أي smartfriend_unified.db مرشحة."
fi

########################################
# B) إصلاح التصاريح للمستخدم smartfrind
########################################
log "[PERM] إصلاح التصاريح للمسارات الأساسية..."

fix_perm_dir() {
  local d="$1"
  if [ -d "$d" ]; then
    log "[PERM] ضبط الملكية والصلاحيات على: $d"
    chown -R smartfrind:smartfrind "$d"
    find "$d" -type d -exec chmod 755 {} \;
  fi
}

fix_perm_dir "$SUITE_DIR"
fix_perm_dir "$APP_DIR"
fix_perm_dir "/var/lib/smartfrind"
fix_perm_dir "/var/log/smartfrind"

########################################
# C) نقل venv فعليًا من smartfrind/venv إلى smartfriend-suite/venv
########################################
log "[VENV] فحص حالة venv..."

if [ -d "$VENV_OLD" ] && [ ! -d "$VENV_NEW" ]; then
  log "[VENV] نقل فعلي للـ venv من: $VENV_OLD إلى: $VENV_NEW (بدون symlink)"
  mv "$VENV_OLD" "$VENV_NEW"
elif [ -d "$VENV_NEW" ]; then
  log "[VENV] تم العثور على venv في: $VENV_NEW — لن يتم نقل شيء."
elif [ ! -d "$VENV_OLD" ] && [ ! -d "$VENV_NEW" ]; then
  log "[VENV] تحذير: لا يوجد venv في $VENV_OLD ولا في $VENV_NEW — تحتاج إعداد venv يدوي لاحقًا."
fi

########################################
# D) تحديث وحدات systemd لاستعمال /opt/smartfriend-suite/venv بدلاً من smartfrind/venv
########################################
log "[SYSTEMD] تحديث وحدات systemd لاستخدام venv الموحد (بدون symlink)..."

UNIT_GLOB1="/etc/systemd/system/smartfrind-*.service"
UNIT_GLOB2="/etc/systemd/system/smartfriend-*.service"

shopt -s nullglob
UNITS=( $UNIT_GLOB1 $UNIT_GLOB2 )
shopt -u nullglob

if [ "${#UNITS[@]}" -eq 0 ]; then
  log "[SYSTEMD] لا توجد وحدات smartfrind*/smartfriend* في /etc/systemd/system."
else
  for u in "${UNITS[@]}"; do
    log "[SYSTEMD] تعديل الوحدة: $u"
    sed -i 's#/opt/smartfriend-suite/smartfrind/venv#/opt/smartfriend-suite/venv#g' "$u"
  done
fi

log "[SYSTEMD] إعادة تحميل daemon فقط (بدون تشغيل أي خدمة تلقائيًا)..."
systemctl daemon-reload

########################################
# E) نقل جذور smartfrind القديمة بعيدًا عن /opt
########################################
log "[LEGACY] نقل جذور smartfrind القديمة إلى مجلد نسخ احتياطي (لإخفاء الاسم من المسارات التشغيلية بدون حذف فعلي)..."

move_if_exists() {
  local src="$1"
  if [ -e "$src" ]; then
    local base
    base="$(basename "$src")"
    local dst="$BACKUP_ROOT/$base"
    log "[LEGACY] نقل: $src -> $dst"
    mv "$src" "$dst"
  fi
}

# /opt جذور باسم smartfrind
move_if_exists "/opt/smartfrind"
move_if_exists "/opt/smartfrind_backup_20251108_052245"
# جذور audit باسم smartfrind (سجلات قديمة)
move_if_exists "/srv/audit/smartfrind-20251104_031627"
move_if_exists "/srv/audit/smartfrind-20251104_031835"
move_if_exists "/srv/audit/smartfrind-20251104_033016"
move_if_exists "/srv/audit/smartfrind-20251104_033306"
move_if_exists "/srv/audit/smartfrind-20251104_033340"
move_if_exists "/srv/audit/smartfrind-20251104_034001"
move_if_exists "/srv/audit/smartfrind-20251104_034336"
move_if_exists "/srv/audit/smartfrind-20251104_035850"
move_if_exists "/srv/audit/smartfrind-20251104_041014"
move_if_exists "/srv/audit/smartfrind-20251104_041051"

log "[LEGACY] تم نقل الجذور القديمة إلى: $BACKUP_ROOT (لا يوجد rm -rf، فقط نقل)."

########################################
# F) ملخص نهائي
########################################
log "===== ملخص مرحلة ٢ ====="
log "• قاعدة البيانات الرسمية الآن (إن وُجد مرشح كبير): $DB_VAR"
log "• venv الموحد المتوقع: $VENV_NEW"
log "• مسار الكود التشغيلي: $APP_DIR (داخل smartfriend-suite)"
log "• الجذور القديمة باسم smartfrind تم نقلها إلى: $BACKUP_ROOT"

log "===== لا يوجد أي خدمة تم تشغيلها تلقائيًا في هذا السكربت ====="
log "عند الرغبة في الاختبار، يمكنك مثلاً تشغيل:"
log "  systemctl restart smartfriend-api.service || true"
log "  systemctl restart smartfriend-unified.service || true"
log "  systemctl restart smartfriend-smartcore.service || true"
log "  systemctl restart smartfrind-local.service smartfrind-advanced.service || true"
log "ثم فحص البورتات 8210/8211/8212/8220 يدوياً."

log "===== انتهاء مرحلة ٢ بنجاح (سكريبت فقط: نقل/دمج/تهيئة، بدون تشغيل خدمات) ====="

