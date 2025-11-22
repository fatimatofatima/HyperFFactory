#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="${ROOT_DIR}/reports"
NOW=$(date +"%Y%m%d_%H%M%S")
OUT="${REPORT_DIR}/full_snapshot_${NOW}.txt"

mkdir -p "${REPORT_DIR}"

{
  echo "HyperFFactory Full Snapshot - ${NOW}"
  echo "===================================="
  echo
  echo "## System"
  echo "### uptime"
  uptime
  echo
  echo "### df -h"
  df -h
  echo
  echo "### free -h"
  free -h || true
  echo
  echo "### docker ps"
  docker ps || true
  echo
  echo "## Stack Health"
} > "$OUT"

# stack health
if [[ -x "${ROOT_DIR}/scripts/health/stack_health.sh" ]]; then
  "${ROOT_DIR}/scripts/health/stack_health.sh" >> "$OUT" 2>&1 || true
fi

# apps health
if [[ -x "${ROOT_DIR}/scripts/health/app_health.sh" ]]; then
  "${ROOT_DIR}/scripts/health/app_health.sh" >> "$OUT" 2>&1 || true
fi

echo "Snapshot written to: $OUT"
