# 🏭 HyperFFactory – الخطة الرئيسية الموحّدة

## 1. الوضع الحالي (Current Status)

- موقع المشروع الفعلي على السيرفر: `/root/HyperFFactory`
- الدمج: تجميع أغلب الشغل السابق تحت مشروع موحّد واحد.
- البيئة التقنية:
  - بيئة Python افتراضية (venv) مخصّصة للمصنع.
  - Docker Stack لخدمات AI / API / دعم.
  - FastAPI / Hyper API كبوابة أساسية (مثلاً على منفذ 8310 أو ما يعادله).
- التشغيل:
  - خدمات systemd لتشغيل مكوّنات المصنع تلقائياً.
  - سكربتات تشغيل/فحص/تشخيص موزّعة تحت المشروع.
- الاستخدام:
  - الريبو على GitHub لعرض الصورة الكاملة والتوثيق.
  - التنفيذ الفعلي والخدمات الحقيقية تعمل على السيرفر فقط.

> هذا القسم يتم تحديثه كلما تغيّر “وضع المصنع” أو تمت ترقية معمارية كبيرة.

---

## 2. الرؤية النهائية (End-State Vision)

**هدف نهائي:** بناء مصنع ذكي متكامل **ذاتي الإدارة** يعمل كمنظومة إدارية وتشغيلية كاملة:

- 🤖 عقل مدير استراتيجي (Central Management Brain)
- 👨‍💼 مديري أنظمة (عمليات – جودة – موارد – بيانات)
- 👷 مشرفون على خطوط الإنتاج والأنظمة الفرعية
- 🔧 عمال آليون (Bots / Services) ينفّذون المهام (OCR، تحليلات، لعب، مراقبة…)
- 📊 نظام تعلّم مستمر (Continuous Learning) يحسّن الأداء تلقائياً.

### مؤشرات نجاح رئيسية (Business KPIs)

- ⏱️ وقت تنفيذ المهام: انخفاض 30% على الأقل.
- 📈 إنتاجية العمال/الخدمات: زيادة 40%.
- 📊 جودة المخرجات (نتائج / تحليلات): 95–98% دقة.
- 🤖 نسبة القرارات ذاتية التشغيل في اليوميات: 80–90%.
- ⚡ سرعة الاستجابة للأحداث والإنذارات: تحسن 50–60%.

---

## 3. خريطة الطبقات والتكامل (Integration Map)

### 3.1 الطبقات التنظيمية

1. **العقل المدير المركزي**  
   - التخطيط الاستراتيجي، رسم الأهداف، تحليل الأداء الكلي، إدارة المخاطر.

2. **مديرو الأنظمة المتخصصة**
   - مدير العمليات (Operations Manager)
   - مدير الجودة (Quality Manager)
   - مدير الموارد (Resources Manager)
   - مدير البيانات (Data Manager)

3. **المشرفون (Supervisors)**
   - مشرف الإنتاج، مشرف الجودة، مشرف الصيانة، مشرف المستودعات/التخزين.

4. **العمال (Workers / Bots / Services)**
   - OCR Workers
   - Game/Pattern Analyzers
   - Data Ingestors
   - Risk Engines، Pattern Engines (Falcon, HawkEye, …)
   - أي أنظمة تنفيذية أخرى داخل HyperFFactory.

### 3.2 قواعد البيانات الإدارية (Management DBs)

كلها تحت: `var/db/management/` على السيرفر

- `workers.db`
- `tasks.db`
- `quality.db`
- `performance.db` (لاحقاً)

### 3.3 تدفق العمل (Workflow Flow)

1. العقل المدير يحدد الأهداف والخطط الاستراتيجية.
2. مديري الأنظمة يحوّلون الأهداف إلى مهام (Tasks) موزعة على الأنظمة/العمال.
3. المشرفون يراقبون التنفيذ عبر العمال والخدمات.
4. العمال ينفذون المهام ويسجّلون النتائج (Logs, DB, Metrics).
5. نظام الجودة يفحص ويعطي تقارير/تنبيهات.
6. العقل المدير يعيد تحليل الأداء ويعدّل الخطط (Loop مستمر).

---

## 4. تصميم النظام الإداري (Management System Blueprint)

### 4.1 العقل المدير المركزي

- كلاس محوري: `CentralManagementBrain`
- المهام الأساسية:
  - إعداد/تحديث الأهداف الاستراتيجية.
  - قراءة مؤشرات الأداء من قواعد البيانات.
  - تقييم المخاطر ووضع خطط تخفيف.
  - إنتاج خطط موارد (Human / Equipment / Time).

### 4.2 مديري الأنظمة (Managers)

- **Operations Manager**
  - إدارة طوابير المهام.
  - مراقبة حالة الخدمات العاملة (Workers / Containers / Bots).
  - إعادة جدولة المهام عند حدوث أعطال.

- **Quality Manager**
  - قراءة سجلات الجودة من `quality.db`.
  - مراقبة نسب القبول/الرفض.
  - توليد تنبيهات في حال انخفاض جودة أي مسار.

- **Resources Manager**
  - مراقبة توزيع الأحمال على العمال/الخدمات.
  - إدارة الجداول (Shifts) وحالة الموارد.
  - اقتراح تدريب/تعزيز الموارد عند بوادر ضغط.

- **Data Manager**
  - إدارة قواعد البيانات الإدارية والتشغيلية.
  - متابعة صحة البيانات (Integrity / Backups / Growth).
  - توفير واجهات استعلام للإدارة العليا.

---

## 5. تصميم قواعد البيانات الإدارية (DB Design)

### 5.1 قاعدة العمال – `workers.db`

جدول `workers`:

- `worker_id` (PRIMARY KEY)
- `name`
- `role` (manager / supervisor / worker / service / bot …)
- `department`
- `skills` (JSON list)
- `experience_level` (رقم/مستوى)
- `current_tasks` (JSON list)
- `performance_score` (REAL)
- `status` (active / paused / disabled)
- `created_at`, `last_updated`

### 5.2 قاعدة المهام – `tasks.db`

جدول `tasks`:

- `task_id` (PRIMARY KEY)
- `title`
- `description`
- `task_type`
- `priority` (low / medium / high / critical)
- `assigned_to`
- `assigned_by`
- `status` (pending / running / done / failed / cancelled)
- `deadline`
- `quality_metrics` (JSON)
- `completion_time` (minutes)
- `actual_time`
- `quality_score`
- `created_at`
- `completed_at`

### 5.3 قاعدة الجودة – `quality.db`

جدول `quality_checks`:

- `check_id` (PRIMARY KEY)
- `product_id`
- `inspector_id`
- `check_type`
- `metrics` (JSON)
- `defects` (JSON)
- `score`
- `status`
- `recommendations`
- `timestamp`

### 5.4 قاعدة الأداء – `performance.db` (مستقبلاً)

جدول مقترح:

- `worker_id`
- `task_completion_rate`
- `avg_quality_score`
- `efficiency_index`
- `training_needs`
- `last_review_at`

---

## 6. خريطة التنفيذ (Execution Roadmap – High Level)

### المرحلة 1 – النظام الإداري الأساسي

- [ ] بناء `CentralManagementBrain` مع ربط أولي بالـ DB.
- [ ] تعريف Managers (operations/quality/resources/data) كـ وحدات منفصلة.
- [ ] تعريف Supervisors + واجهة أساسية للعمال (Workers API).

### المرحلة 2 – قواعد البيانات والربط

- [ ] إنشاء/تثبيت DBs تحت `var/db/management`.
- [ ] ربط كل Manager بالـ DB الخاصة به.
- [ ] إعداد سكربتات فحص صحة (Health / Integrity) لهذه القواعد.

### المرحلة 3 – التعلم والتحسين

- [ ] ربط مخرجات الأنظمة الفعلية (OCR / لعب / تحليلات) بقواعد الأداء.
- [ ] بناء Loop: Data → Analyze → Decide → Adjust → Execute.
- [ ] إضافة مؤشرات نجاح ومراقبتها من خلال العقل المدير.

---

## 7. سياسة التحديث مع الريبو (Repo Operating Model)

1. التنفيذ الفعلي يتم على السيرفر (`/root/HyperFFactory`).
2. الريبو على GitHub يستخدم لـ:
   - التوثيق.
   - الصورة المعمارية.
   - تتبّع التقدم (Roadmap + Status).
3. لأي مكوّن جديد أو تعديل مهم:
   - تنفيذ + اختبار على السيرفر.
   - تحديث قسم/ملف مناسب في `docs/` أو `plans/`.
   - `git add` + `git commit` برسالة وصفية.
   - `git push` لتحديث الريبو.

> هذا الملف هو المرجع الأعلى (Master Plan) لصورة المصنع الكاملة.
