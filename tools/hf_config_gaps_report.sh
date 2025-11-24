#!/usr/bin/env bash
# HyperFFactory – Config Gaps Report
# يغطي البنود:
# - config/agents.yaml
# - config/worker_orchestrator.yaml
# - config/modules.json
# - config/modules_enhanced.json
#
# قراءة فقط: لا يغيّر أي ملف، فقط يكتب تقرير في reports.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="${REPORT_DIR}/hf_config_gaps_${TS}.log"

CONFIGS=(
  "config/agents.yaml"
  "config/worker_orchestrator.yaml"
  "config/modules.json"
  "config/modules_enhanced.json"
)

{
  echo "====================================================="
  echo "[CONFIG-GAPS] HyperFFactory – Config Gaps Report"
  echo "ROOT : ${ROOT}"
  echo "TIME : ${TS}"
  echo "LOG  : ${LOG}"
  echo "====================================================="
  echo

  git_status_ok=true
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_status_ok=false
    echo "[WARN] هذا المشروع ليس داخل git (أو git غير مهيأ) – سأتجاهل حالة التتبع."
    echo
  fi

  printf "%-35s | %-7s | %-8s | %-10s | %s\n" "PATH" "EXISTS" "TRACKED" "SIZE(bytes)" "NOTE"
  printf -- "-----------------------------------------------------------------------------------------------\n"

  for cfg in "${CONFIGS[@]}"; do
    exists="NO"
    tracked="N/A"
    size="0"
    note=""

    if [[ -f "$cfg" ]]; then
      exists="YES"
      size=$(stat -c '%s' "$cfg" 2>/dev/null || echo "0")
      note="config-present"

      if $git_status_ok; then
        if git ls-files --error-unmatch "$cfg" >/dev/null 2>&1; then
          tracked="YES"
        else
          tracked="NO"
          note+="; UNTRACKED-in-git"
        fi
      fi
    else
      exists="NO"
      tracked=$($git_status_ok && echo "NO" || echo "N/A")
      note="missing"
    fi

    printf "%-35s | %-7s | %-8s | %-10s | %s\n" "$cfg" "$exists" "$tracked" "$size" "$note"
  done

  echo
  echo "-----------------------------------------------------"
  echo "[HINT] البنود التي ظهرت note فيها = UNTRACKED-in-git هي ما أشار له تقرير hf_check_plan_and_architecture."
  echo "       هذا السكربت لا يضيف ولا يحذف ولا يعدّل أي ملف؛ فقط تقرير."
  echo "-----------------------------------------------------"
} | tee "$LOG"

echo
echo "[CONFIG-GAPS] Report saved to: $LOG"
