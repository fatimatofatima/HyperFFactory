#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-/root/HyperFFactory}"

if [[ ! -d "$ROOT_DIR" ]]; then
  echo "Root dir not found: $ROOT_DIR"
  echo "شغّل أولاً: /root/bootstrap_hyper_ffactory.sh /root/HyperFFactory"
  exit 1
fi

echo "==> Updating HyperFFactory extras in: $ROOT_DIR"

############################################
# 1) تحديث ملف الهوية MY_FACTORY_NOTES.md
############################################

cat > "$ROOT_DIR/MY_FACTORY_NOTES.md" <<'EOF_NOTES'
# 🏭 HyperFFactory – مصنع العمال الأذكياء

## 1. أنا مين؟

- المالك: مبرمج بيشتغل بعقلية مصنع:
  - يحب الخوارزميات، تحليل البيانات، حل المشاكل.
  - هدفه يبني "عقل مساعد" يشبهه في الشغل والتفكير.
- طريقة التفكير:
  - كل حاجة عبارة عن: نظام → موديولات → عمال → خطوط إنتاج.
  - مفيش خطوة بدون سبب، ومفيش نظام بدون قياس وتحسين.

### 1.1 المصانع/المشاريع المرتبطة

المصنع الحالي `HyperFFactory` هو مظلة موحّدة فوق عدّة مستودعات:

- `hyper-factory`  
  https://github.com/fatimatofatima/hyper-factory
- `ffactory`  
  https://github.com/fatimatofatima/ffactory
- `ffactory2`  
  https://github.com/fatimatofatima/ffactory2
- `smartfrind`  
  https://github.com/fatimatofatima/smartfrind
- `smartfriend-suite`  
  https://github.com/fatimatofatima/smartfriend-suite
- `other` (مكان التجارب والأدوات الإضافية)  
  https://github.com/fatimatofatima/other

هدف HyperFFactory: توحيد طريقة التفكير والتنظيم والتنفيذ فوق كل هذه المشاريع، بدون لمس أو كسر أي مشروع قائم، فقط إدارة وتكامل من طبقة أعلى.

---

## 2. فكرة المصنع (AI Factory)

المصنع مش مجرد Bot، ولا مجرد سكربتات، بل:

- **منصة** تبني وتدير "عمال أذكياء" (Agents) و"خطوط إنتاج" (Pipelines) حسب الحاجة.
- كل عامل له:
  - دور واضح.
  - مدخلات (Inputs).
  - مخرجات (Outputs).
  - مقاييس أداء (KPIs).

### 2.1 العمال الأساسيون (Agents)

- **Debug Expert**  
  عامل متخصص في:
  - تحليل Tracebacks والأخطاء.
  - شرح السبب الجذري Root Cause.
  - اقتراح إصلاح واضح + كود إن لزم.

- **System Architect**  
  عامل متخصص في:
  - تصميم الأنظمة والمعمارية (Services / APIs / DB Models).
  - تبسيط الأنظمة الكبيرة إلى موديولات نظيفة.

- **Technical Coach**  
  عامل يدرّب المبرمجين بمسارات مهارات (Skills & Tracks)، مثلاً:
  - Backend Junior.
  - Python Projects.

- **Knowledge Spider**  
  عنكبوت يجمع المعرفة:
  - مستندات، كتب، تقارير، كود.
  - يحوّلها إلى Knowledge Base منظمة جاهزة للاستخدام.

كل عامل يشتغل فوق نفس البنية الأساسية:

- 🧠 Foundation Model (LLM) قوي.
- 🧩 Orchestrator (HyperFFactory) يتحكم في من يشتغل ومتى.
- 🗃 Memory لتخزين حالة المستخدم والمصنع.
- 📚 Knowledge Base للمراجع (raw_knowledge → knowledge).
- 📈 Analytics & Quality (logs, feedback, evaluation).
- 🎯 Skills & Tracks لإدارة مستوى المتدرّب/المستخدم.

---

## 3. Layers / الطبقات الرئيسية في HyperFFactory

### 3.1 طبقة البيانات والمعرفة

- `raw_knowledge/`  
  - ملفات خام: كتب، ملخصات، مقالات، Docs من العنكبوت (Knowledge Spider).
- `knowledge/`  
  - ملفات جاهزة للاسترجاع (بعد التقسيم، التنظيف، الإثراء).
- **Ingestion Pipeline**  
  - سكربت/خدمة تقوم بـ:
    - سحب الملفات من المصادر.
    - تنظيف/تقسيم المحتوى.
    - حفظه في `knowledge/` + فهرسة (Vector DB لاحقًا).

### 3.2 طبقة الذكاء (AI Engine)

- **LLM Provider**  
  - أي مزوّد: OpenAI / DeepSeek / Local LLM / xAI…  
  - HyperFFactory لا يقيّد بنوع واحد، بل يعرّف واجهة مجردة.

- **AI Engine / Orchestrator**  
  مسؤول عن:
  - بناء الـ Prompt (Persona + Context + Knowledge + Patterns).
  - اختيار العامل (Debug / Architect / Coach / Spider).
  - تمرير الطلب للـ LLM وإرجاع الرد.
  - تسجيل كل شيء في `ai/datasets/messages.jsonl`.

### 3.3 طبقة الذاكرة والجودة

- **Memory Store**
  - UserProfile:
    - مستوى، أهداف، وقت متاح، Stack مفضلة.
  - UserHistory:
    - ملخص الجلسات السابقة والمشاريع.

- **Conversation Log**
  - `ai/datasets/messages.jsonl`:  
    كل سؤال/جواب يتسجّل كسطر JSONL.

- **Quality Store**
  - `ai/datasets/quality.json`:  
    تقييمات `/good` و`/bad`، ملاحظات جودة، أسباب.

- **Patterns**
  - `ai/patterns/patterns.json`:  
    دروس وأنماط تم استخراجها من الأخطاء والتجارب:
    - أنماط Bugs متكررة.
    - أنماط نجاح حلول معينة.
    - Correlations بين نوع السؤال ونوع الفشل.

---

## 4. Skills & Tracks (مسار Backend Junior – نسخة تشغيلية)

**Track ID:** `backend_junior`

يُدار من خلال:

- ملف كونفيج عام: `config/skills_tracks_backend.yaml`
- ملف Skills مخصوص للـ AI Coach:  
  `ai/skills_tracks/backend_junior_skills.yaml`

### Phase 0 – الأساسيات

- `computer_basics`
- `terminal_basics`
- `git_basics`

### Phase 1 – أساسيات بايثون

- `python_syntax_basics`
- `python_control_flow`
- `python_functions_basics`
- `python_collections_basics`

### Phase 2 – بايثون المتقدمة للمشاريع

- `python_oop_basics`
- `python_errors_handling`
- `python_modules_packages`
- `python_venv_pip`

### Phase 3 – Backend Basics

- `web_http_fundamentals`
- `rest_api_concepts`
- `backend_framework_intro`
- `request_response_handling`

### Phase 4 – قواعد بيانات

- `db_relational_basics`
- `sql_query_basics`
- `db_modeling_basic`
- `orm_basics`

### Phase 5 – Backend Craft

- `auth_basics`
- `validation_and_schemas`
- `logging_basics`
- `testing_basics`

### Phase 6 – Deployment

- `environments_config`
- `basic_deployment_vps`
- `container_intro`

لكل مستخدم، حالة المهارات:

- **UserSkillState:**
  - score 0–100 لكل Skill.
  - track_id الحالي.
  - current_phase.
  - current_focus_skill.

---

## 5. مصانع الـ System (Linux / Windows)

### 5.1 مصنع Linux – HyperFFactory Stack

داخل `HyperFFactory/`:

- `config/`
  - `factory_manifest.yaml` → تعريف المصنع، الـ stacks، روابط apps/agents.
  - `apps.yaml` → تعريف كل App.
  - `agents.yaml` → تعريف كل Agent.
  - `skills_tracks_backend.yaml` → تعريف مسار Backend Junior.

- `stack/`
  - `core/` → ELK وغيرهم.
  - `monitoring/` → Prometheus / Grafana.
  - `ai_support/` → Vector DB / AI Gateway.

- `apps/`
  - `timeline_analyzer/` → تحليل لوجات وخطوط زمن.
  - `netflow_inspector/` → تحليل Netflow وربطه بالـ logs.
  - `backend_coach_api/` → API لتدريب Backend Junior.

- `scripts/`
  - `core/` → تشغيل/إيقاف/حالة/Shutdown للمصنع.
  - `health/` → تقارير صحة stacks / apps / snapshot.
  - `fix/` → سكربتات إصلاح آمنة (Ports / Security / Reset Safe).
  - `ai/` → سكربتات AI (تشغيل Agents / تحليل logs / توليد بيانات تدريب).

- `ai/`
  - `prompts/` → Prompts للعمال (Debug/Architect/Coach/Spider).
  - `patterns/` → `patterns.json`.
  - `skills_tracks/` → `backend_junior_skills.yaml`.
  - `datasets/` → `messages.jsonl`, `quality.json`, ملفات تدريب إضافية.

- `reports/`
  - `stack_status/` → تقارير صحة الـ stacks.
  - `apps_status/` → تقارير صحة الـ apps.
  - `ai_eval/` → تقارير تقييم AI.

- `audit/`
  - `actions.log` → عمليات المصنع (start/stop/health/...).
  - `security_events.log` → أحداث الأمان.

### 5.2 مصنع Windows – (مستقبلي) WPF Shell

- Orchestrator على ويندوز:
  - يقرأ `modules.json`.
  - يعرض قائمة Modules (سيرفرات، سكربتات، أدوات).
  - لكل Module: Start / Stop / Health (cmd / ps1).
- Settings:
  - `appsettings.json`: ScriptRoot, HealthTimeout, LogDirectory.

الهدف:  
واجهة واحدة على ويندوز لإدارة كل ما يتعلق بـ HyperFFactory والسيرفرات الموصولة به.

---

## 6. الحلم / الهدف النهائي

تحويل HyperFFactory إلى منصة:

1. تساعد المبرمجين يتعلموا ويتطوروا:
   - Technical Coach + Skills & Tracks.
   - Feedback Loop + Patterns + Quality.

2. تساعد المبرمجين تحل Bugs وتبني Systems:
   - Debug Expert + System Architect.
   - Patterns من الأخطاء السابقة.

3. تساعد المحللين والفورنزك يسيطروا على بيئة معقدة:
   - apps + stack + scripts + AI Orchestrator.
   - تقارير صحّة + تقارير أنماط + Dashboards.

كل ده فوق البنية الحالية (smartfriend-suite / ffactory / hyper-factory)، بدون تضارب، مع فصل واضح بين:

- **Core Systems** (الموجودة في GitHub).
- **HyperFFactory Orchestrator** (إدارة وتشغيل وتدريب فوقها).

---

## 7. آخر نقطة وقفنا عندها (تُحدّث يدويًا منك)

> حدّث هذا الجزء يدويًا في كل جلسة مهمة.

- آخر قرار مهم:
  - …

- آخر تعديل في HyperFFactory:
  - …

- المطلوب في الجلسة الجاية:
  - تصميم Factory Manager أكثر تفصيلاً لقواعد توزيع الشغل بين العمال.
  - إضافة Dashboard بسيطة لتقارير المصنع (Web أو TUI).
  - ربط logs حقيقية من smartfriend-suite / ffactory إلى `ai/datasets/`.
EOF_NOTES

############################################
# 2) skills_tracks/backend_junior_skills.yaml
############################################

mkdir -p "$ROOT_DIR/ai/skills_tracks"

cat > "$ROOT_DIR/ai/skills_tracks/backend_junior_skills.yaml" <<'EOF_SK'
track_id: backend_junior
name: "Backend Junior Skills – HyperFFactory"
phases:
  - id: phase0_basics
    name: "أساسيات الحاسب"
    skills:
      - id: computer_basics
        name: "Computer Basics"
      - id: terminal_basics
        name: "Terminal Basics"
      - id: git_basics
        name: "Git Basics"

  - id: phase1_python_core
    name: "أساسيات بايثون"
    skills:
      - id: python_syntax_basics
        name: "Python Syntax Basics"
      - id: python_control_flow
        name: "Control Flow"
      - id: python_functions_basics
        name: "Functions Basics"
      - id: python_collections_basics
        name: "Collections Basics"

  - id: phase2_python_project
    name: "بايثون للمشاريع"
    skills:
      - id: python_oop_basics
        name: "OOP Basics"
      - id: python_errors_handling
        name: "Error Handling"
      - id: python_modules_packages
        name: "Modules & Packages"
      - id: python_venv_pip
        name: "venv & pip"

  - id: phase3_backend_basics
    name: "Backend Basics"
    skills:
      - id: web_http_fundamentals
        name: "HTTP Fundamentals"
      - id: rest_api_concepts
        name: "REST API Concepts"
      - id: backend_framework_intro
        name: "Backend Framework Intro"
      - id: request_response_handling
        name: "Request/Response Handling"

  - id: phase4_db
    name: "قواعد البيانات"
    skills:
      - id: db_relational_basics
        name: "Relational DB Basics"
      - id: sql_query_basics
        name: "SQL Query Basics"
      - id: db_modeling_basic
        name: "DB Modeling Basics"
      - id: orm_basics
        name: "ORM Basics"

  - id: phase5_craft
    name: "Backend Craft"
    skills:
      - id: auth_basics
        name: "Auth Basics"
      - id: validation_and_schemas
        name: "Validation & Schemas"
      - id: logging_basics
        name: "Logging Basics"
      - id: testing_basics
        name: "Testing Basics"

  - id: phase6_deploy
    name: "النشر"
    skills:
      - id: environments_config
        name: "Environments & Config"
      - id: basic_deployment_vps
        name: "Basic VPS Deployment"
      - id: container_intro
        name: "Containers Intro"
EOF_SK

############################################
# 3) scripts/health/app_health.sh
############################################

HEALTH_DIR="$ROOT_DIR/scripts/health"
mkdir -p "$HEALTH_DIR"

cat > "$HEALTH_DIR/app_health.sh" <<'EOF_APP_H'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"
REPORT_DIR="${ROOT_DIR}/reports/apps_status"

mkdir -p "${REPORT_DIR}"

NOW=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${REPORT_DIR}/apps_health_${NOW}.txt"

echo "HyperFFactory Apps Health - ${NOW}" | tee "${REPORT_FILE}"
echo "==================================" | tee -a "${REPORT_FILE}"

# قراءة apps.yaml وتحليل الحالة البسيطة (run.sh + البورتات)
awk '/^- id:/{print $3}' "${CONFIG_DIR}/apps.yaml" | tr -d '"' | while read -r APP_ID; do
  [ -z "$APP_ID" ] && continue

  APP_BLOCK=$(awk "/- id: ${APP_ID}/{flag=1;next}/- id:/{flag=0}flag" "${CONFIG_DIR}/apps.yaml")
  APP_PATH=$(printf "%s\n" "$APP_BLOCK" | awk '/path:/{print $2}' | tr -d '"')
  PORTS=$(printf "%s\n" "$APP_BLOCK" | awk '/- ".*"/{print $2}' | tr -d '"')

  APP_DIR="${ROOT_DIR}/${APP_PATH}"
  RUN_SCRIPT="${APP_DIR}/run.sh"

  echo "" | tee -a "${REPORT_FILE}"
  echo "App: ${APP_ID}" | tee -a "${REPORT_FILE}"
  echo "-----------------" | tee -a "${REPORT_FILE}"
  echo "Path: ${APP_DIR}" | tee -a "${REPORT_FILE}"

  if [[ -x "${RUN_SCRIPT}" ]]; then
    echo "Run script: OK (${RUN_SCRIPT})" | tee -a "${REPORT_FILE}"
  else
    echo "Run script: MISSING or not executable (${RUN_SCRIPT})" | tee -a "${REPORT_FILE}"
  fi

  if [[ -n "$PORTS" ]]; then
    echo "Ports:" | tee -a "${REPORT_FILE}"
    for P in $PORTS; do
      if ss -tulpn | grep -q ":${P} "; then
        echo "  - ${P}: LISTEN (something is bound)" | tee -a "${REPORT_FILE}"
      else
        echo "  - ${P}: free (no listener)" | tee -a "${REPORT_FILE}"
      fi
    done
  else
    echo "Ports: none defined" | tee -a "${REPORT_FILE}"
  fi
done
EOF_APP_H
chmod +x "$HEALTH_DIR/app_health.sh"

############################################
# 4) scripts/health/full_snapshot.sh
############################################

cat > "$HEALTH_DIR/full_snapshot.sh" <<'EOF_SNAP'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="${ROOT_DIR}/reports"
NOW=$(date +"%Y%m%d_%H%M%S")
OUT="${REPORT_DIR}/full_snapshot_${NOW}.txt"

mkdir -p "${REPORT_DIR}"

{
  echo "HyperFFactory Full Snapshot - ${NOW}"
  echo "===================================="
  echo
  echo "## System"
  echo "### uptime"
  uptime
  echo
  echo "### df -h"
  df -h
  echo
  echo "### free -h"
  free -h || true
  echo
  echo "### docker ps"
  docker ps || true
  echo
  echo "## Stack Health"
} > "$OUT"

# stack health
if [[ -x "${ROOT_DIR}/scripts/health/stack_health.sh" ]]; then
  "${ROOT_DIR}/scripts/health/stack_health.sh" >> "$OUT" 2>&1 || true
fi

# apps health
if [[ -x "${ROOT_DIR}/scripts/health/app_health.sh" ]]; then
  "${ROOT_DIR}/scripts/health/app_health.sh" >> "$OUT" 2>&1 || true
fi

echo "Snapshot written to: $OUT"
EOF_SNAP
chmod +x "$HEALTH_DIR/full_snapshot.sh"

############################################
# 5) scripts/fix/* (إصلاحات آمنة)
############################################

FIX_DIR="$ROOT_DIR/scripts/fix"
mkdir -p "$FIX_DIR"

cat > "$FIX_DIR/security_autofix.sh" <<'EOF_SEC'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[SECURITY] HyperFFactory security_autofix (project-local only)"

# تشديد صلاحيات مجلد audit
if [[ -d "${ROOT_DIR}/audit" ]]; then
  chmod -R go-rwx "${ROOT_DIR}/audit"
  echo "  - audit perms hardened."
fi

# تشديد صلاحيات السكربتات
find "${ROOT_DIR}/scripts" -type f -name "*.sh" -exec chmod u+x {} \; -exec chmod go-rwx {} \; 2>/dev/null || true
echo "  - scripts perms tightened (u+x, go-rwx)."

echo "[SECURITY] Done (no system-wide changes)."
EOF_SEC
chmod +x "$FIX_DIR/security_autofix.sh"

cat > "$FIX_DIR/fix_ports.sh" <<'EOF_PORTS'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

echo "[PORTS] Checking declared ports in apps.yaml and stacks (static list)."
echo

# من apps.yaml
echo "== Apps Ports =="
awk '/ports:/{flag=1;next}/description:/{flag=0}flag' "${CONFIG_DIR}/apps.yaml" | awk '/- ".*"/{print $2}' | tr -d '"' | sort -u | while read -r P; do
  [ -z "$P" ] && continue
  if ss -tulpn | grep -q ":${P} "; then
    echo "  - ${P}: BUSY"
  else
    echo "  - ${P}: FREE"
  fi
done

echo
echo "== Core Stack Known Ports =="
# قائمة ثابتة من docker-compose (يمكن تعديلها حسب الحاجة)
for P in 9200 5601 9091 3000 5439 8280; do
  if ss -tulpn | grep -q ":${P} "; then
    echo "  - ${P}: BUSY"
  else
    echo "  - ${P}: FREE"
  fi
done

echo
echo "[PORTS] No automatic changes performed. Use this التقرير لاتخاذ قرار يدوي."
EOF_PORTS
chmod +x "$FIX_DIR/fix_ports.sh"

cat > "$FIX_DIR/reset_stack_safe.sh" <<'EOF_RESET'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[RESET] Safe reset for HyperFFactory stacks."

if [[ -x "${ROOT_DIR}/scripts/core/ffactory_shutdown.sh" ]]; then
  "${ROOT_DIR}/scripts/core/ffactory_shutdown.sh"
else
  echo "ffactory_shutdown.sh not found."
fi

echo "[RESET] Done (docker compose down executed for all stacks defined in factory_manifest.yaml)."
EOF_RESET
chmod +x "$FIX_DIR/reset_stack_safe.sh"

############################################
# 6) scripts/ai/analyze_logs_for_patterns.sh
############################################

AI_DIR="$ROOT_DIR/scripts/ai"
mkdir -p "$AI_DIR"

cat > "$AI_DIR/analyze_logs_for_patterns.sh" <<'EOF_ALP'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATASET="${ROOT_DIR}/ai/datasets/messages.jsonl"
REPORT_DIR="${ROOT_DIR}/reports/ai_eval"
mkdir -p "${REPORT_DIR}"

NOW=$(date +"%Y%m%d_%H%M%S")
OUT="${REPORT_DIR}/patterns_${NOW}.txt"

echo "HyperFFactory – Simple Patterns Report - ${NOW}" | tee "${OUT}"
echo "===============================================" | tee -a "${OUT}"

if [[ ! -f "$DATASET" ]]; then
  echo "messages.jsonl not found: $DATASET" | tee -a "${OUT}"
  exit 0
fi

TOTAL=$(wc -l < "$DATASET" || echo 0)
echo "Total lines in messages.jsonl: $TOTAL" | tee -a "${OUT}"

echo >> "${OUT}"
echo "Top keywords (very naive grep counts):" | tee -a "${OUT}"

for KW in ERROR Traceback WARNING BUG FIX TODO; do
  CNT=$(grep -i "$KW" "$DATASET" 2>/dev/null | wc -l || echo 0)
  echo "  - ${KW}: ${CNT}" | tee -a "${OUT}"
done

echo >> "${OUT}"
echo "This is فقط تحليل بدائي. لاحقًا يربط مع Python/LLM لتحليل أعمق." | tee -a "${OUT}"

EOF_ALP
chmod +x "$AI_DIR/analyze_logs_for_patterns.sh"

############################################
# 7) scripts/ai/generate_training_data.sh
############################################

cat > "$AI_DIR/generate_training_data.sh" <<'EOF_GTD'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATA_DIR="${ROOT_DIR}/ai/datasets"

mkdir -p "${DATA_DIR}"

OUT="${DATA_DIR}/train_backend.jsonl"

echo "[AI] Generating placeholder training dataset for Backend Junior → ${OUT}"

cat > "${OUT}" <<'EOF_TRAIN'
{"track_id":"backend_junior","phase_id":"phase1_python_core","skill_id":"python_syntax_basics","input":"اشرح لي المتغيرات في بايثون مع أمثلة بسيطة.","target":"شرح مبسط للمتغيرات في بايثون + كود."}
{"track_id":"backend_junior","phase_id":"phase3_backend_basics","skill_id":"rest_api_concepts","input":"ما هو REST API؟","target":"تعريف REST API مع توضيح مبادئه الأساسية."}
EOF_TRAIN

echo "[AI] Done. عدّل هذا الملف لاحقًا ببيانات حقيقية من logs أو أسئلة المستخدمين."
EOF_GTD
chmod +x "$AI_DIR/generate_training_data.sh"

echo "==> Extras update completed."
