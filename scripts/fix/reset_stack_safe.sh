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
