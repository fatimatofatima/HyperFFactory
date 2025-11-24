#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/root/HyperFFactory"

echo "[*] Fixing HyperFFactory core scripts under: ${BASE_DIR}"

mkdir -p "${BASE_DIR}/scripts/core" "${BASE_DIR}/scripts/health"
mkdir -p "${BASE_DIR}/reports/stack_status" "${BASE_DIR}/reports/apps_status" "${BASE_DIR}/reports/ai_eval"
mkdir -p "${BASE_DIR}/config" "${BASE_DIR}/ai" "${BASE_DIR}/apps" "${BASE_DIR}/stack" "${BASE_DIR}/audit"

############################################
# 1) /root/init_hyper_ffactory.sh
############################################
cat > /root/init_hyper_ffactory.sh << 'EOF_INIT'
#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${1:-/root/HyperFFactory}"

echo "[*] Init HyperFFactory base at: ${BASE_DIR}"

mkdir -p "${BASE_DIR}/config"
mkdir -p "${BASE_DIR}/stack/core" "${BASE_DIR}/stack/monitoring" "${BASE_DIR}/stack/ai_support"
mkdir -p "${BASE_DIR}/apps/timeline_analyzer" "${BASE_DIR}/apps/netflow_inspector" "${BASE_DIR}/apps/backend_coach_api"
mkdir -p "${BASE_DIR}/scripts/core" "${BASE_DIR}/scripts/health" "${BASE_DIR}/scripts/fix" "${BASE_DIR}/scripts/ai"
mkdir -p "${BASE_DIR}/ai/prompts" "${BASE_DIR}/ai/patterns" "${BASE_DIR}/ai/skills_tracks" "${BASE_DIR}/ai/datasets"
mkdir -p "${BASE_DIR}/reports/stack_status" "${BASE_DIR}/reports/apps_status" "${BASE_DIR}/reports/ai_eval"
mkdir -p "${BASE_DIR}/audit"

if [ ! -f "${BASE_DIR}/README.md" ]; then
  cat > "${BASE_DIR}/README.md" << 'EOF_README'
# HyperFFactory – Unified Smart Factory

- orchestrator موحّد للـ stacks:
  - core_elk
  - monitoring
  - ai_support
  - smartfriend_suite (systemd sf-* services)
- سكربتات التحكم الأساسية:
  - scripts/core/ffactory.sh
  - scripts/core/ffactory_status.sh
  - scripts/core/ffactory_shutdown.sh
  - scripts/health/stack_health.sh
EOF_README
fi

echo "[*] HyperFFactory init done. Example:"
echo "    cd ${BASE_DIR}"
echo "    scripts/core/ffactory.sh health"
echo "    scripts/core/ffactory.sh status"
EOF_INIT

chmod +x /root/init_hyper_ffactory.sh

############################################
# 2) scripts/health/stack_health.sh
############################################
cat > "${BASE_DIR}/scripts/health/stack_health.sh" << 'EOF_HEALTH'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"
REPORT_DIR="${ROOT_DIR}/reports/stack_status"

mkdir -p "${REPORT_DIR}"

NOW="$(date +'%Y%m%d_%H%M%S')"
REPORT_FILE="${REPORT_DIR}/stack_health_${NOW}.txt"

echo "HyperFFactory Stack Health - ${NOW}" | tee "${REPORT_FILE}"
echo "==================================" | tee -a "${REPORT_FILE}"

# قراءة الـ stacks من factory_manifest.yaml (أسطر: "  - id: core_elk")
STACK_IDS="$(grep ' - id:' "${CONFIG_DIR}/factory_manifest.yaml" | awk '{print $3}' | tr -d '"')"

for STACK_ID in ${STACK_IDS}; do
  echo "" | tee -a "${REPORT_FILE}"
  echo "Stack: ${STACK_ID}" | tee -a "${REPORT_FILE}"
  echo "--------------------" | tee -a "${REPORT_FILE}"

  if [[ "${STACK_ID}" == "smartfriend_suite" ]]; then
    systemctl -a | grep -E 'sf-core|sf-web|sf-health|sf-bot' | tee -a "${REPORT_FILE}" || \
      echo "  No sf-* services found" | tee -a "${REPORT_FILE}"
    continue
  fi

  COMPOSE_FILE="$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" \
      | grep 'compose_file' | awk '{print $2}' | tr -d '"')"
  COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"

  if [[ -f "${COMPOSE_PATH}" ]]; then
    docker compose -f "${COMPOSE_PATH}" ps | tee -a "${REPORT_FILE}"
  else
    echo "Compose file not found: ${COMPOSE_PATH}" | tee -a "${REPORT_FILE}"
  fi
done
EOF_HEALTH

chmod +x "${BASE_DIR}/scripts/health/stack_health.sh"

############################################
# 3) scripts/core/ffactory_status.sh
############################################
cat > "${BASE_DIR}/scripts/core/ffactory_status.sh" << 'EOF_STATUS'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"
REPORT_DIR="${ROOT_DIR}/reports/stack_status"
mkdir -p "${REPORT_DIR}"

NOW="$(date +'%Y%m%d_%H%M%S')"
REPORT_FILE="${REPORT_DIR}/ffactory_status_${NOW}.txt"

echo "HyperFFactory – Status ${NOW}" | tee "${REPORT_FILE}"
echo "===============================" | tee -a "${REPORT_FILE}"

STACK_IDS="$(grep ' - id:' "${CONFIG_DIR}/factory_manifest.yaml" | awk '{print $3}' | tr -d '"')"

for STACK_ID in ${STACK_IDS}; do
  echo "" | tee -a "${REPORT_FILE}"
  echo "Stack: ${STACK_ID}" | tee -a "${REPORT_FILE}"
  echo "--------------------" | tee -a "${REPORT_FILE}"

  if [[ "${STACK_ID}" == "smartfriend_suite" ]]; then
    systemctl -a | grep -E 'sf-core|sf-web|sf-health|sf-bot' | tee -a "${REPORT_FILE}" || \
      echo "  No sf-* services found" | tee -a "${REPORT_FILE}"
    continue
  fi

  COMPOSE_FILE="$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" \
      | grep 'compose_file' | awk '{print $2}' | tr -d '"')"
  COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"

  if [[ -f "${COMPOSE_PATH}" ]]; then
    docker compose -f "${COMPOSE_PATH}" ps | tee -a "${REPORT_FILE}"
  else
    echo "Compose file not found: ${COMPOSE_PATH}" | tee -a "${REPORT_FILE}"
  fi
done

echo "" | tee -a "${REPORT_FILE}"
echo "Docker containers (summary):" | tee -a "${REPORT_FILE}"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | tee -a "${REPORT_FILE}"
EOF_STATUS

chmod +x "${BASE_DIR}/scripts/core/ffactory_status.sh"

############################################
# 4) scripts/core/ffactory_shutdown.sh
############################################
cat > "${BASE_DIR}/scripts/core/ffactory_shutdown.sh" << 'EOF_SHUT'
#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

echo "[FFactory] Shutting down all stacks (docker + smartfriend_suite)..."

STACK_IDS="$(grep ' - id:' "${CONFIG_DIR}/factory_manifest.yaml" | awk '{print $3}' | tr -d '"')"

for STACK_ID in ${STACK_IDS}; do
  if [[ "${STACK_ID}" == "smartfriend_suite" ]]; then
    echo "[FFactory] Stopping SmartFriend Suite via systemd..."
    systemctl stop sf-core.service sf-web.service sf-health.service sf-bot.service || true
    continue
  fi

  COMPOSE_FILE="$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" \
      | grep 'compose_file' | awk '{print $2}' | tr -d '"')"
  COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"

  if [[ -f "${COMPOSE_PATH}" ]]; then
    echo "[FFactory] Stopping stack: ${STACK_ID} (docker compose down)..."
    docker compose -f "${COMPOSE_PATH}" down || true
  else
    echo "[FFactory] WARNING: compose file not found for stack ${STACK_ID}: ${COMPOSE_PATH}"
  fi
done
EOF_SHUT

chmod +x "${BASE_DIR}/scripts/core/ffactory_shutdown.sh"

echo "[*] HyperFFactory core scripts fixed."
