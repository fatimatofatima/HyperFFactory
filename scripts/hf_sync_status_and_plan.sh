#!/usr/bin/env bash
# hf_sync_status_and_plan.sh
# - تشغيل دورة hf_repo_update (Health + Workers + Pipeline + Meta)
# - تحديث plan_status.md بالمحتوى المعتمد
# - عمل commit + push لـ plan_status.md فقط بدون لمس أي imported/snapshot/داتا ثقيلة

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

echo "==[HF SYNC] Root: $ROOT"

############################################
# 1) تشغيل hf_repo_update.sh (إن وُجد)
############################################

if [[ -x "bin/hf_repo_update.sh" ]]; then
    echo "==[HF SYNC] Running bin/hf_repo_update.sh ..."
    ./bin/hf_repo_update.sh || echo "!! hf_repo_update.sh انتهى مع كود غير صفري، راجع اللوج."
else
    echo "!! bin/hf_repo_update.sh غير موجود أو غير قابل للتنفيذ، تخطي هذه الخطوة."
fi

############################################
# 2) نسخ احتياطي لـ plan_status.md (إن وُجد)
############################################

if [[ -f "plan_status.md" ]]; then
    ts="$(date +%Y%m%d_%H%M%S)"
    backup="plan_status.md.bak_${ts}"
    cp plan_status.md "${backup}"
    echo "==[HF SYNC] Backup created: ${backup}"
fi

############################################
# 3) كتابة المحتوى الجديد لـ plan_status.md
############################################

cat > plan_status.md <<'PLAN_EOF'
# HyperFFactory – حالة التنفيذ والتكامل (Execution Status)

> هذا الملف هو المرجع الرسمي لحالة HyperFFactory على السيرفر:
> - لا يصف SmartFriend Suite نفسها، بل وضع التكامل معها.
> - يركّز على: الصحة، العمال، خط الإنتاج، الميتا، والحوكمة.

## 1) ملخص تنفيذي

- مستوى جاهزية طبقة **الصحة + العمال + خط الإنتاج + الميتا**: حوالي **80–90% مكتمل**.
- مستوى جاهزية **الحوكمة والتخطيط الموحد (Unified Plan / Config / Backups / Schedulers)**: حوالي **20–30% مكتمل**.
- آخر نقطة مرجعية عملية:
  - `status/STATUS_HYPER_INTEGRATION.md`  
  - Timestamp آخر تكامل: مذكور داخل الملف.

---

## 2) المراحل (Phases)

### Phase 1 – Core Integration & Health (البنية التشغيلية الأساسية)

**الهدف:**  
امتلاك مركز صحّة وتشغيل وتكامل أساسي ثابت لـ HyperFFactory بدون لمس ffactory أو SmartFriend Suite نفسها.

| ID   | البند                                                | الحالة      | ملاحظات عملية                                                                 |
|------|------------------------------------------------------|------------|-------------------------------------------------------------------------------|
| P1-1 | توحيد فحص الصحة SmartFriend + FFactory               | DONE       | عبر `bin/hf_health_all.sh` و `bin/hf_smart_integration_cycle.sh`.            |
| P1-2 | مركز حالة العمال والجودة/الأخطاء/التعلّم/المهام     | DONE       | `bin/hf_workers_status.sh` + `hf_quality.db`, `hf_errors.db`, `hf_learning.db`, `hf_tasks.db`, `hf_changes.db`. |
| P1-3 | خط إنتاج بيانات أساسي (ingestor → reporter)         | DONE       | `bin/hf_run_basic_pipeline.sh` + العمال الأربعة؛ يعمل حتى لو inbox فارغ.     |
| P1-4 | طبقة ميتا للمهام والتقدم                             | DONE       | `hf_ops_meta.db` (جداول `tasks`, `progress_log`) مربوطة مع `hf_progress_exec.sh`. |
| P1-5 | نقطة دخول موحّدة لدورات التكامل                     | DONE       | `bin/hf_smart_integration_cycle.sh` (4 خطوات: Health + Workers + Pipeline + Summary). |
| P1-6 | تقرير تكامل نصي موحّد                                | DONE       | تقارير `reports/hf_smart_integration_cycle_*.log` + ملخص DBs في خطوة Summary. |

**حالة Phase 1:**  
✅ مكتملة وظيفيًا (MVP قوي) وقابلة للتشغيل من السيرفر ومن الريبو.

---

### Phase 2 – Governance & Unified Plan (الحوكمة والخطة الموحدة)

**الهدف:**  
تثبيت “العقل الإداري” لـ HyperFFactory: من هو صاحب الحقيقة، وكيف تُدار الخطط، وكيف تُوثّق الحالة.

| ID   | البند                                                                   | الحالة      | ملاحظات عملية                                                                 |
|------|-------------------------------------------------------------------------|------------|-------------------------------------------------------------------------------|
| P2-1 | تعريف رسمي لدور HyperFFactory مقابل SmartFriend Suite                  | PLANNED    | HyperFFactory = مصنع بيانات/تحليل؛ SmartFriend = مصدر الهوية/الذاكرة.       |
| P2-2 | توحيد ملف خطة واحد (هذا الملف + HF_EXEC_PLAN.tsv + أدوات العرض)       | IN_PROGRESS| `plan_status.md` + `plans/HF_EXEC_PLAN.tsv` + `tools/hf_show_plan.sh`.       |
| P2-3 | ربط بعض البنود بـ `hf_ops_meta.tasks` (actor / scope)                  | PLANNED    | مثل ربط `hyper_brain_controller`، `hyper_guard`، إلخ.                         |
| P2-4 | سياسة Backup رسمية موثَّقة لـ HyperFFactory                            | PLANNED    | استخدام أدوات مثل: `tools/check_hf_backups.sh`, `tools/hf_backups_quick_report.sh`. |
| P2-5 | احترام فصل الملكية: عدم لمس `/opt/ffactory` و`/opt/smartfriend-suite`  | ACTIVE     | سياسة ثابتة، مذكورة هنا كجزء من الحوكمة.                                     |
| P2-6 | تعريف واضح لملفات “الداتا الثقيلة / snapshots / imported`”            | PLANNED    | فقط على السيرفر؛ لا تُضمّن في Git إلا بقرار صريح.                            |
| P2-7 | ربط خطّة التنفيذ مع سكربتات الإدارة (hf_update_plan_and_repo.sh, إلخ) | IN_PROGRESS| السكربتات موجودة تحت `scripts/` وتحتاج توثيقًا ومواءمة مع هذه الخطة.        |

**حالة Phase 2:**  
🔄 قيد البناء؛ هذا الملف نفسه هو أول خطوة صريحة في توثيق الحوكمة.

---

### Phase 3 – Advanced Infrastructure (Data Lakehouse / Factories / Stack)

**الهدف:**  
الوصول للبنية المتقدمة التي ذكرتها سابقًا (Lakehouse, Factories, Stack, Agents, Systems).

#### 3.1 البنية التحتية المتقدمة (Infrastructure)

من قائمة النواقص التي ذكرتها:

- data_lakehouse/ (كامل - Raw → Cleansed → Semantic → Serving)
- factories/ (مصنع النماذج - مصنع المعرفة - مصنع الجودة)
- stack/ (GPU cluster - Model serving - Vector DB)

حالة التنفيذ داخل HyperFFactory حتى الآن:

| ID    | العنصر                  | المسار المستهدف           | الحالة      | ملاحظات |
|-------|-------------------------|---------------------------|------------|---------|
| INF-1 | data_lakehouse/        | `data_lakehouse/`         | NOT_STARTED| لم تُنشأ بنية Lakehouse مستقلة بعد. |
| INF-2 | factories/             | `factories/`              | NOT_STARTED| لم يُبنَ مصنع نماذج/معرفة موحّد بعد. |
| INF-3 | stack/                 | `stack/`                  | PARTIAL    | توجد بعض ملفات stack/ لـ ffactory والـ AI stack، لكن ليست Lakehouse/Factories موحّدة. |

#### 3.2 العوامل المتقدمة (Agents)

- agents/debug_expert/
- agents/system_architect/
- agents/technical_coach/
- agents/knowledge_spider/

حاليًا:

| ID     | العامل              | الحالة      | ملاحظات |
|--------|---------------------|------------|---------|
| AG-1   | debug_expert        | NOT_STARTED| البنية المنطقية موجودة في الخطة، لم يُنفّذ كعامل مستقل. |
| AG-2   | system_architect    | NOT_STARTED| – |
| AG-3   | technical_coach     | NOT_STARTED| – |
| AG-4   | knowledge_spider    | PARTIAL    | توجد أدوات جمع معرفة (SmartFriend spider)، لكن لم تُربَط كـ Agent ضمن HyperFFactory. |

#### 3.3 الأنظمة المتقدمة (Systems)

- نظام الأنماط (Patterns) - التعلم من الأخطاء  
- نظام الجودة (Quality) - التقييم التلقائي  
- نظام الذاكرة الزمنية - تطور المستخدمين  
- نظام التكامل - ربط مع أنظمة خارجية  

حالة هذه الأنظمة داخل HyperFFactory:

| ID     | النظام                       | الحالة      | ملاحظات |
|--------|------------------------------|------------|---------|
| SYS-1  | نظام الأنماط (Patterns)     | PARTIAL    | hf_learning.db يجمع أحداث تعلّم، لكن لا يوجد Engine أنماط متكامل بعد. |
| SYS-2  | نظام الجودة (Quality)       | PARTIAL    | توجد سجلات جودة في `hf_quality.db`، تحتاج Engine + سياسات. |
| SYS-3  | الذاكرة الزمنية             | NOT_STARTED| لا يوجد نظام زمني للمستخدمين/الكيانات حتى الآن ضمن HyperFFactory. |
| SYS-4  | نظام التكامل مع أنظمة خارجية| PARTIAL    | التكامل مع SmartFriend Suite و ffactory موجود على مستوى الصحة فقط. |

---

## 4) ربط الخطة مع الواقع التشغيلي

### 4.1 مصادر الحالة العملية (Ground Truth)

- قواعد بيانات الميتا:
  - `/root/HyperFFactory/db/meta/hf_ops_meta.db`
  - `/root/HyperFFactory/db/meta/hf_quality.db`
  - `/root/HyperFFactory/db/meta/hf_errors.db`
  - `/root/HyperFFactory/db/meta/hf_learning.db`
  - `/root/HyperFFactory/db/meta/hf_tasks.db`
  - `/root/HyperFFactory/db/meta/hf_changes.db`
- التقارير النصية:
  - `reports/hf_smart_integration_cycle_*.log`
  - `reports/hf_health_report_*.log`
  - `reports/hf_basic_pipeline_*.log`
  - `reports/hf_progress_*.log`

### 4.2 سياسة التعامل مع الملفات الثقيلة / imported / snapshots

- كل المسارات تحت:
  - `imported/`
  - `snapshot/`
  - `var/lib/docker/overlay2/…`
  - `var/lib/smartfrind/sources/repos/…`
  - نسخ SmartFriend Suite (`imported/opt/smartfriend-suite/...`)
- تُعتبر **بيانات تشغيل/أرشيف** على السيرفر، وليست جزءًا من الكود المصدري لـ HyperFFactory.
- لا تُضاف إلى Git إلا بقرار صريح ضمن خطة منفصلة للأرشفة.

---

## 5) ما بعد هذا الملف

- هذا الملف يثبّت وضع التنفيذ الحالي.
- أي تطوّر في HyperFFactory يجب أن يمر عبر:
  1. تحديث هذا الملف (`plan_status.md`) أو `plans/HF_EXEC_PLAN.tsv`.
  2. توثيق التغييرات عبر تقارير `hf_smart_integration_cycle.sh` و `hf_repo_update.sh`.
PLAN_EOF

echo "==[HF SYNC] plan_status.md updated."

############################################
# 4) عرض فرق سريع
############################################

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "==[HF SYNC] Git diff for plan_status.md:"
    git diff -- plan_status.md || true
else
    echo "!! هذا المجلد ليس مستودع Git، تخطي خطوة git."
    exit 0
fi

############################################
# 5) Commit + Push لـ plan_status.md فقط
############################################

if git diff --quiet -- plan_status.md; then
    echo "==[HF SYNC] لا توجد تغييرات على plan_status.md بعد الكتابة (لا يوجد commit جديد)."
else
    echo "==[HF SYNC] Adding plan_status.md to git ..."
    git add plan_status.md

    msg="chore: update HyperFFactory execution plan_status"
    echo "==[HF SYNC] Committing with message: ${msg}"
    git commit -m "${msg}" || echo '!! لم يتم إنشاء commit (ربما لا تغييرات أو مشكلة أخرى).'

    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    echo "==[HF SYNC] Pushing to origin/${current_branch} ..."
    git push origin "${current_branch}" || echo "!! فشل push، راجع إعدادات الريموت/الإنترنت."
fi

echo "==[HF SYNC] Done."
