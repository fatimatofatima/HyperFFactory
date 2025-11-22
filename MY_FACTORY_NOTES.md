# 🏭 HyperFFactory + مصنع العمال الأذكياء – هوية المشروع

## 1. المالك / الـ Mindset

- المالك: مبرمج بيشتغل بعقلية مصنع:
  - يحب الخوارزميات، تحليل البيانات، حل المشاكل.
  - هدفه يبني "عقل مساعد" يشبهه في الشغل والتفكير.
- طريقة التفكير:
  - كل حاجة عبارة عن: نظام → موديولات → عمال → خطوط إنتاج.
  - مفيش خطوة بدون سبب، ومفيش نظام بدون قياس وتحسين.

HyperFFactory هو الطبقة الموحّدة فوق:
- smartfriend-suite (تحت /opt/smartfriend-suite)
- ffactory / hyper-factory (المشاريع السابقة)
- طبقة AI Orchestrator وعمال الذكاء.

---

## 2. فكرة المصنع (AI Factory / HyperFFactory)

المصنع مش مجرد Bot، بل:

- Factory للبنية التحتية:
  - stacks تحت `stack/` (core_elk, monitoring, ai_support, smartfriend_suite).
  - سكربتات تشغيل موحدة تحت `scripts/core/ffactory*.sh`.
- Factory للتطبيقات:
  - apps تحت `apps/` (timeline_analyzer, netflow_inspector, backend_coach_api).
- Factory للذكاء:
  - agents معرفين في `config/agents.yaml` وملفات الـ prompts.
  - skills & tracks في `config/skills_tracks_backend.yaml`.
  - datasets في `ai/datasets/`.

Agents الأساسية:
- Debug Expert
- System Architect
- Technical Coach
- Knowledge Spider

كل عامل يشتغل فوق نفس البنية:
- LLM Provider
- Orchestrator (HyperFFactory)
- Memory / Logs
- Knowledge Base
- Patterns & Quality

---

## 3. الطبقات الرئيسية

### 3.1 Layer البيانات والمعرفة

- raw_knowledge/ (لاحقًا)
- knowledge/ (لاحقًا)
- ingestion pipeline (يربط HyperFFactory مع مصادر مثل smartfriend-suite, ffactory, hyper-factory repos).

### 3.2 Layer الذكاء

- `ai/prompts/*` لتعريف شخصيات العمال.
- `ai/datasets/*` لتجميع المحادثات، الجودة، التدريب.
- `config/agents.yaml` لربط كل عامل بملف الـ prompt والـ data.

### 3.3 Layer الذاكرة والجودة

- HyperFFactory يعتمد على:
  - logs في `reports/` و `audit/`.
  - patterns في `ai/patterns/patterns.json` (لاحقًا).
  - رسائل تدريب في `ai/datasets/messages.jsonl`.

---

## 4. Skills & Tracks – Backend Junior

تعريف كامل في `config/skills_tracks_backend.yaml`:

- Phase 0 → الأساسيات
- Phase 1 → Python Fundamentals
- Phase 2 → Python للمشاريع
- Phase 3 → Backend Basics
- Phase 4 → Databases
- Phase 5 → Backend Craft
- Phase 6 → Deployment

لكل مستخدم في المستقبل:
- UserSkillState:
  - score 0–100 لكل Skill.
  - track_id الحالي.
  - current_focus_skill.

---

## 5. مصانع الـ System

### 5.1 HyperFFactory – Linux Factory

مجلد: `HyperFFactory/`

- `config/`:
  - `factory_manifest.yaml`: تعريف جميع الـ stacks + تكامل smartfriend_suite.
  - `apps.yaml`: تعريف كل App وخدماته.
  - `agents.yaml`: تعريف العمال الأذكياء.
- `stack/`:
  - core/, monitoring/, ai_support/ → docker-compose.*
- `apps/`:
  - timeline_analyzer, netflow_inspector, backend_coach_api.
- `scripts/`:
  - core/: ffactory.sh, ffactory_run_stack.sh, ffactory_run_app.sh, ffactory_status.sh, ffactory_shutdown.sh
  - health/: stack_health.sh
  - ai/: run_agent.sh
- `ai/`:
  - prompts/, skills_tracks/, datasets/, patterns/
- `reports/` + `audit/`: تقارير وحوكمة.

### 5.2 تكامل SmartFriend Suite

Stack: `smartfriend_suite` في `config/factory_manifest.yaml`:

- type: systemd
- services: sf-core, sf-web, sf-health, sf-bot
- db_path: `/opt/smartfriend-suite/var/db/smartfriend_unified.db`

أوامر من HyperFFactory:
- تشغيل:
  - `scripts/core/ffactory.sh start-stack smartfriend_suite`
- إيقاف:
  - ضمن `ffactory_shutdown.sh` (systemctl stop …)
- Status/Health:
  - يظهر status داخل تقارير stack_status.

---

## 6. الهدف النهائي

- منصة موحّدة:
  - تدير smartfriend-suite و ffactory كمصانع فرعية.
  - تضيف عليهم HyperFFactory كـ Orchestrator ذكي.
  - تستغل الـ Agents (Debug / Architect / Coach / Spider) لخدمة كل النظام.

---

## 7. آخر نقطة وقفنا عندها (تُحدَّث يدويًا)

- تم إنشاء:
  - هيكل HyperFFactory موحّد تحت /root/HyperFFactory.
  - تكامل مبدئي مع smartfriend-suite كـ stack systemd.
  - سكربتات ffactory الأساسية: start/health/status/shutdown.
  - ملف هوية المصنع الحالي: هذا الملف.

- المطلوب في الجلسات القادمة:
  - ربط فعلي مع smartfriend_unified.db (تحليل، تقارير).
  - بناء Dashboard بسيطة لتقارير المصنع.
  - تفعيل Agents حقيقيًا عبر Python / AI Gateway.
