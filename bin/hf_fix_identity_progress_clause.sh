#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
IDENT="$ROOT/docs/UNIFIED_FACTORY_LOGIN.md"
BACKUP_DIR="$ROOT/backups_identity"

if [[ ! -f "$IDENT" ]]; then
  echo "❌ ملف الهوية غير موجود: $IDENT"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
cp "$IDENT" "$BACKUP_DIR/UNIFIED_FACTORY_LOGIN.md.$TS.bak"
echo "✅ تم أخذ نسخة احتياطية: $BACKUP_DIR/UNIFIED_FACTORY_LOGIN.md.$TS.bak"

# لو النص موجود بالفعل، لا نكرر
if grep -q "إلزام تسجيل التقدّم" "$IDENT"; then
  echo "✅ عبارة 'إلزام تسجيل التقدّم' موجودة بالفعل في الهوية – لا حاجة لتعديل."
  exit 0
fi

cat >> "$IDENT" <<'BLOCK'

## 7. إلزام تسجيل التقدّم والمسارات والحالة في الخطة

1. **تسجيل التقدّم (Progress Logging Mandatory):**  
   - يجب على كل نموذج/خدمة/سكربت أن يكتب تقدّمه في:
     - ملفات تحت `reports/` (logs / JSON / summaries)
     - والسجلات تحت `db/meta/` عند الحاجة (مثل `hf_changes.db`).
   - أي خطوة تنفيذية مهمّة تتم بدون تسجيل تقدّمها تعتبر **مخالفة تشغيلية** لسياسة المصنع الموحّد.

2. **تسجيل المسارات (Path & Context Logging):**  
   - كل عملية إصلاح/فحص/تشغيل يجب أن تُسجّل مع:
     - اسم السكربت / الخدمة،
     - المسار الذي تعمل عليه داخل الهيكل،
     - وقت التنفيذ (timestamp)،
     - الحالة (نجاح / تحذير / فشل).
   - الهدف: تتبّع تاريخ التغييرات على الشجرة الموحدة بدون ضياع أي خطوة.

3. **ربط التقدّم بخريطة العمل (Plan-Aware Logging):**  
   - أي تغيير جوهري في الهيكل أو الخدمات يجب أن يُربط بـ:
     - بند واضح في وثائق الخطة (README/plan_status)،
     - وتحديث في `plan_status.md` يوضّح حالة التنفيذ (✅ / ⏭ / 🟡).
   - لا يُعتبر أي تغيّر "مكتمل" إلا إذا:
     - تم تنفيذه داخل الهيكل الموحّد،
     - وتم تسجيله في التقارير،
     - وتم عكسه في حالة الخطة.

BLOCK

echo "✅ تم إضافة بند 'إلزام تسجيل التقدّم' إلى docs/UNIFIED_FACTORY_LOGIN.md."
