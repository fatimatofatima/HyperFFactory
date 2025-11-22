#!/usr/bin/env bash
set -e

AGENT_ID="${1:-}"
if [[ -z "$AGENT_ID" ]]; then
  echo "Usage: $0 <agent_id> [extra args...]"
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

cat "${PROMPT_PATH}"
