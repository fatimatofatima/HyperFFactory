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
