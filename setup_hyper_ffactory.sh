#!/usr/bin/env bash
set -e

BASE_DIR="$(pwd)/HyperFFactory"
echo "[HyperFFactory] Base dir: ${BASE_DIR}"
mkdir -p "${BASE_DIR}"

mkdir -p "${BASE_DIR}/config"
mkdir -p "${BASE_DIR}/stack/core"
mkdir -p "${BASE_DIR}/stack/monitoring"
mkdir -p "${BASE_DIR}/stack/ai_support"
mkdir -p "${BASE_DIR}/apps/timeline_analyzer"
mkdir -p "${BASE_DIR}/apps/netflow_inspector"
mkdir -p "${BASE_DIR}/apps/backend_coach_api"
mkdir -p "${BASE_DIR}/scripts/core"
mkdir -p "${BASE_DIR}/scripts/health"
mkdir -p "${BASE_DIR}/scripts/fix"
mkdir -p "${BASE_DIR}/scripts/ai"
mkdir -p "${BASE_DIR}/ai/prompts"
mkdir -p "${BASE_DIR}/ai/patterns"
mkdir -p "${BASE_DIR}/ai/skills_tracks"
mkdir -p "${BASE_DIR}/ai/datasets"
mkdir -p "${BASE_DIR}/reports/stack_status"
mkdir -p "${BASE_DIR}/reports/apps_status"
mkdir -p "${BASE_DIR}/reports/ai_eval"
mkdir -p "${BASE_DIR}/audit"

touch "${BASE_DIR}/audit/actions.log"
touch "${BASE_DIR}/audit/security_events.log"

cat > "${BASE_DIR}/README.md" <<'EOF_README'
# HyperFFactory – Unified Smart Factory

مصنع موحّد لإدارة:
- الـ Stacks (Docker / Services / Monitoring / AI Support)
- الـ Apps (تحليل زمني، مراقبة الشبكة، Backend Coach)
- طبقة الذكاء (Agents + Skills + Datasets)

## أوامر التشغيل:
scripts/core/ffactory.sh start-stack core_elk
scripts/core/ffactory.sh start-app backend_coach_api  
scripts/core/ffactory.sh status
scripts/core/ffactory.sh health
scripts/core/ffactory.sh shutdown-all
EOF_README

cat > "${BASE_DIR}/MY_FACTORY_NOTES.md" <<'EOF_NOTES'
🏭 HyperFFactory – مصنع العمال الأذكياء

1. من أنا؟
• المالك: مبرمج بعقلية مصنع
• يحب الخوارزميات، تحليل البيانات، حل المشاكل
• هدف: بناء "عقل مساعد" يشبهه في التفكير

2. فكرة المصنع (AI Factory)
HyperFFactory ليس Bot واحد، بل مصنع يبني "عمال أذكياء":
• Debug Expert → متخصص في حل الأخطاء
• System Architect → متخصص في تصميم الأنظمة  
• Technical Coach → مدرب للمبرمجين
• Knowledge Spider → جامع للمعرفة

3. Skills & Tracks – Backend Junior
مسار متكامل من الصفر حتى النشر:
Phase 0: Basics
Phase 1: Python Basics  
Phase 2: Python Projects
Phase 3: Backend Basics
Phase 4: Databases
Phase 5: Backend Craft
Phase 6: Deployment
EOF_NOTES

cat > "${BASE_DIR}/config/factory_manifest.yaml" <<'EOF_FACTORY'
factory:
  id: hyper_ffactory
  name: "HyperFFactory – Unified Smart Factory"
  owner: "Angel-Malak"
  version: "0.1.0"

stacks:
  - id: core_elk
    name: "Core ELK & DB"
    compose_file: "stack/core/docker-compose.core.yml"
  - id: monitoring  
    name: "Monitoring & Metrics"
    compose_file: "stack/monitoring/docker-compose.monitoring.yml"
  - id: ai_support
    name: "AI Support Stack" 
    compose_file: "stack/ai_support/docker-compose.ai.yml"

apps_manifest: "config/apps.yaml"
agents_manifest: "config/agents.yaml"
EOF_FACTORY

cat > "${BASE_DIR}/config/stacks.yaml" <<'EOF_STACKS'
stacks:
  core_elk:
    purpose: "Logs + Search + Core DB"
    services:
      - elasticsearch
      - kibana  
      - logstash
      - postgres
    tags: ["core", "logging", "search", "db"]

  monitoring:
    purpose: "Metrics + Dashboards" 
    services:
      - prometheus
      - grafana
    tags: ["monitoring", "metrics", "dashboards"]

  ai_support:
    purpose: "Models + Vectors + AI Gateway"
    services:
      - vector_db
      - ai_gateway
      - ollama_or_other
    tags: ["ai", "llm", "gateway", "vector"]
EOF_STACKS

cat > "${BASE_DIR}/config/apps.yaml" <<'EOF_APPS'
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

  - id: backend_coach_api
    name: "Backend Coach API"
    category: "ai_coach"
    path: "apps/backend_coach_api" 
    entry_script: "run.sh"
    required_stacks:
      - ai_support
    ports:
      - "9090"
EOF_APPS

cat > "${BASE_DIR}/config/agents.yaml" <<'EOF_AGENTS'
agents:
  - id: debug_expert
    name: "Debug Expert"
    prompt_file: "ai/prompts/agent_debug_expert.md"
    skills_focus:
      - "python_errors_handling"
      - "debug_skills"

  - id: system_architect
    name: "System Architect" 
    prompt_file: "ai/prompts/agent_system_architect.md"
    skills_focus:
      - "rest_api_concepts"
      - "db_modeling_basic"

  - id: technical_coach
    name: "Technical Coach"
    prompt_file: "ai/prompts/agent_technical_coach.md"
    skills_track_file: "ai/skills_tracks/backend_junior_skills.yaml"

  - id: knowledge_spider
    name: "Knowledge Spider"
    prompt_file: "ai/prompts/agent_knowledge_spider.md"
    knowledge_raw_dir: "raw_knowledge"
    knowledge_dir: "knowledge"
EOF_AGENTS

cat > "${BASE_DIR}/config/skills_tracks_backend.yaml" <<'EOF_SKILLS'
tracks:
  - id: backend_junior
    name: "Backend Junior Track"
    description: "مسار متكامل من الصفر حتى النشر"
    phases:
      - id: phase0_basics
        name: "Phase 0 – الأساسيات"
        skills:
          - "computer_basics"
          - "terminal_basics" 
          - "git_basics"

      - id: phase1_python
        name: "Phase 1 – أساسيات بايثون"
        skills:
          - "python_syntax_basics"
          - "python_control_flow"
          - "python_functions_basics"

      - id: phase2_python_projects
        name: "Phase 2 – بايثون المتقدمة"
        skills:
          - "python_oop_basics" 
          - "python_errors_handling"
          - "python_modules_packages"

      - id: phase3_backend_basics
        name: "Phase 3 – Backend Basics"
        skills:
          - "web_http_fundamentals"
          - "rest_api_concepts"
          - "backend_framework_intro"

      - id: phase4_db
        name: "Phase 4 – قواعد بيانات"
        skills:
          - "db_relational_basics"
          - "sql_query_basics"
          - "db_modeling_basic"

      - id: phase5_craft
        name: "Phase 5 – Backend Craft"
        skills:
          - "auth_basics"
          - "validation_and_schemas" 
          - "logging_basics"

      - id: phase6_deploy
        name: "Phase 6 – Deployment"
        skills:
          - "environments_config"
          - "basic_deployment_vps"
          - "container_intro"
EOF_SKILLS

cat > "${BASE_DIR}/scripts/core/ffactory.sh" <<'EOF_FF_MAIN'
#!/usr/bin/env bash
set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACTION="$1"
TARGET="$2"

usage() {
cat <<EOF
HyperFFactory – Factory Controller

Usage:
$0 start-stack <stack_id>
$0 stop-stack  <stack_id> 
$0 start-app   <app_id>
$0 stop-app    <app_id>
$0 status
$0 health
$0 shutdown-all
