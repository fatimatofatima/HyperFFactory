#!/usr/bin/env bash
set -Eeuo pipefail

# ===========================
# SmartFrind → Smartfriend-suite Migration
# دمج خدمات smartfrind داخل smartfriend-suite
# ===========================

OLD_ROOT="/opt/smartfrind"
SUITE_ROOT="/opt/smartfriend-suite"
NEW_ROOT="${SUITE_ROOT}/smartfrind"
BACKUP_DIR="/root"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/smartfrind_backup_${TIMESTAMP}.tar.gz"
LEFTOVERS_FILE="/root/smartfrind_leftovers_${TIMESTAMP}.txt"

log()  { echo "[SF-MIGRATE $(date +%H:%M:%S)] $*"; }
fail() { echo "[SF-MIGRATE ERROR] $*" >&2; exit 1; }

log "بدء عملية دمج smartfrind داخل smartfriend-suite"

# 1) تأكيد الصلاحيات
if [[ "$EUID" -ne 0 ]]; then
  fail "يجب تشغيل السكربت كمستخدم root."
fi

# 2) فحص المسارات
if [[ ! -d "$OLD_ROOT" ]]; then
  fail "المجلد ${OLD_ROOT} غير موجود. لا يوجد ما يتم نقله."
fi

if [[ ! -d "$SUITE_ROOT" ]]; then
  fail "المجلد ${SUITE_ROOT} غير موجود. يجب أن يكون smartfriend-suite مثبتًا في /opt/smartfriend-suite."
fi

if [[ -e "$NEW_ROOT" ]]; then
  fail "المسار الهدف ${NEW_ROOT} موجود بالفعل. تأكد من عدم وجود نسخة قديمة أو انقلها/احذفها يدويًا أولاً."
fi

log "البيئة صحيحة. OLD_ROOT=${OLD_ROOT}, SUITE_ROOT=${SUITE_ROOT}, NEW_ROOT=${NEW_ROOT}"

# 3) إنشاء باك-أب كامل
log "إنشاء باك-أب كامل لمجلد smartfrind في ${BACKUP_FILE} ..."
tar -czf "$BACKUP_FILE" -C /opt "smartfrind"
log "تم إنشاء الباك-أب بنجاح."

# 4) التقاط قائمة الخدمات الحالية
log "اكتشاف خدمات systemd المرتبطة بـ smartfrind ..."
mapfile -t SF_SERVICES < <(systemctl list-units 'smartfrind*.service' --all --no-legend 2>/dev/null | awk '{print $1}' || true)

if [[ "${#SF_SERVICES[@]}" -eq 0 ]]; then
  log "لم يتم العثور على خدمات تبدأ بـ smartfrind*. سنكمل النقل بدون تعديل خدمات."
else
  log "تم العثور على الخدمات التالية:"
  for s in "${SF_SERVICES[@]}"; do
    echo "  - $s"
  done

  # إيقاف وتعطيل الخدمات مؤقتًا
  for s in "${SF_SERVICES[@]}"; do
    log "إيقاف الخدمة: ${s}"
    systemctl stop "$s" || log "تحذير: تعذر إيقاف ${s} (ربما كانت متوقفة)."
    log "تعطيل الخدمة مؤقتًا: ${s}"
    systemctl disable "$s" || log "تحذير: تعذر تعطيل ${s}."
  done
fi

# 5) نقل مجلد smartfrind إلى داخل smartfriend-suite
log "نقل ${OLD_ROOT} إلى ${NEW_ROOT} ..."
mv "$OLD_ROOT" "$NEW_ROOT"
log "تم نقل المجلد بنجاح."

# 6) تعديل ملفات الخدمات لتشير إلى المسار الجديد
if [[ "${#SF_SERVICES[@]}" -gt 0 ]]; then
  log "تعديل ملفات systemd لتحديث المسارات من ${OLD_ROOT} إلى ${NEW_ROOT} ..."
  
  # نبحث عن ملفات الخدمات في /etc/systemd/system و /lib/systemd/system
  UNIT_PATHS=()
  while IFS= read -r f; do
    UNIT_PATHS+=("$f")
  done < <(grep -rl "$OLD_ROOT" /etc/systemd/system /lib/systemd/system 2>/dev/null || true)

  if [[ "${#UNIT_PATHS[@]}" -eq 0 ]]; then
    log "لم يتم العثور على ملفات خدمات تحتوي المسار ${OLD_ROOT}. قد تكون الخدمات تستدعي سكربتات وسيطة."
  else
    log "سيتم تعديل الملفات التالية:"
    for f in "${UNIT_PATHS[@]}"; do
      echo "  - $f"
      sed -i "s|${OLD_ROOT}|${NEW_ROOT}|g" "$f"
    done

    log "إعادة تحميل تعريفات systemd ..."
    systemctl daemon-reload

    # إعادة تفعيل وتشغيل الخدمات من المسار الجديد
    for s in "${SF_SERVICES[@]}"; do
      log "إعادة تفعيل الخدمة: ${s}"
      systemctl enable "$s" || log "تحذير: تعذر تفعيل ${s}."
      log "تشغيل الخدمة: ${s}"
      systemctl start "$s" || log "تحذير: تعذر تشغيل ${s} بعد التعديل. تحقق من logs."
    done
  fi
fi

# 7) إنشاء مسار placeholder مكان OLD_ROOT (اختياري – لتتبع الأثر فقط)
log "إنشاء مجلد placeholder فارغ في ${OLD_ROOT} لتأكيد أن المسار تم تفريغه ..."
mkdir -p "$OLD_ROOT"
echo "تم نقل مشروع smartfrind بالكامل إلى ${NEW_ROOT} ضمن smartfriend-suite في ${TIMESTAMP}." > "${OLD_ROOT}/MIGRATED_TO_SMARTFRIEND_SUITE.txt"

# 8) فحص المراجع المتبقية لمسار /opt/smartfrind
log "فحص المراجع المتبقية للمسار القديم /opt/smartfrind داخل /etc /opt /srv ..."
grep -R "/opt/smartfrind" /etc /opt /srv 2>/dev/null | tee "$LEFTOVERS_FILE" || true
log "تم حفظ نتائج البحث في: ${LEFTOVERS_FILE}"

log "انتهت عملية الدمج بنجاح (مع باك-أب كامل)."
log "راجع ملف ${LEFTOVERS_FILE} لمعرفة أي سكربتات أو إعدادات ما زالت تشير إلى المسار القديم."

exit 0
