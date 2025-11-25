#!/usr/bin/env bash
# HyperFFactory – Seed interface-related tasks using hf_tasks_admin.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HF_TASKS_ADMIN="$SCRIPT_DIR/hf_tasks_admin.sh"

if [[ ! -x "$HF_TASKS_ADMIN" ]]; then
  echo "❌ hf_tasks_admin.sh غير موجود أو غير قابل للتنفيذ: $HF_TASKS_ADMIN" >&2
  exit 1
fi

"$HF_TASKS_ADMIN" create \
  "hyper_interfaces_manager" \
  "Design HyperFFactory Telegram interface" \
  "interfaces:telegram:design" \
  70 \
  "[interfaces,telegram,hyperfactory]"

"$HF_TASKS_ADMIN" create \
  "hyper_interfaces_manager" \
  "Design HyperFFactory Web interface (read-only dashboard)" \
  "interfaces:web:design" \
  70 \
  "[interfaces,web,hyperfactory]"

"$HF_TASKS_ADMIN" create \
  "hyper_interfaces_manager" \
  "Implement CLI→Web bridge using snapshot/dashboard scripts" \
  "interfaces:web:bridge" \
  65 \
  "[interfaces,web,bridge,hyperfactory]"

echo "✅ Seeded interface-related tasks via hf_tasks_admin.sh"
