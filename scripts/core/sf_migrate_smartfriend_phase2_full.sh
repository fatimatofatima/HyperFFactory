#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="/root/sf_migration"
LOG_FILE="${LOG_DIR}/phase2_full_${TS}.log"
UNIT_BACKUP_DIR="${LOG_DIR}/systemd_backup_${TS}"

mkdir -p "$LOG_DIR" "$UNIT_BACKUP_DIR"

log()  { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }
sec()  { echo -e "\n===== $* =====" | tee -a "$LOG_FILE"; }

sec "بدء مرحلة ٢: نقل/دمج smartfrind إلى smartfriend بدون symlink"

SUITE_ROOT="/opt/smartfriend-suite"

# المسارات القديمة
OLD_BASE="${SUITE_ROOT}/smartfrind"
OLD_APP_DIR="${OLD_BASE}/app"
OLD_VENV_DIR="${OLD_BASE}/venv"

# المسارات الجديدة الموحدة
NEW_BASE="${SUITE_ROOT}/smartfriend"
NEW_APP_DIR="${NEW_BASE}/app"
NEW_VENV_DIR="${NEW_BASE}/venv"

DB_VAR_DIR="${SUITE_ROOT}/var/db"
DEST_DB="${DB_VAR_DIR}/smartfriend_unified.db"

# 1) فحص وجود المسارات القديمة
sec "فحص المسارات القديمة والجديدة"

if [[ ! -d "$OLD_APP_DIR" ]]; then
    log "تحذير: مجلد الكود القديم غير موجود: $OLD_APP_DIR"
else
    log "مجلد الكود القديم موجود: $OLD_APP_DIR"
fi

if [[ ! -d "$OLD_VENV_DIR" ]]; then
    log "تحذير: مجلد venv القديم غير موجود: $OLD_VENV_DIR"
else
    log "مجلد venv القديم موجود: $OLD_VENV_DIR"
fi

mkdir -p "$NEW_BASE"
log "تجهيز المجلد الجديد: $NEW_BASE"

# 2) نسخ الكود إلى المسار الجديد
sec "نسخ الكود إلى المسار الجديد /smartfriend/app"

if [[ -d "$OLD_APP_DIR" ]]; then
    mkdir -p "$NEW_APP_DIR"
    if command -v rsync >/dev/null 2>&1; then
        log "استخدام rsync لنسخ الكود من $OLD_APP_DIR إلى $NEW_APP_DIR"
        rsync -a "$OLD_APP_DIR"/ "$NEW_APP_DIR"/ | tee -a "$LOG_FILE" || true
    else
        log "rsync غير متوفر، استخدام cp -a"
        cp -a "$OLD_APP_DIR"/. "$NEW_APP_DIR"/
    fi
    log "انتهى نسخ الكود إلى المسار الجديد."
else
    log "تخطي نسخ الكود لأن المجلد القديم غير موجود."
fi

# 3) نسخ venv إلى المسار الجديد
sec "نسخ venv إلى المسار الجديد /smartfriend/venv"

if [[ -d "$OLD_VENV_DIR" ]]; then
    if [[ -d "$NEW_VENV_DIR" ]]; then
        log "تنبيه: venv جديد موجود بالفعل: $NEW_VENV_DIR (لن يتم استبداله، فقط نبلغ)"
    else
        log "بدء نسخ venv من $OLD_VENV_DIR إلى $NEW_VENV_DIR (قد يستغرق وقتًا)"
        cp -a "$OLD_VENV_DIR" "$NEW_VENV_DIR"
        log "انتهى نسخ venv إلى المسار الجديد."
    fi
else
    log "تخطي نسخ venv لأن المجلد القديم غير موجود."
fi

# 4) دمج/توحيد قاعدة البيانات smartfriend_unified.db
sec "اختيار أكبر smartfriend_unified.db وجعلها الرسمية"

mkdir -p "$DB_VAR_DIR"

CANDIDATES=(
    "/opt/smartfriend-suite-backup-20251109-025421/data/smartfriend_unified.db"
    "/opt/smartfriend-suite-backup/data/smartfriend_unified.db"
    "/opt/smartfriend-suite/data/smartfriend_unified.db"
    "$DEST_DB"
)

best_db=""
best_size=0

for db in "${CANDIDATES[@]}"; do
    if [[ -f "$db" ]]; then
        size=$(stat -c %s "$db" 2>/dev/null || echo 0)
        log "مرشح DB: $db (حجم: $size بايت)"
        if (( size > best_size )); then
            best_size="$size"
            best_db="$db"
        fi
    fi
done

if [[ -n "$best_db" ]]; then
    log "أكبر DB تم العثور عليها: $best_db (حجم: $best_size بايت)"
    if [[ -f "$DEST_DB" && "$best_db" != "$DEST_DB" ]]; then
        BACKUP_DB="${DEST_DB}.bak_${TS}"
        log "إنشاء نسخة احتياطية من DB الحالية: $BACKUP_DB"
        cp -a "$DEST_DB" "$BACKUP_DB"
    fi

    if [[ "$best_db" != "$DEST_DB" ]]; then
        log "نسخ $best_db إلى المسار الرسمي $DEST_DB"
        cp -a "$best_db" "$DEST_DB"
    else
        log "المسار الرسمي يحتوي بالفعل على أكبر نسخة؛ لا حاجة للنسخ."
    fi
else
    log "لم يتم العثور على أي smartfriend_unified.db في المسارات المعروفة."
fi

# 5) إصلاح الملكيات والصلاحيات
sec "إصلاح المالك والصلاحيات للمسارات الجديدة"

# نحافظ حاليًا على مستخدم النظام smartfrind، يمكن إعادة تسميته لاحقًا لو حبيت
for path in "$NEW_BASE" "$DB_VAR_DIR" "/var/lib/smartfrind" "/var/log/smartfrind"; do
    if [[ -e "$path" ]]; then
        log "ضبط الملكية إلى smartfrind:smartfrind على $path"
        chown -R smartfrind:smartfrind "$path" || log "تنبيه: فشل chown على $path (تحقق يدويًا لاحقًا)"
    fi
done

for path in "$SUITE_ROOT" "$NEW_BASE" "$NEW_APP_DIR" "$NEW_VENV_DIR"; do
    if [[ -d "$path" ]]; then
        log "ضبط صلاحيات 755 على $path"
        chmod 755 "$path" || log "تنبيه: فشل chmod على $path (تحقق يدويًا لاحقًا)"
    fi
done

# 6) تعديل ملفات systemd لاستخدام المسارات الجديدة
sec "تعديل وحدات systemd لاستخدام /smartfriend و /smartfriend/venv بدلاً من smartfrind أو venv القديم"

SERVICE_DIR="/etc/systemd/system"

# دالة لعمل نسخة احتياطية للملف مرة واحدة فقط
backup_unit_once() {
    local f="$1"
    local base
    base="$(basename "$f")"
    if [[ ! -f "${UNIT_BACKUP_DIR}/${base}" ]]; then
        cp -a "$f" "${UNIT_BACKUP_DIR}/${base}"
        log "تم أخذ نسخة احتياطية من وحدة: $f -> ${UNIT_BACKUP_DIR}/${base}"
    fi
}

# استبدال /opt/smartfriend-suite/smartfrind → /opt/smartfriend-suite/smartfriend
mapfile -t units_old_app < <(grep -rl "/opt/smartfriend-suite/smartfrind" "$SERVICE_DIR" || true)
if (( ${#units_old_app[@]} > 0 )); then
    log "سيتم تعديل المسار /opt/smartfriend-suite/smartfrind في الوحدات التالية:"
    printf ' - %s\n' "${units_old_app[@]}" | tee -a "$LOG_FILE"
    for u in "${units_old_app[@]}"; do
        backup_unit_once "$u"
        sed -i 's#/opt/smartfriend-suite/smartfrind#/opt/smartfriend-suite/smartfriend#g' "$u"
    done
else
    log "لا توجد وحدات systemd تحتوي على /opt/smartfriend-suite/smartfrind."
fi

# استبدال /opt/smartfriend-suite/venv → /opt/smartfriend-suite/smartfriend/venv
mapfile -t units_old_venv < <(grep -rl "/opt/smartfriend-suite/venv" "$SERVICE_DIR" || true)
if (( ${#units_old_venv[@]} > 0 )); then
    log "سيتم تعديل المسار /opt/smartfriend-suite/venv في الوحدات التالية:"
    printf ' - %s\n' "${units_old_venv[@]}" | tee -a "$LOG_FILE"
    for u in "${units_old_venv[@]}"; do
        backup_unit_once "$u"
        sed -i 's#/opt/smartfriend-suite/venv#/opt/smartfriend-suite/smartfriend/venv#g' "$u"
    done
else
    log "لا توجد وحدات systemd تحتوي على /opt/smartfriend-suite/venv."
fi

# 7) إعادة تحميل وحدات systemd بدون تشغيل أي خدمة
sec "إعادة تحميل systemd (بدون تشغيل أو إيقاف أي خدمة)"

systemctl daemon-reload
log "تم تنفيذ systemctl daemon-reload."

sec "انتهاء مرحلة ٢ (نقل/دمج بدون symlink)"

log "المسار الجديد للتطبيق: $NEW_APP_DIR"
log "المسار الجديد لـ venv:   $NEW_VENV_DIR"
log "المسار الرسمي للـ DB:    $DEST_DB"
log "نسخ وحدات systemd الاحتياطية في: $UNIT_BACKUP_DIR"
log "للاطلاع على اللوج الكامل: cat $LOG_FILE"

echo
echo "مقترح: بعد التأكد من كل شيء، يمكنك تجربة تشغيل بعض الخدمات يدويًا، مثل:"
echo "  systemctl restart smartfriend-api.service || true"
echo "  systemctl restart smartfriend-smartcore.service || true"
echo "  systemctl restart smartfrind-gateway.service smartfrind-core.service || true"
echo "  systemctl status smartfriend-api.service smartfriend-smartcore.service smartfrind-gateway.service smartfrind-core.service"
echo
echo "ملاحظة: لم يتم تشغيل أو إيقاف أي خدمة تلقائيًا داخل هذا السكربت."
