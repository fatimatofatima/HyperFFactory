#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

last_update="$(date +'%Y-%m-%d %H:%M:%S')"

cat > README.md <<R_EOF
# 🏭 HyperFFactory – المصنع الذكي الموحد على السيرفر

## 🎯 الهدف

منصة تشغيل موحَّدة فوق السيرفر تجمع:
- عقل إدارة مركزي (Hyper Brain)
- طبقة بيانات موحدة (Identity / Memory / Knowledge / Tasks / Skills / Meta)
- تكامل كامل مع SmartFriend-Suite والأنظمة القديمة
- سكربتات تشغيل، ترحيل، مراقبة، وتقارير – كلها تحت \`/root/HyperFFactory\`

## 📌 موقع العمل الفعلي

> كل التشغيل الفعلي يتم على السيرفر فقط:

\`\`\`text
/root/HyperFFactory
\`\`\`

GitHub يُستخدم كأرشيف/مرجع للكود فقط، ليس كمصدر تشغيل.

---

## 🧱 الطبقات الرئيسية في HyperFFactory

### 1) طبقة الكود المركزي

- \`hyper_factory/\`
  - \`hyper_factory/api/\` – واجهات API (قيد التطوير)
  - \`hyper_factory/management/\` – طبقة الإدارة المركزية
- ملفات عقل إضافية في الجذر:
  - \`simple_brain.py\`
  - \`self_learning_brain.py\`
  - \`ops.py\`

### 2) طبقة البيانات

- \`db/\`
  - \`db/audit\`      – سجلات تدقيق وتحليل
  - \`db/identity\`   – الهوية / المستخدمون / الأدوار
  - \`db/knowledge\`  – المعرفة
  - \`db/memory\`     – الذاكرة
  - \`db/meta\`       – بيانات وصفية عامة
  - \`db/skills\`     – المهارات / العوامل
  - \`db/tasks\`      – المهام وجداول التشغيل
- \`var/\`
  - \`var/db\`        – قواعد بيانات تشغيلية/وقت تشغيل
  - \`var/log\`       – لوجات التشغيل
  - \`var/run\`       – ملفات PID و runtime
- \`meta/hyper_meta.db\` – قاعدة بيانات وصفية موحدة
- \`original_system_dbs_20251122_085558\` – نسخة من قواعد النظام الأصلية قبل التوحيد

### 3) تكامل SmartFriend-Suite والأنظمة القديمة

- \`opt/smartfriend-suite\` – نسخة مستوردة من السيوت القديم
- \`opt/imported\`, \`imported/{opt, root}\` – شجرة الكود/البيانات المستوردة
- \`ops\` (symlink):
  - يشير إلى \`imported/opt/report/.../opt/smartfriend-suite/ops\`
  - يسمح بإعادة استخدام طبقة \`ops\` القديمة من داخل HyperFFactory
- سكربتات الهجرة/التهيئة (أمثلة من الجذر و tools):
  - \`hyper_migrate_identity_from_legacy.sh\`
  - \`hyper_migrate_knowledge_from_legacy.sh\`
  - \`hyper_init_brain_and_knowledge*.sh\`
  - \`hyper_seed_runtime_from_legacy.sh\`
  - \`hyper_seed_workers_from_services.sh\`
  - سكربتات Python لـ migration تحت \`tools/hyper_migrate_*.py\`, \`hyper_meta_import_dbs.py\`, … إلخ
- سكربتات التقارير والفحص:
  - \`hyper_scan_dbs.sh\`, \`hyper_collect_all_dbs.sh\`
  - \`hyper_db_audit_readonly.sh\`, \`hyper_db_usage_from_meta.sh\`
  - \`hyper_dedupe_by_hash.sh\` + النسخة Python في \`tools/\`

### 4) سكربتات الإدارة والتشغيل

- \`scripts/\` – محور التشغيل الفعلي، منظم حسب مجال العمل:
  - \`scripts/core\`        – سكربتات التحكم الأساسية في HyperFFactory
  - \`scripts/db\`          – إدارة قواعد البيانات
  - \`scripts/maintenance\` – صيانة، إصلاحات، تنظيم
  - \`scripts/suites\`      – تكامل مع SmartFriend-Suite
  - \`scripts/unification\` – توحيد الطبقات والأنظمة
  - \`scripts/gateways\`    – بوابات API / Gateways
  - \`scripts/health\`      – فحوصات صحة الأنظمة
  - \`scripts/integration\` – تكامل داخلي/خارجي
  - \`scripts/ai\`, \`scripts/agents\`, \`scripts/spiders\`, \`scripts/testing\`, … إلخ
- سكربتات جذرية مهمة:
  - \`hyper_bootstrap_*.sh\` – إعداد سريع للبيئة
  - \`hyper_server_check.sh\` – فحص حالة السيرفر
  - \`hyper_final_check.sh\` – فحص شامل قبل أي تغييرات كبرى
  - \`emergency_restore.sh\` – مسار طوارئ لاستعادة الحالة

### 5) أدوات التحليل العميق

- \`tools/\`
  - فحص وتنظيف: \`hf_root_cleanup.sh\`, \`execute_safe_cleanup.sh\`
  - إخفاء وتخصيص واجهة الدخول: \`hf_hide_default_motd.sh\`, \`hf_set_login_banner.sh\`
  - فحص شجرة الكود: \`hyper_deep_scan.py\`, \`hf_index_scripts.sh\`, \`hf_flatten_src_to_root.sh\`, \`hf_inspect_and_fix_src.sh\` (استُخدمت سابقًا لإلغاء \`src/\`)
  - إدارة قواعد البيانات: \`hyper_collect_dbs.py\`, \`hyper_scan_dbs.py\`, \`hyper_meta_import_dbs.py\`, … إلخ
- تقارير جاهزة في الجذر:
  - \`hf_backups_report_*.txt\`
  - \`db_inventory_*.tsv\`, \`db_inventory_summary_*.txt\`

### 6) الستاك (Stack)

- \`stack/\`
  - \`stack/core\`          – مكونات أساسية (DB, LLMs, …)
  - \`stack/ai_support\`    – خدمات مساعدة للذكاء الاصطناعي
  - \`stack/ffactory2\`     – تكامل مع ffactory2
  - \`stack/integrations\`  – تكاملات إضافية
  - \`stack/monitoring\`    – مراقبة/لوحات
  - \`stack/other_tools\`   – خدمات أخرى

### 7) التوثيق والتقارير

- \`docs/\`
  - \`HYPERFACTORY_MASTER_PLAN.md\` – الخطة الرئيسية
  - \`INTEGRATION_OVERVIEW.md\` – نظرة تكاملية
  - \`PROJECT_STATUS_2025.md\` – حالة المشروع
  - \`integration_roadmap.md\` – خارطة طريق التكامل
  - سجلات حركة الملفات: \`ffactory_move_*.log\`, \`root_move_pure_*.log\`, \`opt_move_log_*.txt\`
- \`plans/EXECUTION_ROADMAP.md\` – خطة التنفيذ
- \`reports/\`
  - \`reports/db_audit_*.txt\`
  - \`reports/apps_status\`, \`reports/backups_audit\`, \`reports/stack_status\`, إلخ
- \`logs/\`
  - \`logs/management_smoke_*.log\`
  - \`logs/root_tree_before_*.txt\`, \`logs/root_tree_after_*.txt\`

### 8) ملفات أخرى ذات أهمية

- \`config/*.yaml\` – manifest, stacks, apps, skills_tracks_backend
- \`requirements.txt\` (+ نسخ احتياطية) – متطلبات بايثون
- \`structure.txt\` – لقطة هيكلية للملفات
- \`motd_backup_*\` – نسخ احتياطية لرسائل login القديمة
- \`أي\` / \`مهم:\` – ملاحظات خاصة محلية

---

## 📊 إحصائيات حالية (من آخر فحص)

- عدد المجلدات: **233**
- عدد الملفات: **15,489**

(هذه الأرقام مأخوذة من إخراج آخر فحص في \`/root/HyperFFactory\`.)

---

## 🔄 أسلوب العمل

1. **كل التطوير والتشغيل** داخل \`/root/HyperFFactory\`.
2. **الأنظمة القديمة** (SmartFriend-Suite, ffactory2, …) يتم دمجها من خلال:
   - مسارات \`imported/\` و \`opt/smartfriend-suite\`
   - سكربتات \`hyper_migrate_*\`, \`hyper_seed_*\`, \`hyper_init_*\`
3. **لا يتم لمس مشروع ffactory الأساسي** من داخل HyperFFactory؛ الدمج يتم بالقراءة/الترحيل فقط، وفق الاتفاق.
4. **كل عمليات الهجرة/الفحص** تُسجّل في:
   - \`docs/*.log\`, \`logs/\`, \`reports/\`, \`hf_backups_report_*.txt\`

---

## 🗺️ خارطة طريق مختصرة

- المرحلة 1 (منجزة):
  - توحيد شجرة العمل داخل \`/root/HyperFFactory\`
  - استيراد SmartFriend-Suite والبيانات القديمة إلى \`imported/\` و \`opt/\`
  - بناء طبقة بيانات موحدة (\`db/\`, \`var/db\`, \`meta/hyper_meta.db\`)
  - فحص وتوثيق الحالة (docs/logs/reports/structure)

- المرحلة 2 (جارية):
  - تثبيت طبقة إدارة مركزية في \`hyper_factory/management\`
  - ربط طبقة الذاكرة/المعرفة/المهام بقواعد البيانات الموحدة
  - تنظيم تشغيل الستاك (stack/*) مع HyperFFactory كسوبر-أوركستريتور

- المرحلة 3 (لاحقًا):
  - تفعيل الـ self-learning في \`self_learning_brain.py\`
  - تعريف عمال ووكلاء (agents) يعتمدون على قواعد البيانات الموحدة
  - بناء واجهات تحكم (CLI + Web) أعلى السكربتات الحالية

---

*آخر تحديث لهذا التوثيق: ${last_update}*  
*هذا الملف يصف الوضع الفعلي في \`/root/HyperFFactory\` بناءً على آخر فحص للشجرة.*
R_EOF

echo "✅ تم تحديث README.md وفق الهيكل الحالي الفعلي"
