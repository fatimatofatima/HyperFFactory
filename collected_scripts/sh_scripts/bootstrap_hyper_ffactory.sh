#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$HOME/HyperFFactory}"

echo "==> HyperFFactory bootstrap to: $ROOT_DIR"

# 1) المجلدات الرئيسية
mkdir -p \
  "$ROOT_DIR"/config \
  "$ROOT_DIR"/stack/core \
  "$ROOT_DIR"/stack/monitoring \
  "$ROOT_DIR"/stack/ai_support \
  "$ROOT_DIR"/apps/timeline_analyzer \
  "$ROOT_DIR"/apps/netflow_inspector \
  "$ROOT_DIR"/apps/backend_coach_api \
  "$ROOT_DIR"/scripts/core \
  "$ROOT_DIR"/scripts/health \
  "$ROOT_DIR"/scripts/fix \
  "$ROOT_DIR"/scripts/ai \
  "$ROOT_DIR"/ai/prompts \
  "$ROOT_DIR"/ai/patterns \
  "$ROOT_DIR"/ai/skills_tracks \
  "$ROOT_DIR"/ai/datasets \
  "$ROOT_DIR"/reports/stack_status \
  "$ROOT_DIR"/reports/apps_status \
  "$ROOT_DIR"/reports/ai_eval \
  "$ROOT_DIR"/audit

############################################
# 2) README مختصر + ملف هوية مختصر
############################################

cat > "$ROOT_DIR/README.md" <<'EOF_README'
# HyperFFactory

منصة موحّدة لإدارة:
- الـ stacks (Docker / Monitoring / AI)
- الـ apps (تحليل لوجات، Netflow، Backend Coach)
- الـ AI Agents (Debug Expert, System Architect, Technical Coach, Knowledge Spider)

كل شيء يدار عبر:
- ملفات config/* (manifests)
- سكربتات scripts/core/* (تشغيل/إيقاف/حالة)
- سكربتات health/fix/ai (صحة + إصلاح + ذكاء)
EOF_README

cat > "$ROOT_DIR/MY_FACTORY_NOTES.md" <<'EOF_NOTES'
# HyperFFactory – Identity Snapshot (مختصر)

- الهدف: منصة/مصنع موحّد فوق:
  - smartfriend-suite
  - ffactory / ffactory2
  - smartfrind
  - hyper-factory
  - other

- طريقة التفكير:
  - Systems → Modules → Workers (Agents / Services) → Pipelines.
  - كل خطوة لها سبب، وكل نظام له قياس وتحسين.

- الطبقات:
  - Data & Knowledge: raw_knowledge / knowledge (لاحقًا).
  - AI Engine: LLM + Orchestrator + Agents.
  - Memory & Quality: messages.jsonl, quality.json, patterns.json.
  - Skills & Tracks: backend_junior كأول مسار.

- Agents أساسيين:
  - debug_expert
  - system_architect
  - technical_coach
  - knowledge_spider

- نقطة تتبع يدوية (تحدّثها بنفسك):
  - آخر قرار:
  - آخر تعديل:
  - أولويات الجلسة الجاية:
EOF_NOTES

############################################
# 3) config/*  (manifestات المصنع)
############################################

CFG_DIR="$ROOT_DIR/config"

cat > "$CFG_DIR/factory_manifest.yaml" <<'EOF_FM'
factory:
  id: hyper_ffactory
  name: "Hyper FFactory – Unified Smart Factory"
  owner: "root"
  environment: "lab"      # lab / staging / prod
  version: "0.1.0"

stacks:
  - id: core_elk
    description: "Core logging & search stack (ELK)"
    compose_file: "stack/core/docker-compose.core.yml"

  - id: monitoring
    description: "Metrics & monitoring stack (Prometheus/Grafana)"
    compose_file: "stack/monitoring/docker-compose.monitoring.yml"

  - id: ai_support
    description: "AI support stack (vector DB, AI gateway, tools)"
    compose_file: "stack/ai_support/docker-compose.ai.yml"

apps_manifest: "config/apps.yaml"
agents_manifest: "config/agents.yaml"

logging:
  reports_dir: "reports"
  audit_file: "audit/actions.log"

security:
  require_confirm_for:
    - "reset_stack"
    - "security_autofix"
    - "full_wipe"
EOF_FM

cat > "$CFG_DIR/apps.yaml" <<'EOF_APPS'
apps:
  - id: timeline_analyzer
    name: "Timeline Analyzer"
    category: "forensics"
    path: "apps/timeline_analyzer"
    entry_script: "run.sh"
    required_stacks:
      - core_elk
    ports:
      - "8081"
    description: "تحليل خطوط الزمن من اللوجات والأحداث."

  - id: netflow_inspector
    name: "Netflow Inspector"
    category: "network"
    path: "apps/netflow_inspector"
    entry_script: "run.sh"
    required_stacks:
      - core_elk
      - monitoring
    ports:
      - "8082"
    description: "تحليل تدفق الشبكة وربطها باللوجات."

  - id: backend_coach_api
    name: "Backend Coach API"
    category: "ai_coach"
    path: "apps/backend_coach_api"
    entry_script: "run.sh"
    required_stacks:
      - ai_support
    ports:
      - "9090"
    description: "API لتدريب المبرمجين على مسار Backend Junior باستخدام Skills & Tracks."
EOF_APPS

cat > "$CFG_DIR/agents.yaml" <<'EOF_AGENTS'
agents:
  - id: debug_expert
    name: "Debug Expert"
    prompt_file: "ai/prompts/agent_debug_expert.md"
    skills_focus: ["python_errors_handling", "debug_skills"]
    logs_source: "ai/datasets/messages.jsonl"

  - id: system_architect
    name: "System Architect"
    prompt_file: "ai/prompts/agent_system_architect.md"
    skills_focus: ["rest_api_concepts", "db_modeling_basic"]
    logs_source: "ai/datasets/messages.jsonl"

  - id: technical_coach
    name: "Technical Coach"
    prompt_file: "ai/prompts/agent_technical_coach.md"
    skills_track_file: "ai/skills_tracks/backend_junior_skills.yaml"
    logs_source: "ai/datasets/messages.jsonl"

  - id: knowledge_spider
    name: "Knowledge Spider"
    prompt_file: "ai/prompts/agent_knowledge_spider.md"
    knowledge_raw_dir: "raw_knowledge"
    knowledge_dir: "knowledge"
EOF_AGENTS

cat > "$CFG_DIR/skills_tracks_backend.yaml" <<'EOF_SKILLS'
track:
  id: backend_junior
  name: "Backend Junior Track"
  phases:
    - id: phase0_basics
      name: "أساسيات الحاسب"
      skills:
        - computer_basics
        - terminal_basics
        - git_basics

    - id: phase1_python_core
      name: "أساسيات بايثون"
      skills:
        - python_syntax_basics
        - python_control_flow
        - python_functions_basics
        - python_collections_basics

    - id: phase2_python_project
      name: "بايثون للمشاريع"
      skills:
        - python_oop_basics
        - python_errors_handling
        - python_modules_packages
        - python_venv_pip

    - id: phase3_backend_basics
      name: "Backend Basics"
      skills:
        - web_http_fundamentals
        - rest_api_concepts
        - backend_framework_intro
        - request_response_handling

    - id: phase4_db
      name: "قواعد البيانات"
      skills:
        - db_relational_basics
        - sql_query_basics
        - db_modeling_basic
        - orm_basics

    - id: phase5_craft
      name: "Backend Craft"
      skills:
        - auth_basics
        - validation_and_schemas
        - logging_basics
        - testing_basics

    - id: phase6_deploy
      name: "النشر"
      skills:
        - environments_config
        - basic_deployment_vps
        - container_intro
EOF_SKILLS

############################################
# 4) stack/* (Docker compose placeholders)
############################################

cat > "$ROOT_DIR/stack/core/docker-compose.core.yml" <<'EOF_CORE_DC'
version: "3.9"

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
    environment:
      - discovery.type=single-node
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:8.15.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
EOF_CORE_DC

cat > "$ROOT_DIR/stack/monitoring/docker-compose.monitoring.yml" <<'EOF_MON_DC'
version: "3.9"

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
EOF_MON_DC

cat > "$ROOT_DIR/stack/ai_support/docker-compose.ai.yml" <<'EOF_AI_DC'
version: "3.9"

services:
  vectordb:
    image: ankane/pgvector
    environment:
      - POSTGRES_PASSWORD=changeme
    ports:
      - "5439:5432"

  ai_gateway:
    image: ghcr.io/example/ai-gateway:latest
    environment:
      - PROVIDER=openai
    ports:
      - "8280:8280"
EOF_AI_DC

############################################
# 5) apps/* (Run scripts placeholders)
############################################

# timeline_analyzer
cat > "$ROOT_DIR/apps/timeline_analyzer/run.sh" <<'EOF_TA_RUN'
#!/usr/bin/env bash
set -e
echo "[timeline_analyzer] placeholder – اربط هنا تحليل اللوجات/التايم لاين."
EOF_TA_RUN
chmod +x "$ROOT_DIR/apps/timeline_analyzer/run.sh"

# netflow_inspector
cat > "$ROOT_DIR/apps/netflow_inspector/run.sh" <<'EOF_NF_RUN'
#!/usr/bin/env bash
set -e
echo "[netflow_inspector] placeholder – اربط هنا تحليل Netflow + ELK."
EOF_NF_RUN
chmod +x "$ROOT_DIR/apps/netflow_inspector/run.sh"

# backend_coach_api
cat > "$ROOT_DIR/apps/backend_coach_api/run.sh" <<'EOF_BC_RUN'
#!/usr/bin/env bash
set -e
echo "[backend_coach_api] placeholder – اربط هنا FastAPI / Flask لتدريب Backend Junior."
EOF_BC_RUN
chmod +x "$ROOT_DIR/apps/backend_coach_api/run.sh"

############################################
# 6) scripts/core/* (مدير المصنع)
############################################

CORE_SCRIPTS="$ROOT_DIR/scripts/core"

cat > "$CORE_SCRIPTS/ffactory.sh" <<'EOF_FFACTORY'
#!/usr/bin/env bash
set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACTION="${1:-}"
TARGET="${2:-}"

usage() {
  echo "HyperFFactory – Factory Controller"
  echo "Usage:"
  echo "  $0 start-stack <stack_id>"
  echo "  $0 start-app  <app_id>"
  echo "  $0 status"
  echo "  $0 health"
  echo "  $0 shutdown-all"
  exit 1
}

if [[ -z "$ACTION" ]]; then
  usage
fi

case "$ACTION" in
  start-stack)
    "$SCRIPTS_DIR/ffactory_run_stack.sh" "$TARGET"
    ;;
  start-app)
    "$SCRIPTS_DIR/ffactory_run_app.sh" "$TARGET"
    ;;
  status)
    "$SCRIPTS_DIR/ffactory_status.sh"
    ;;
  health)
    "$SCRIPTS_DIR/../health/stack_health.sh"
    ;;
  shutdown-all)
    "$SCRIPTS_DIR/ffactory_shutdown.sh"
    ;;
  *)
    usage
    ;;
esac
EOF_FFACTORY
chmod +x "$CORE_SCRIPTS/ffactory.sh"

cat > "$CORE_SCRIPTS/ffactory_run_stack.sh" <<'EOF_RUN_STACK'
#!/usr/bin/env bash
set -e

STACK_ID="${1:-}"
if [[ -z "$STACK_ID" ]]; then
  echo "Usage: $0 <stack_id>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

COMPOSE_FILE=$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" | grep "compose_file" | awk '{print $2}' | tr -d '"')

if [[ -z "$COMPOSE_FILE" ]]; then
  echo "Stack not found in manifest: ${STACK_ID}"
  exit 1
fi

COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"

echo "[FFactory] Starting stack: ${STACK_ID}"
docker compose -f "${COMPOSE_PATH}" up -d
EOF_RUN_STACK
chmod +x "$CORE_SCRIPTS/ffactory_run_stack.sh"

cat > "$CORE_SCRIPTS/ffactory_run_app.sh" <<'EOF_RUN_APP'
#!/usr/bin/env bash
set -e

APP_ID="${1:-}"
if [[ -z "$APP_ID" ]]; then
  echo "Usage: $0 <app_id>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

APP_PATH=$(awk "/id: ${APP_ID}/{flag=1;next}/id:/{flag=0}flag" "${CONFIG_DIR}/apps.yaml" | grep "path:" | awk '{print $2}' | tr -d '"')

if [[ -z "$APP_PATH" ]]; then
  echo "App not found in apps.yaml: ${APP_ID}"
  exit 1
fi

APP_DIR="${ROOT_DIR}/${APP_PATH}"
RUN_SCRIPT="${APP_DIR}/run.sh"

if [[ ! -x "${RUN_SCRIPT}" ]]; then
  echo "Run script not found or not executable: ${RUN_SCRIPT}"
  exit 1
fi

echo "[FFactory] Starting app: ${APP_ID}"
( cd "${APP_DIR}" && "${RUN_SCRIPT}" )
EOF_RUN_APP
chmod +x "$CORE_SCRIPTS/ffactory_run_app.sh"

cat > "$CORE_SCRIPTS/ffactory_status.sh" <<'EOF_STATUS'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

echo "== Stacks =="
grep "id:" "${CONFIG_DIR}/factory_manifest.yaml" | grep -v "factory:" || true

echo
echo "== Apps =="
grep "id:" "${CONFIG_DIR}/apps.yaml" || true
EOF_STATUS
chmod +x "$CORE_SCRIPTS/ffactory_status.sh"

cat > "$CORE_SCRIPTS/ffactory_shutdown.sh" <<'EOF_SHUT'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

echo "[FFactory] Shutdown all stacks (docker compose down)..."

grep "id:" "${CONFIG_DIR}/factory_manifest.yaml" | grep -v "factory:" | awk '{print $2}' | tr -d '"' | while read -r STACK_ID; do
  [ -z "$STACK_ID" ] && continue
  COMPOSE_FILE=$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" | grep "compose_file" | awk '{print $2}' | tr -d '"')
  COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"
  if [[ -f "$COMPOSE_PATH" ]]; then
    echo "  - down: $STACK_ID"
    docker compose -f "$COMPOSE_PATH" down || true
  fi
done
EOF_SHUT
chmod +x "$CORE_SCRIPTS/ffactory_shutdown.sh"

############################################
# 7) scripts/health/*  (تقارير صحة)
############################################

HEALTH_SCRIPTS="$ROOT_DIR/scripts/health"

cat > "$HEALTH_SCRIPTS/stack_health.sh" <<'EOF_STACK_HEALTH'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"
REPORT_DIR="${ROOT_DIR}/reports/stack_status"

mkdir -p "${REPORT_DIR}"

NOW=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${REPORT_DIR}/stack_health_${NOW}.txt"

echo "HyperFFactory Stack Health - ${NOW}" | tee "${REPORT_FILE}"
echo "==================================" | tee -a "${REPORT_FILE}"

grep "id:" "${CONFIG_DIR}/factory_manifest.yaml" | grep -v "factory:" | awk '{print $2}' | tr -d '"' | while read -r STACK_ID; do
  [ -z "$STACK_ID" ] && continue
  COMPOSE_FILE=$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" | grep "compose_file" | awk '{print $2}' | tr -d '"')
  COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"

  echo "" | tee -a "${REPORT_FILE}"
  echo "Stack: ${STACK_ID}" | tee -a "${REPORT_FILE}"
  echo "--------------------" | tee -a "${REPORT_FILE}"

  if [[ -f "${COMPOSE_PATH}" ]]; then
    docker compose -f "${COMPOSE_PATH}" ps | tee -a "${REPORT_FILE}"
  else
    echo "Compose file not found: ${COMPOSE_PATH}" | tee -a "${REPORT_FILE}"
  fi
done
EOF_STACK_HEALTH
chmod +x "$HEALTH_SCRIPTS/stack_health.sh"

############################################
# 8) scripts/ai/*  (ربط الـ Agents)
############################################

AI_SCRIPTS="$ROOT_DIR/scripts/ai"

cat > "$AI_SCRIPTS/run_agent.sh" <<'EOF_RUN_AGENT'
#!/usr/bin/env bash
set -e

AGENT_ID="${1:-}"
if [[ -z "$AGENT_ID" ]]; then
  echo "Usage: $0 <agent_id> [extra args]"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

AGENT_PROMPT_FILE=$(awk "/id: ${AGENT_ID}/{flag=1;next}/id:/{flag=0}flag" "${CONFIG_DIR}/agents.yaml" | grep "prompt_file" | awk '{print $2}' | tr -d '"')

if [[ -z "$AGENT_PROMPT_FILE" ]]; then
  echo "Agent not found in agents.yaml: ${AGENT_ID}"
  exit 1
fi

PROMPT_PATH="${ROOT_DIR}/${AGENT_PROMPT_FILE}"

echo "[FFactory AI] Running agent: ${AGENT_ID}"
echo "Prompt file: ${PROMPT_PATH}"

# نقطة تكامل لاحقة:
# python3 ai/run_agent.py --agent "${AGENT_ID}" --prompt-file "${PROMPT_PATH}" "$@"
EOF_RUN_AGENT
chmod +x "$AI_SCRIPTS/run_agent.sh"

############################################
# 9) ai/prompts/*  (Prompts placeholder)
############################################

cat > "$ROOT_DIR/ai/prompts/agent_debug_expert.md" <<'EOF_P_DEB'
أنت عامل Debug Expert داخل HyperFFactory.
تركّز على:
- تحليل Tracebacks والأخطاء.
- شرح السبب الجذري.
- اقتراح إصلاح واضح مع كود إن لزم.
EOF_P_DEB

cat > "$ROOT_DIR/ai/prompts/agent_system_architect.md" <<'EOF_P_ARCH'
أنت System Architect داخل HyperFFactory.
تركّز على تصميم الأنظمة، تقسيمها إلى خدمات، وتوضيح الـ APIs والـ DB Models.
EOF_P_ARCH

cat > "$ROOT_DIR/ai/prompts/agent_technical_coach.md" <<'EOF_P_COACH'
أنت Technical Coach داخل HyperFFactory.
تعمل على تدريب المستخدم على مسار Backend Junior باستخدام Skills & Tracks.
EOF_P_COACH

cat > "$ROOT_DIR/ai/prompts/agent_knowledge_spider.md" <<'EOF_P_SPIDER'
أنت Knowledge Spider داخل HyperFFactory.
تجمع المعرفة من المصادر (Docs/كتب/تقارير) وتحولها إلى Knowledge Base منظمة.
EOF_P_SPIDER

############################################
# 10) ai/datasets و patterns placeholders
############################################

cat > "$ROOT_DIR/ai/datasets/messages.jsonl" <<'EOF_MSG'
{"role":"system","content":"HyperFFactory bootstrapped.","ts":"INIT"}
EOF_MSG

cat > "$ROOT_DIR/ai/datasets/quality.json" <<'EOF_Q'
[]
EOF_Q

cat > "$ROOT_DIR/ai/patterns/patterns.json" <<'EOF_PAT'
{
  "patterns": []
}
EOF_PAT

############################################
# 11) audit logs placeholders
############################################

cat > "$ROOT_DIR/audit/actions.log" <<'EOF_A1'
[INIT] HyperFFactory bootstrap completed.
EOF_A1

cat > "$ROOT_DIR/audit/security_events.log" <<'EOF_A2'
[INIT] No security events yet.
EOF_A2

echo "==> Done. HyperFFactory structure created."
echo "Root: $ROOT_DIR"
