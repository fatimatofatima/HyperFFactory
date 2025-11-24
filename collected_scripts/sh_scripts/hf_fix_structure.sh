#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok()   { echo "   [OK]   $*"; }
warn() { echo "   [WARN] $*"; }

# جذر Hyper Factory على السيرفر
HF_ROOT_DEFAULT="/root/hyper-factory"
HF_ROOT="${1:-$HF_ROOT_DEFAULT}"

log "Hyper Factory root: $HF_ROOT"

if [ ! -d "$HF_ROOT" ]; then
  echo "❌ لا يوجد مجلد Hyper Factory في: $HF_ROOT"
  echo "   عدّل المسار في السكربت أو مرّره كوسيط:  bash /root/hf_fix_structure.sh /مسار/آخر"
  exit 1
fi

cd "$HF_ROOT"

log "1) فحص المجلدات الأساسية طبقًا للريبو"
BASE_DIRS=(
  "ai"
  "apps"
  "apps/backend_coach"
  "config"
  "scripts"
  "scripts/core"
  "scripts/ai"
)

for d in "${BASE_DIRS[@]}"; do
  if [ -d "$d" ]; then
    ok "موجود: $d"
  else
    warn "ناقص أو لم يُنشأ بعد: $d"
  fi
done

log "2) تجهيز هيكل البيانات الرسمي تحت data/"
DATA_DIR="$HF_ROOT/data"
mkdir -p "$DATA_DIR"

# طبقة lakehouse
LAKEHOUSE_DIRS=(
  "lakehouse/raw"
  "lakehouse/cleansed"
  "lakehouse/semantic"
  "lakehouse/serving"
)

# طبقة خط الإنتاج الأساسي
BASIC_PIPELINE_DIRS=(
  "inbox"
  "raw"
  "processed"
  "semantic"
  "serving"
  "factory"
  "knowledge"
)

for d in "${LAKEHOUSE_DIRS[@]}"; do
  mkdir -p "$DATA_DIR/$d"
  ok "جاهز: data/$d"
done

for d in "${BASIC_PIPELINE_DIRS[@]}"; do
  mkdir -p "$DATA_DIR/$d"
  ok "جاهز: data/$d"
done

log "3) ضمان وجود logs/ و reports/ و var/"
mkdir -p "$HF_ROOT/logs" "$HF_ROOT/reports" "$HF_ROOT/var/tmp" "$HF_ROOT/var/run"
ok "logs/ و reports/ و var/* جاهزة"

log "4) فحص قواعد البيانات الأساسية"
FACTORY_DB="$DATA_DIR/factory/factory.db"
KNOW_DB="$DATA_DIR/knowledge/knowledge.db"

if [ -f "$FACTORY_DB" ]; then
  ok "factory.db موجود: $FACTORY_DB"
else
  warn "factory.db غير موجود في: $FACTORY_DB"
fi

if [ -f "$KNOW_DB" ]; then
  ok "knowledge.db موجود: $KNOW_DB"
else
  warn "knowledge.db غير موجود في: $KNOW_DB"
fi

log "5) استيراد بيانات قديمة (إن وجدت) من /root/hyper"
OLD_ROOT="/root/hyper"
if [ -d "$OLD_ROOT/data" ]; then
  IMPORT_DIR="$DATA_DIR/_import_from_old_hyper"
  mkdir -p "$IMPORT_DIR"
  log "نسخ بيانات قديمة من $OLD_ROOT/data إلى $IMPORT_DIR (بدون حذف القديم)"
  rsync -a "$OLD_ROOT/data/" "$IMPORT_DIR/" || warn "فشل نسخ /root/hyper/data إلى $IMPORT_DIR"
  ok "تم أخذ نسخة من /root/hyper/data إلى $IMPORT_DIR"
else
  warn "لم يتم العثور على /root/hyper/data – لا يوجد مصدر قديم للاستيراد"
fi

log "6) ملخص هيكل Hyper Factory (حتى 3 مستويات)"
if command -v tree >/dev/null 2>&1; then
  tree -L 3 "$HF_ROOT" || true
else
  warn "tree غير مثبت؛ سيتم استخدام find -maxdepth 3"
  find "$HF_ROOT" -maxdepth 3 -type d | sort
fi

log "7) عرض محتوى scripts/core و scripts/ai للمراجعة اليدوية"
if [ -d "scripts/core" ]; then
  echo "----- scripts/core -----"
  ls -la "scripts/core"
else
  warn "scripts/core غير موجود"
fi

if [ -d "scripts/ai" ]; then
  echo "----- scripts/ai -----"
  ls -la "scripts/ai"
else
  warn "scripts/ai غير موجود"
fi

log "اكتمل فحص/تصحيح هيكل Hyper Factory"
