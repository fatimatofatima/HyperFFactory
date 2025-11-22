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
