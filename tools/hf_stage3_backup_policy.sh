#!/usr/bin/env bash
# ============================================
# HF Stage 3 – Backup Policy Closure
# ============================================
# الهدف:
#   - مسح فعلي سريع لمسارات قواعد البيانات والبيانات الحرجة
#     * HyperFFactory
#     * SmartFriend Suite
#     * smartfrind القديمة
#     * ffactory (قراءة فقط)
#   - رصد سكربتات/خدمات/تايمرات النسخ الاحتياطي الموجودة حاليًا
#   - توليد ملف سياسة نسخ احتياطي موحّدة داخل HyperFFactory/config
#   - وضع مهمة backup_policy في hf_tasks.db على DONE
#
# ملاحظات:
#   - لا يغيّر أي ملفات داخل /opt/ffactory أو /opt/smartfriend-suite أو /var/lib/smartfrind
#   - كل التعديلات تقتصر على /root/HyperFFactory و /root/backups فقط

set -euo pipefail

HYPER_ROOT="/root/HyperFFactory"
cd "$HYPER_ROOT" || {
  echo "❌ لا يمكن الدخول إلى $HYPER_ROOT"
  exit 1
}

TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${HYPER_ROOT}/reports"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/hf_stage3_backup_policy_${TS}.log"

CONFIG_DIR="${HYPER_ROOT}/config"
mkdir -p "$CONFIG_DIR"
BACKUP_POLICY_FILE="${CONFIG_DIR}/hf_backup_policy_manifest_${TS}.txt"
BACKUP_POLICY_LATEST="${CONFIG_DIR}/hf_backup_policy_manifest_latest.txt"

# مجلد افتراضي للنسخ الاحتياطي (لن نلمس شيء داخله الآن)
BACKUP_ROOT="/root/backups"
mkdir -p "$BACKUP_ROOT"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "====================================================="
echo "HF Stage 3 – Backup Policy"
echo "====================================================="
echo "ROOT          : $HYPER_ROOT"
echo "LOG_FILE      : $LOG_FILE"
echo "POLICY_FILE   : $BACKUP_POLICY_FILE"
echo "BACKUP_ROOT   : $BACKUP_ROOT"
echo "TIME          : $(date '+%Y-%m-%d %H:%M:%S %z')"
echo

sep() {
  echo
  echo "-----------------------------------------------------"
  echo "$1"
  echo "-----------------------------------------------------"
}

# ------------------------------------------------------
# 1) مسح مسارات قواعد البيانات الفعلية (قراءة فقط)
# ------------------------------------------------------
sep "1) اكتشاف قواعد البيانات والبيانات الحرجة (Discovery – read-only)"

echo "[A] HyperFFactory DB roots:"
if [[ -d "${HYPER_ROOT}/var/db" ]]; then
  echo " - ${HYPER_ROOT}/var/db"
  find "${HYPER_ROOT}/var/db" -maxdepth 3 -type f -name '*.db' -printf '   DB: %p\n' || true
fi
if [[ -d "${HYPER_ROOT}/db/meta" ]]; then
  echo " - ${HYPER_ROOT}/db/meta"
  find "${HYPER_ROOT}/db/meta" -maxdepth 2 -type f -name '*.db' -printf '   META_DB: %p\n' || true
fi

echo
echo "[B] SmartFriend Suite DB roots (/opt/smartfriend-suite/var/db):"
if [[ -d "/opt/smartfriend-suite/var/db" ]]; then
  find "/opt/smartfriend-suite/var/db" -maxdepth 2 -type f -name '*.db' -printf '   SF_DB: %p\n' || true
else
  echo "   ℹ️ لا يوجد /opt/smartfriend-suite/var/db"
fi

echo
echo "[C] Legacy smartfrind DB roots (/var/lib/smartfrind):"
if [[ -d "/var/lib/smartfrind" ]]; then
  find "/var/lib/smartfrind" -maxdepth 2 -type f -name '*.db' -printf '   LEGACY_DB: %p\n' || true
else
  echo "   ℹ️ لا يوجد /var/lib/smartfrind"
fi

echo
echo "[D] ffactory (قراءة فقط – مسارات مؤشرّة فقط):"
/bin/ls -1 /opt/ffactory 2>/dev/null || echo "   ℹ️ لا يوجد /opt/ffactory أو لا يمكن قراءته"

# ------------------------------------------------------
# 2) رصد سكربتات / خدمات / تايمرات النسخ الاحتياطي
# ------------------------------------------------------
sep "2) رصد منظومة النسخ الاحتياطي الحالية (خدمات/تايمرات/سكربتات)"

echo "[A] systemd units ذات علاقة بالـ backup:"
systemctl list-unit-files '*backup*.service' '*backup*.timer' 2>/dev/null || echo "   ℹ️ systemctl list-unit-files فشل"

echo
echo "[B] systemd units مرتبطة ب ffactory backup:"
systemctl list-unit-files 'ffactory-backup.*' 'ffactory-snapshot.*' 2>/dev/null || echo "   ℹ️ لا يمكن قراءة وحدة ffactory-*"

echo
echo "[C] cron (بحث عن backup):"
grep -R --line-number -i "backup" /etc/cron.* 2>/dev/null | sed 's/^/   /' || echo "   ℹ️ لا توجد إشارات backup في /etc/cron.* (أو لا يمكن قراءتها)"

echo
echo "[D] سكربتات backup ضمن /root (عمق 3):"
find /root -maxdepth 3 -type f -iname '*backup*.sh' -printf '   SCRIPT: %p\n' 2>/dev/null || echo "   ℹ️ لا توجد سكربتات backup تحت /root (عمق 3)"

# ------------------------------------------------------
# 3) توليد ملف سياسة النسخ الاحتياطي داخل HyperFFactory/config
# ------------------------------------------------------
sep "3) توليد ملف سياسة النسخ الاحتياطي الموحدة (Manifest)"

{
  echo "# ================================================"
  echo "# HyperFFactory – Unified Backup Policy Manifest"
  echo "# Generated at: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "# This file هو توصيف منطقي للسياسة المتفق عليها،"
  echo "# التنفيذ الفعلي (cron/systemd) يتم في مراحل أخرى."
  echo "# ================================================"
  echo
  echo "[ROOTS]"
  echo "HYPERFFACTORY_ROOT=${HYPER_ROOT}"
  echo "HYPERFFACTORY_DB_ROOT=${HYPER_ROOT}/var/db"
  echo "HYPERFFACTORY_META_DB_ROOT=${HYPER_ROOT}/db/meta"
  echo "SMARTFRIEND_DB_ROOT=/opt/smartfriend-suite/var/db"
  echo "SMARTFRIND_LEGACY_DB_ROOT=/var/lib/smartfrind"
  echo "FFACTORY_ROOT=/opt/ffactory"
  echo "BACKUP_ROOT=${BACKUP_ROOT}"
  echo
  echo "[POLICY]"
  echo "# 1) HyperFFactory DBs:"
  echo "#    - backup إلى: \${BACKUP_ROOT}/hyper-ffactory/db/ (كل *.db تحت var/db و db/meta)"
  echo "#    - تكرار مقترح: يومي + قبل أي تغييرات كبرى."
  echo
  echo "# 2) SmartFriend Suite DBs:"
  echo "#    - backup إلى: \${BACKUP_ROOT}/smartfriend-suite/db/"
  echo "#    - يحترم المسار الرسمي الموحد smartfriend_unified.db."
  echo
  echo "# 3) Legacy smartfrind DBs:"
  echo "#    - backup إلى: \${BACKUP_ROOT}/smartfrind-legacy/db/"
  echo "#    - للمرجعية فقط (لا تعديل على النظام القديم)."
  echo
  echo "# 4) ffactory:"
  echo "#    - backup/ snapshot يتم عبر خدمات ffactory-backup / ffactory-snapshot الموجودة."
  echo "#    - هذا الملف لا يغيّر أي إعداد داخل ffactory; فقط يعرّف سياسة عليا."
  echo
  echo "[IMPLEMENTATION_NOTES]"
  echo "# - Stage 3 يغلق التصميم المنطقي للسياسة."
  echo "# - ربط السياسة فعليًا بـ cron/systemd timers سيتم في Stage 8 (Schedulers)."
} > "$BACKUP_POLICY_FILE"

# عمل symlink/نسخة "latest" داخل config لسهولة الرجوع
cp -f "$BACKUP_POLICY_FILE" "$BACKUP_POLICY_LATEST"

echo "✅ تم توليد ملف سياسة النسخ الاحتياطي:"
echo "   - $BACKUP_POLICY_FILE"
echo "   - (نسخة latest): $BACKUP_POLICY_LATEST"

# ------------------------------------------------------
# 4) تحديث مهمة backup_policy في hf_tasks.db إلى DONE
# ------------------------------------------------------
sep "4) تحديث حالة مهمة backup_policy في hf_tasks.db → DONE"

TASKS_DB="${HYPER_ROOT}/db/meta/hf_tasks.db"

if [[ ! -f "$TASKS_DB" ]]; then
  echo "⚠️ لم يتم العثور على قاعدة المهام: $TASKS_DB"
  echo "   لن يتم تعديل حالة المهام."
else
  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "⚠️ أداة sqlite3 غير مثبتة – لا يمكن تعديل حالة المهام."
  else
    echo "[i] استخدام قاعدة المهام: $TASKS_DB"

    echo
    echo "[A] حالة المهام قبل التحديث:"
    sqlite3 -header -column "$TASKS_DB" "
      SELECT id,actor,scope,status,priority,title,created_at,updated_at
      FROM tasks
      ORDER BY id;
    " || echo "⚠️ خطأ أثناء قراءة المهام قبل التحديث."

    echo
    echo "[B] تعيين backup_policy إلى DONE (إن لم تكن DONE)..."
    sqlite3 "$TASKS_DB" "
      UPDATE tasks
      SET status='DONE',
          updated_at=CURRENT_TIMESTAMP
      WHERE scope='backup_policy'
        AND status <> 'DONE';
    " || echo "⚠️ خطأ أثناء تحديث backup_policy."

    echo
    echo "[C] حالة المهام بعد التحديث:"
    sqlite3 -header -column "$TASKS_DB" "
      SELECT id,actor,scope,status,priority,title,created_at,updated_at
      FROM tasks
      ORDER BY id;
    " || echo "⚠️ خطأ أثناء قراءة المهام بعد التحديث."
  fi
fi

# ------------------------------------------------------
# 5) ملخص المرحلة
# ------------------------------------------------------
sep "5) ملخص HF Stage 3 – Backup Policy"

echo "ROOT            : $HYPER_ROOT"
echo "LOG_FILE        : $LOG_FILE"
echo "POLICY_FILE     : $BACKUP_POLICY_FILE"
echo "POLICY_LATEST   : $BACKUP_POLICY_LATEST"
echo "BACKUP_ROOT     : $BACKUP_ROOT"
echo "TASKS_DB        : $TASKS_DB"
echo
echo "✅ انتهت مرحلة Stage 3 (Backup Policy) على مستوى HyperFFactory."
echo "   - السياسة موثّقة في ملف manifest داخل config."
echo "   - التنفيذ الزمني (cron/timers) سيكون في Stage 8."
