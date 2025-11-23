#!/usr/bin/env bash
# HyperFFactory - Add Tasks/Quality/Experience/Errors sections to README & plan_status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
README="$ROOT_DIR/README.md"
PLAN_STATUS="$ROOT_DIR/plan_status.md"
BACKUP_DIR="$ROOT_DIR/backups/plan_updates"

mkdir -p "$BACKUP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"

echo "=================================================="
echo "📝 HyperFFactory – Update plan (Tasks/Quality/Experience/Errors)"
echo "📍 Root : $ROOT_DIR"
echo "🕒 Time : $TS"
echo "=================================================="

# 1) تأكيد وجود الملفات الأساسية
if [[ ! -f "$README" ]]; then
  echo "❌ README.md غير موجود في $ROOT_DIR" >&2
  exit 1
fi

if [[ ! -f "$PLAN_STATUS" ]]; then
  echo "❌ plan_status.md غير موجود في $ROOT_DIR" >&2
  exit 1
fi

# 2) أخذ نسخ احتياطية
README_BK="$BACKUP_DIR/README_$TS.before_tasks_quality.md"
PLAN_BK="$BACKUP_DIR/plan_status_$TS.before_tasks_quality.md"

cp "$README" "$README_BK"
cp "$PLAN_STATUS" "$PLAN_BK"

echo "✅ Backup:"
echo "   - $README_BK"
echo "   - $PLAN_BK"

# 3) تحديث README.md – إضافة قسم 8 إذا غير موجود
if grep -q '## 8. أنظمة المهام والجودة والخبرة والأخطاء' "$README"; then
  echo "ℹ️ قسم المهام/الجودة/الخبرة/الأخطاء موجود بالفعل في README.md – لن أضيفه مرة أخرى."
else
  echo "✏️ إضافة قسم 8 إلى README.md ..."
  cat >> "$README" <<'EOF_README'

## 8. أنظمة المهام والجودة والخبرة والأخطاء

هذه الأنظمة تعمل فوق HyperFFactory وتستخدم نفس سياسة الهيكل الموحّد وقاعدة "عدم حذف البيانات". الهدف: تتبّع ما يحدث (Tasks)، كيف يحدث (Quality)، من الذي ينفّذ (Experience)، وما الذي كسر (Errors).

### 8.1 نظام المهام (Tasks System)

- الهدف:
  - تسجيل كل مهمة مهمّة في المصنع (فحص، إصلاح، ترحيل، تكامل).
  - ربط المهام بالمدراء/العمّال (actors) والزمن والحالة.
- المبادئ:
  - كل مهمة يجب أن تحتوي على: `id، actor، scope، status، priority، created_at، updated_at`.
  - الحالات المسموح بها للمهام: `PLANNED، RUNNING، DONE، FAILED، SKIPPED`.
  - لا يتم حذف المهام نهائيًا، بل يتم تحديث حالتها فقط.
- التكامل مع الأنظمة الحالية:
  - يمكن ربط المهام بأحداث `hf_changes.db` (progress log).
  - يمكن لاحقًا إنشاء تقارير منطقية تجمع بين المهام والتقدّم الفعلي.

### 8.2 نظام الجودة (Quality System)

- الهدف:
  - قياس جودة تشغيل الأنظمة (SmartFriend / FFactory / HyperFFactory).
  - اكتشاف الفترات/السكربتات التي تسبب أعطال متكررة أو نتائج ضعيفة.
- المبادئ:
  - كل فحص جودة يجب أن يخزّن: `actor، check_name، result، score (0–100)، details، ts`.
  - لا توجد "نجاح/فشل" فقط؛ وإنما "درجة جودة" يمكن تتبّعها زمنيًا.
  - تقارير الجودة تعتمد على:
    - تقارير الصحة (health reports) الموجودة في `reports/`.
    - سجل التقدّم `hf_changes.db`.
- أمثلة لاستخدامه:
  - مقارنة جودة تشغيل SmartFriend عبر الأيام.
  - قياس استقرار ffactory stack بعد كل تحديث/إعادة تشغيل.

### 8.3 نظام الخبرة والتدريب (Experience & Training)

- الهدف:
  - إعطاء "مستوى خبرة" لكل Actor (مدير/عامل) حسب تاريخ نجاحه/أخطائه.
  - تسجيل جلسات التدريب/التجارب التي ترفع خبرة النظام أو تقلّلها.
- المبادئ:
  - لكل Actor يمكن تخزين:
    - counters مثل: `runs_total، runs_success، runs_failed`.
    - مشتقات مثل: `success_rate` و `experience_level` (مثلاً: NOVICE، STABLE، EXPERT).
  - جلسات التدريب (Training Sessions) تُسجَّل كمهام خاصّة مرتبطة بـ Actor أو مجموعة Actors.
- التكامل:
  - يمكن ربط هذا النظام بجداول التعلّم (مثل `hf_learning.db`) بحيث:
    - يتم قراءة قائمة السكربتات والمدراء من learning layer.
    - يتم إسناد مستوى خبرة لكل سكربت/Actor بناءً على الأداء الفعلي.

### 8.4 نظام الأخطاء (Errors & Incidents)

- الهدف:
  - توحيد رؤية الأخطاء والحوادث (Incidents) في مكان واحد.
  - معرفة أي سكربت/Actor يسبب أعطال متكررة، ومتى حصل ذلك.
- المبادئ:
  - كل Incident يجب أن يحتوي على:
    - `id، actor، error_type، error_message، severity (LOW/MEDIUM/HIGH/CRITICAL)، ts، context`.
  - لا يتم حذف الأخطاء، وإنما تُضاف فوق سجل زمني مستمر.
  - يمكن الإشارة إلى روابط (paths / reports) لتسهيل التحقيق.
- التكامل:
  - النظام يعتمد أساسًا على:
    - رسائل الفشل القادمة من السكربتات.
    - وربطها مع `hf_changes.db` لعمل Trace كامل لما حدث قبل/بعد الخطأ.
  - تقارير الأخطاء تساعد نظام الجودة على حساب "استقرار" كل Actor/خدمة.

### 8.5 العلاقة مع خطّة HyperFFactory

- كل هذه الأنظمة الأربعة تعمل فوق:
  - طبقة التعلّم (hf_learning.db) ← معرفة من هم المدراء/العمّال.
  - طبقة التقدّم (hf_changes.db)   ← معرفة ماذا حدث ومتى.
- لا يتم تنفيذ أي جزء منها خارج `/root/HyperFFactory`.
- يتم إضافة حالة التنفيذ لهذه الأنظمة في `plan_status.md` مع استخدام الرموز:
  - ✅ مكتمل / 🟡 قيد التنفيذ / ⏭ خطوة قادمة.
EOF_README

  echo "✅ تم تحديث README.md (إضافة قسم 8)."
fi

# 4) تحديث plan_status.md – إضافة بلوك الحالة إذا غير موجود
if grep -q '\[أنظمة المهام والجودة والخبرة والأخطاء\]' "$PLAN_STATUS"; then
  echo "ℹ️ بلوك أنظمة المهام/الجودة/الخبرة/الأخطاء موجود بالفعل في plan_status.md – لن أضيفه مرة أخرى."
else
  echo "✏️ إضافة بلوك أنظمة المهام والجودة والخبرة والأخطاء إلى plan_status.md ..."
  cat >> "$PLAN_STATUS" <<'EOF_PLAN'

[أنظمة المهام والجودة والخبرة والأخطاء]
- نظام المهام (Tasks System):
  - تعريف نظري في README.md: ✅ مكتمل
  - تصميم بنية تخزين المهام (DB / تقارير): ⏭ خطوة قادمة
  - ربط المهام بسجل التقدّم hf_changes.db: ⏭ خطوة قادمة

- نظام الجودة (Quality System):
  - تعريف نظري في README.md وربطه بتقارير الصحة: ✅ مكتمل
  - تعريف مؤشرات الجودة (KPIs) الرسمية لكل نظام (SmartFriend / FFactory / HyperFFactory): ⏭ خطوة قادمة
  - توليد تقارير جودة دورية من تقارير health و hf_changes.db: ⏭ خطوة قادمة

- نظام الخبرة والتدريب (Experience & Training):
  - تعريف نظري في README.md وربطه بطبقة التعلّم hf_learning.db: ✅ مكتمل
  - حساب مستويات الخبرة لكل Actor (NOVICE/STABLE/EXPERT) بناءً على السجلات: ⏭ خطوة قادمة
  - تسجيل جلسات التدريب (Training Sessions) كمهام خاصّة: ⏭ خطوة قادمة

- نظام الأخطاء والحوادث (Errors & Incidents):
  - تعريف نظري في README.md وربطه بسجل التقدّم: ✅ مكتمل
  - توحيد تسجيل الأخطاء في شكل Incidents (id/actor/severity/ts/...): ⏭ خطوة قادمة
  - تقارير دورية عن الأخطاء المتكرّرة لكل Actor/نظام: ⏭ خطوة قادمة
EOF_PLAN

  echo "✅ تم تحديث plan_status.md (إضافة بلوك أنظمة المهام والجودة والخبرة والأخطاء)."
fi

echo "=================================================="
echo "✅ انتهى تحديث الخطة بنجاح."
echo "   README.md    → تم أخذ نسخة احتياطية في:"
echo "      $README_BK"
echo "   plan_status  → تم أخذ نسخة احتياطية في:"
echo "      $PLAN_BK"
echo "=================================================="
