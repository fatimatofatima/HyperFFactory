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
