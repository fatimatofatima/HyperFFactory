#!/usr/bin/env bash
set -e

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FACTORY_MANIFEST="${CONFIG_DIR}/factory_manifest.yaml"

ACTION="${1:-}"
TARGET="${2:-}"

usage() {
  echo "HyperFFactory – Factory Controller"
  echo "Usage:"
  echo "  $0 start-stack <stack_id>"
  echo "  $0 stop-stack <stack_id>"
  echo "  $0 start-app  <app_id>"
  echo "  $0 stop-app   <app_id>"
  echo "  $0 status"
  echo "  $0 health"
  echo "  $0 shutdown-all"
  exit 1
}

if [[ -z "${ACTION}" ]]; then
  usage
fi

run_stack() {
  local stack_id="$1"
  "${SCRIPTS_DIR}/ffactory_run_stack.sh" "$stack_id"
}

run_app() {
  local app_id="$1"
  "${SCRIPTS_DIR}/ffactory_run_app.sh" "$app_id"
}

case "$ACTION" in
  start-stack)
    run_stack "$TARGET"
    ;;
  stop-stack)
    echo "[FFactory] Stop stack not implemented yet for: ${TARGET}"
    ;;
  start-app)
    run_app "$TARGET"
    ;;
  stop-app)
    echo "[FFactory] Stop app not implemented yet for: ${TARGET}"
    ;;
  status)
    "${SCRIPTS_DIR}/ffactory_status.sh"
    ;;
  health)
    "${SCRIPTS_DIR}/../health/stack_health.sh"
    ;;
  shutdown-all)
    "${SCRIPTS_DIR}/ffactory_shutdown.sh"
    ;;
  *)
    usage
    ;;
esac
