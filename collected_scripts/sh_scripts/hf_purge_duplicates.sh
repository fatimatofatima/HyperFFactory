#!/bin/bash
set -e

UNIQUE_DIR="/root/hyper-factory-optimized"

echo "🧹 Hyper-Factory Purge"
echo "======================"
echo "سيتم الاحتفاظ فقط بالمجلد:"
echo "  $UNIQUE_DIR"
echo

# 1) فحص مجلد الملفات الفريدة
if [ ! -d "$UNIQUE_DIR" ]; then
  echo "❌ مجلد الملفات الفريدة غير موجود: $UNIQUE_DIR"
  exit 1
fi

UNIQUE_COUNT=$(find "$UNIQUE_DIR" -type f 2>/dev/null | wc -l || echo 0)
echo "📊 عدد الملفات داخل المجلد الفريد: $UNIQUE_COUNT"
if [ "$UNIQUE_COUNT" -lt 1000 ]; then
  echo "⚠️ تحذير: عدد الملفات أقل من المتوقع، تأكد أن هذا هو المجلد الصحيح قبل الحذف."
fi
echo

# 2) تجميع المجلدات المرشحة للحذف
CANDIDATES=()

# مجلد الأساس
[ -d "/root/hyper-factory" ] && CANDIDATES+=("/root/hyper-factory")

# مجلدات نسخ ودمج
[ -d "/root/hyper-factory-backups" ] && CANDIDATES+=("/root/hyper-factory-backups")
for d in /root/hyper-factory-backup-* /root/hyper-factory-backup-direct-* /root/hyper-factory-unified /root/hyper-factory-merged; do
  if [ -d "$d" ]; then
    CANDIDATES+=("$d")
  fi
done

# إزالة التكرار من القائمة
UNIQ_CANDIDATES=()
for d in "${CANDIDATES[@]}"; do
  SKIP=0
  for u in "${UNIQ_CANDIDATES[@]}"; do
    if [ "$d" = "$u" ]; then
      SKIP=1
      break
    fi
  done
  [ $SKIP -eq 0 ] && UNIQ_CANDIDATES+=("$d")
done

# استثناء المجلد الفريد لو ظهر في القائمة لأي سبب
FINAL_TARGETS=()
for d in "${UNIQ_CANDIDATES[@]}"; do
  if [ "$d" = "$UNIQUE_DIR" ]; then
    continue
  fi
  FINAL_TARGETS+=("$d")
done

if [ ${#FINAL_TARGETS[@]} -eq 0 ]; then
  echo "ℹ️ لا توجد مجلدات مرشحة للحذف تحت /root/hyper-factory* (باستثناء المجلد الفريد)."
  exit 0
fi

echo "📦 المجلدات المرشحة للحذف النهائي:"
for d in "${FINAL_TARGETS[@]}"; do
  echo "  - $d"
done
echo

# 3) حساب الحجم قبل الحذف (تقريري)
echo "📏 تقدير الحجم قبل الحذف (du -sh):"
for d in "${FINAL_TARGETS[@]}"; do
  du -sh "$d" 2>/dev/null || true
done
echo

MODE="$1"

if [ "$MODE" != "--apply" ]; then
  echo "✅ هذا تشغيل تجريبي (Dry-run) فقط."
  echo "🔁 للتنفيذ الفعلي والحذف النهائي استخدم:"
  echo "   bash /root/hf_purge_duplicates.sh --apply"
  exit 0
fi

echo "⚠️ تنبيه نهائي: سيتم الآن تنفيذ حذف نهائي (rm -rf) على المجلدات أعلاه."
echo "⏳ بدء الحذف..."

for d in "${FINAL_TARGETS[@]}"; do
  echo "🗑️ حذف: $d"
  rm -rf "$d"
done

echo
echo "✅ تم حذف كل المجلدات المرشحة."
echo "📊 المساحة بعد الحذف:"
df -h /
