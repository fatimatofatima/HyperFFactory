#!/usr/bin/env bash
set -e

STACK_ID="${1:-}"
if [[ -z "$STACK_ID" ]]; then
  echo "Usage: $0 <stack_id>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

# دعم خاص لـ smartfriend_suite (systemd)
if [[ "$STACK_ID" == "smartfriend_suite" ]]; then
  echo "[FFactory] Starting SmartFriend Suite via systemd..."
  systemctl start sf-core.service sf-web.service sf-health.service sf-bot.service || true
  systemctl status sf-core.service --no-pager || true
  exit 0
fi

COMPOSE_FILE=$(grep -A3 "id: ${STACK_ID}" "${CONFIG_DIR}/factory_manifest.yaml" | grep "compose_file" | awk '{print $2}' | tr -d '"')

if [[ -z "$COMPOSE_FILE" ]]; then
  echo "Stack not found in manifest or compose_file empty: ${STACK_ID}"
  exit 1
fi

COMPOSE_PATH="${ROOT_DIR}/${COMPOSE_FILE}"

if [[ ! -f "${COMPOSE_PATH}" ]]; then
  echo "Compose file not found: ${COMPOSE_PATH}"
  exit 1
fi

echo "[FFactory] Starting stack: ${STACK_ID}"
docker compose -f "${COMPOSE_PATH}" up -d
