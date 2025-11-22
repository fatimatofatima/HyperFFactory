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
