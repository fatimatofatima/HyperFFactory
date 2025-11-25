# HyperFFactory – Plan Status

هذا الملف يلخص حالة تنفيذ خريطة العمل الموحدة للمصنع الموحّد HyperFFactory
ويستخدم نفس الرموز المتفق عليها:
- ✅ مكتمل
- 🟡 قيد التنفيذ
- ⏭ خطوة قادمة / مخططة

> المصدر التنفيذي الحقيقي هو ما يحدث داخل /root/HyperFFactory (Tasks / Quality / Errors / Registry)،  
> GitHub والوثائق مرجع تصميمي فقط.

---

## 1) طبقة الهيكل الموحّد Unified Tree & Meta Layer

### 1.1 الجذر والسياسة

- ✅ تثبيت الجذر الرسمي للمصنع:
  - ROOT = `/root/HyperFFactory`
- ✅ اعتماد سياسة Unified Tree Policy:
  - ممنوع إنشاء شجرات أو venv أو خدمات خارج الجذر إلا لنقاط التكامل المصرّح بها:
    - `/opt/smartfriend-suite`
    - `/opt/ffactory`
  - ممنوع symlinks/hardlinks هاربة من داخل HyperFFactory إلى `/`, `/opt`, `/usr`, `/var`.
- ✅ تفعيل حراسة الشجرة:
  - `bin/hf_assert_unified_tree.sh`
  - `bin/hf_guard.sh`
  - `bin/hf_guard_plus_dbmgr.sh`

### 1.2 طبقة الميتا وقواعد البيانات

- ✅ إنشاء وتشغيل قواعد الميتا الأساسية تحت `db/meta/`:
  - `hf_tasks.db`      ← نظام المهام.
  - `hf_errors.db`     ← نظام الحوادث والأخطاء.
  - `hf_quality.db`    ← نظام فحوص الجودة.
  - `hf_registry.db`   ← Registry للسكربتات والأنظمة.
  - `hf_files_index.db`← فهرس الشجرة.
  - `hf_db_registry.db`← Registry لقواعد البيانات.
  - قواعد أخرى: `hf_actors.db`, `hf_changes.db`, `hyper_meta.db`, ...
- ✅ فحص التكامل عبر:
  - `tools/hf_db_manager_run.sh`
  - `tools/hf_db_registry_status.sh`
  - PRAGMA integrity_check = ok للقواعد المفحوصة.

---

## 2) نظام المهام Tasks System

- ✅ إنشاء hf_tasks.db وربطه بالهيكل:
  - جدول tasks يحتوي على (id, actor, scope, status, priority, title, details, created_at, updated_at ...).
- ✅ Seed لمهام إدارة قواعد الميتا (DB Manager):
  - `db_manager:meta_dbs:*` (check_schema, integrity_check, vacuum, size_report, backup_policy, scan_meta_dbs, rebuild_registry, rebuild_index).
  - `db_manager:registry:*` (scan, validate_index, rebuild_index, orphans_cleanup).
- ✅ ربط المهام بالـ Guard و db_manager:
  - `tools/hf_tasks_seed_db_manager.sh`
  - `tools/hf_tasks_feedback_from_quality_and_errors.sh`
  - `tools/hf_tasks_sync_plan.sh`

### 2.1 حالة المهام الحالية (ملخص منطقي)

- عدد المهام الكلي (تقريبي وفقًا للحالة الأخيرة): ~28
  - DONE    : ≈ 11–13
  - PLANNED : الباقي (مهام جارية/مخططة)
  - RUNNING : 0 حاليًا (تنفيذ تتابعي من السكربتات)

---

## 3) نظام الجودة Quality System

- ✅ إنشاء hf_quality.db وربطه بالهيكل.
- ✅ استخدام فحوص الجودة لتغذية:
  - Dashboard / Snapshot
  - Tasks Feedback (تحويل نتائج بعض الفحوص إلى مهام PLANNED أو INCIDENT TASKS).
- ✅ سكربتات ذات صلة:
  - `tools/hf_quality_stage6.sh`
  - `tools/hf_quality_stage6_fixed.sh`
  - تقارير الجودة تظهر في `reports/` وتنعكس في `hf_status_snapshot.sh`.

---

## 4) نظام الأخطاء والحوادث Errors & Incidents

- ✅ إنشاء hf_errors.db وربطه بالـ Guard وباقي الأنظمة.
- ✅ تخزين الحوادث مع:
  - id, actor, error_type, error_message, severity, ts, context
- ✅ تحويل الأخطاء الحرجة إلى مهام:
  - `incident:*` عبر `tools/hf_tasks_feedback_from_quality_and_errors.sh`
- ✅ أمثلة على مهام Incident:
  - `hyper_guard | incident:service_check | PLANNED | HIGH`
  - `hf_health_all | incident:smartfriend_services | PLANNED | HIGH`

---

## 5) Registry / Index / Dashboard

### 5.1 Registry Systems

- ✅ `hf_db_registry.db`:
  - يحتوي جدول meta_dbs مع قائمة كاملة بقواعد الميتا (hf_tasks, hf_errors, hf_quality, hf_actors, hf_changes, hyper_meta, ...).
- ✅ `hf_registry.db`:
  - جداول: db_registry, scripts_registry, systems_registry
  - يستخدم لتسجيل السكربتات والأنظمة تحت HyperFFactory.

### 5.2 Files Index

- ✅ `hf_files_index.db`:
  - جدول files_index مع الحقول: path, name, parent, type, size_bytes, mtime_ts, ...
  - يتم بناؤه/إعادة بنائه عبر عمليات db_manager (op_rebuild_index).

### 5.3 Dashboard / Status Snapshot

- ✅ `tools/hf_status_snapshot.sh`:
  - يعرض:
    - Tasks Summary
    - Errors Summary
    - Quality Summary
    - Registry Snapshot
    - Docker Snapshot
- ✅ `tools/hf_dashboard_cli.sh`:
  - لوحة CLI فوق الـ Snapshot + استعلامات إضافية من hf_tasks.db.
  - توفر رؤية تشغيلية متناسقة للمصنع الموحّد.

---

## 6) أنظمة Experience / Skills / Training

هذه هي الطبقة التي أشرتَ أنها **غير مكتملة بعد**:

### 6.1 الحالة الحالية

- 🟡 الهيكل الأساسي موجود:
  - `hf_actors.db` موجود بجداول:
    - hf_actors, hf_actor_tags, hf_actor_links, sqlite_sequence
  - `hf_learning.db` مذكور في المهام (hyper_learning_manager) ولكن لم يُستكمل كتطبيق إنتاجي.
- ⏭ لا يوجد حتى الآن نظام كامل لمقاييس الخبرة:
  - runs_total, runs_success, runs_failed
  - success_rate, experience_level (NOVICE/STABLE/EXPERT)
  - training_sessions، experiments، learning_runs، ...

### 6.2 المهام المزروعة لتكميل نظام الخبرة (من hf_tasks_seed_experience_and_integration.sh)

- ⏭ `hyper_experience_manager | experience_system | PLANNED`:
  1. تصميم مخطط قاعدة بيانات الخبرة والمهارات  
     - تعريف الجداول والمقاييس لكل Actor.
  2. ربط نظام الخبرة بطبقة المهام والأخطاء والجودة  
     - قراءة نتائج المهام وفحوص الجودة لتحديث counters و success_rate.
  3. إنشاء وظائف تجميع دورية لمقاييس الخبرة  
     - Jobs أسبوعية/يومية لتحديث مؤشرات الخبرة.
  4. إضافة عرض Dashboard لمستويات الخبرة والمهارات  
     - توسيع hf_dashboard_cli.sh لعرض مؤشرات الخبرة.

---

## 7) تكامل HyperFFactory مع SmartFriend Suite / FFactory

### 7.1 الحالة الحالية

- ✅ على مستوى الملفات:
  - HyperFFactory لا يعبث ببنية:
    - `/opt/smartfriend-suite`
    - `/opt/ffactory`
  - يعتبرهما أنظمة متكاملة مستقلة (Stack / Suite) ويتم التعامل معهما كنقاط تكامل فقط.
- ✅ على مستوى الحاويات Docker:
  - حاويات تكامل وتشغيل AI/Workers ظاهرة في snapshot:
    - `hyper_ai_gateway`
    - `hyper_smartfriend_ai_bridge`
    - `hyper_ffactory2_analytics`
    - `hyper_ffactory2_advanced_bridge`
    - `hyper_legacy_ffactory_bridge`
    - `hyper_legacy_ffactory2_bridge`
    - وغيرها ضمن ffactory stack.
- 🟡 مستوى التكامل الفعلي عبر HyperFFactory:
  - توجد مهام Incident و Health موجهة لـ smartfriend_services و ffactory، لكن
  - لا توجد بعد طبقة API/Adapters موحّدة تحت HyperFFactory تتعامل رسميًا مع:
    - Memory API / Health API / Web Gateway
    - AI Gateway / ASR / Ollama / Tools

### 7.2 المهام المزروعة لتكميل التكامل (من hf_tasks_seed_experience_and_integration.sh)

- ⏭ `hyper_integration_manager | apis_integration | PLANNED`:
  1. حصر واجهات SmartFriend و FFactory ووضع خريطة تكامل  
     - جمع endpoints للذاكرة والصحة والبوابات و AI Stack وتوثيقها في خريطة موحّدة.
  2. تصميم طبقة جسور Adapters داخل HyperFFactory  
     - تعريف abstraction لاستدعاء SmartFriend/FFactory من سكربتات HyperFFactory.
  3. تنفيذ جسور API للـ Health والذاكرة و AI  
     - سكربتات/خدمات صغيرة تبني Health Checks / AI Calls وتغذي Tasks/Quality/Errors.
  4. توثيق قناة التكامل الموحدة  
     - تحديث README/تصميم HyperFFactory لتوضيح مسار البيانات بين الأنظمة.

---

## 8) حالة التنفيذ الإجمالية

- ✅ مرحلة التوحيد الأساسي:
  - ROOT + Unified Tree Policy + Meta DBs + Guard + Registry/Index
- ✅ مرحلة الدمج التشغيلي عبر Tasks/Quality/Errors/Registry:
  - الأنظمة الأربعة تعمل فوق الهيكل الموحّد، وتسجّل التقدّم والحوادث والجودة.
- 🟡 مرحلة نظام الخبرة والمهارات (Experience / Skills / Training):
  - تم تعريف المهام في hf_tasks.db، التنفيذ التفصيلي لم يبدأ بعد.
- 🟡 مرحلة تكامل الـ APIs مع SmartFriend/FFactory:
  - الحاويات والجسور موجودة، والمهام التصميمية مزروعة، لكن طبقة Adapters الموحدة لم تُنفّذ بعد.
- ⏭ مراحل لاحقة:
  - لوحات تحكم متقدمة (Telegram / Web).
  - توسيع Learning Layer لتسجيل تجارب وتجارب محاكاة (experiments).
  - تحسين KPIs وربطها بالـ Experience & Quality Systems.
