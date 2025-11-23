#!/usr/bin/env bash
# HyperFFactory - Update plan_status.md safely (no delete)
# - يأخذ نسخة احتياطية من plan_status.md
# - يكتب نسخة محدثة تعكس وضع الأنظمة (Tasks / Quality / Errors / Learning)
# - يسجّل التقدّم في hf_changes.db لو hf_progress_log.sh موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
PLAN_FILE="$ROOT_DIR/plan_status.md"
BACKUP_DIR="$ROOT_DIR/archive/plan_status"
PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

mkdir -p "$BACKUP_DIR"

ts="$(date +%Y%m%d_%H%M%S)"

if [[ -f "$PLAN_FILE" ]]; then
    cp "$PLAN_FILE" "$BACKUP_DIR/plan_status_${ts}.md"
fi

cat > "$PLAN_FILE" <<'PLAN_EOF'
# HyperFFactory – حالة خطة العمل (ملخص سريع)

[البنية الموحّدة]
- /root/HyperFFactory كمصنع موحّد: ✅ مكتمل
- وجود مجلد داخلي `opt/` تحت /root/HyperFFactory كجزء من الهيكل الموحّد (وليس بديلًا عن /opt النظام): ✅ مؤكّد
- استيراد السكربتات والتقارير من /opt و /usr/local إلى HyperFFactory/imported و HyperFFactory/reports: ✅ مكتمل
- سكربت الحراسة bin/hf_guard.sh: ✅ مكتمل
- سكربت فحص سياسة الشجرة الموحّدة bin/hf_assert_unified_tree.sh (كشف symlink/hardlink والمخالفات): ✅ موجود – ⏭ يحتاج تفعيل دوري
- استخدام hf_guard/hf_assert_unified_tree في كل الأوامر التشغيلية: 🟡 قيد التطبيق (يعتمد على لف الأوامر يدويًا)

[SmartFriend Suite]
- اعتماد /opt/smartfriend-suite كنظام رسمي للتشغيل: ✅ مكتمل
- توحيد smartfriend_unified.db تحت مسار واحد مع روابط صلبة عند الحاجة: ✅ مكتمل
- حصر وتعطيل خدمات smartfrind-* القديمة لمنع التضارب: ⏭ خطوة قادمة
- تعريف API تكامل HyperFFactory ↔ SmartFriend (health / memory / gateway): ⏭ خطوة قادمة

[FFactory / AI Stack]
- تشغيل ffactory كـ Stack خارجي متكامل تحت /opt/ffactory: ✅ مكتمل (بحاجة لمراقبة صحته دوريًا)
- استيراد سكربتات الصحة من ffactory إلى HyperFFactory (imported/bin, reports): ✅ مكتمل
- قناة تكامل رسمية (REST / Queue / Events) بين HyperFFactory و ffactory: ⏭ خطوة قادمة

[HyperFFactory Orchestrator]
- وجود ملفات config (manifests / stacks / apps / agents) تحت config/: ✅ أساس موجود
- خط إنتاج رئيسي لمراقبة الخدمات + تجميع التقارير في reports/: 🟡 قيد التطبيق (hf_daily_health_pipeline.sh / hf_health_all.sh)
- لوحة تحكم موحّدة (CLI/Telegram/Web) مبنية على تقارير HyperFFactory: ⏭ خطوة قادمة

[الحوكمة والنسخ الاحتياطي وسياسة الشجرة]
- سياسة "عدم حذف البيانات" واعتماد HyperFFactory كمرجع تاريخي: ✅ مكتمل
- تنظيم Backup موحّد لـ HyperFFactory + SmartFriend + ffactory (خطة واحدة، مخرجات واضحة): ⏭ خطوة قادمة
- تطبيق سياسة الهيكل الموحّد:
  - الجذر الوحيد `/root/HyperFFactory`
  - وجود `opt/` داخلي فقط
  - منع إنشاء ملفات/venv/خدمات خارج الجذر بواسطة سكربتات HyperFFactory
  حالة التنفيذ: 🟡 قيد التطبيق (جزئيًا – تسجيل التقدّم فعّال، التفعيل المنهجي مستمر)
- منع symlink/hardlink داخل `/root/HyperFFactory` تشير لمسارات خارجية (/, /opt, /usr, /var, ...):
  - سكربت الفحص bin/hf_assert_unified_tree.sh جاهز
  - حالة التنفيذ: 🟡 الفحص تم يدويًا – ⏭ يحتاج جدولة وتشغيل تلقائي
- ضرورة تسجيل التقدّم والملفات والمسارات واقتراح الحالة الحالية في الخطة:
  - تسجيل كل خطوة مهمّة في تقارير تحت `reports/`
  - تسجيل التغييرات البنيوية في `db/meta/` (مثل hf_changes.db)
  - عكس حالة التنفيذ (✅ / 🟡 / ⏭) في هذا الملف و README.md
  حالة التنفيذ: 🟡 قيد التطبيق (جزئيًا – تسجيل التقدّم فعّال، التفعيل المنهجي مستمر)

طريقة الاطلاع السريع:
- قراءة الخطة الكاملة/السياسة:   cat README.md
- قراءة الملخص الحالي:           cat plan_status.md

[أنظمة المهام والجودة والخبرة والأخطاء]
- نظام المهام (Tasks System):
  - تعريف نظري في README.md: ✅ مكتمل
  - تصميم بنية تخزين المهام (DB / تقارير): ✅ مكتمل (hf_tasks.db + سكربتات hf_tasks_add/hf_tasks_list/hf_tasks_report)
  - ربط المهام بسجل التقدّم hf_changes.db: 🟡 قيد التطبيق (مستخدم حاليًا في بايبلاين الصحة وبعض السكربتات)

- نظام الجودة (Quality System):
  - تعريف نظري في README.md وربطه بتقارير الصحة: ✅ مكتمل (hf_quality.db + hf_quality_log.sh + hf_quality_from_health.sh)
  - تعريف مؤشرات الجودة (KPIs) الرسمية لكل نظام (SmartFriend / FFactory / HyperFFactory): ⏭ خطوة قادمة
  - توليد تقارير جودة دورية من تقارير health و hf_changes.db: ⏭ خطوة قادمة

- نظام الخبرة والتدريب (Experience & Training):
  - تعريف نظري في README.md وربطه بطبقة التعلّم hf_learning.db: ✅ مكتمل (hf_learning.db + hf_experience_add.sh)
  - حساب مستويات الخبرة لكل Actor (NOVICE/STABLE/EXPERT) بناءً على السجلات: ⏭ خطوة قادمة
  - تسجيل جلسات التدريب (Training Sessions) كمهام خاصّة: ⏭ خطوة قادمة

- نظام الأخطاء والحوادث (Errors & Incidents):
  - تعريف نظري في README.md وربطه بسجل التقدّم: ✅ مكتمل
  - توحيد تسجيل الأخطاء في شكل Incidents (id/actor/severity/ts/...): ✅ مكتمل (hf_errors.db + hf_errors_log.sh)
  - تقارير دورية عن الأخطاء المتكرّرة لكل Actor/نظام: ⏭ خطوة قادمة
PLAN_EOF

if [[ -x "$PROGRESS_LOG" ]]; then
  "$PROGRESS_LOG" "hf_plan_update" "plan_status" "hyper" "INFO" "تحديث plan_status.md بدون حذف (مع نسخة احتياطية في archive/plan_status)."
fi

echo "✅ تم تحديث $PLAN_FILE"
echo "📁 نسخة احتياطية (إن وجدت) في: $BACKUP_DIR"
