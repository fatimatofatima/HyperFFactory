#!/usr/bin/env bash
# HyperFFactory – Check Design Gaps
# فحص وجود المكوّنات (Lakehouse / Factories / Management DBs / Config / Bridges)
# استخدام:
#   bin/hf_check_design_gaps.sh              # يفترض /root/HyperFFactory
#   bin/hf_check_design_gaps.sh /path/root   # لو اختلف الجذر

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"

if [ ! -d "$ROOT" ]; then
  echo "❌ ROOT غير موجود: $ROOT"
  exit 1
fi

cd "$ROOT"

echo "=================================================="
echo "🧩 HyperFFactory – Design Components Check"
echo "ROOT: $ROOT"
echo "TIME: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="
printf "%-3s %-6s %-45s %-8s %s\n" "ID" "نوع" "المسار النسبي" "الحالة" "الوصف"
echo "--------------------------------------------------"

checks=(
  # 1) Lakehouse layers
  "DIR|data_lakehouse|Lakehouse root folder"
  "DIR|data_lakehouse/raw_zone|Lakehouse RAW zone"
  "DIR|data_lakehouse/cleansed_zone|Lakehouse CLEANSED zone"
  "DIR|data_lakehouse/semantic_zone|Lakehouse SEMANTIC zone"
  "DIR|data_lakehouse/serving_zone|Lakehouse SERVING zone"
  "FILE|config/lakehouse_manifest.yaml|Lakehouse manifest (routing بين الطبقات)"

  # 2) Factories on top of Lakehouse
  "DIR|factories|Factories root"
  "DIR|factories/model_factory|Model Factory"
  "DIR|factories/knowledge_factory|Knowledge Factory"
  "DIR|factories/quality_factory|Quality Factory"
  "FILE|config/factories_manifest.yaml|Factories manifest (وصف كل مصنع)"

  # 3) Knowledge / Patterns / Management DBs (meta layer)
  "FILE|db/meta/hf_knowledge.db|Knowledge DB (hyper knowledge)"
  "FILE|db/meta/hf_patterns.db|Patterns DB"
  "FILE|db/meta/hf_quality.db|Quality DB (KPIs)"
  "FILE|db/meta/hf_errors.db|Errors DB (incidents)"
  "FILE|db/meta/hf_learning.db|Learning DB (experience)"
  "FILE|db/meta/hf_tasks.db|Tasks DB (management)"
  "FILE|db/meta/hf_changes.db|Changes DB (events/timeline)"

  # 4) Agents / Orchestrator config
  "FILE|config/agents.yaml|Agents config (debug_expert / system_architect / coach / spider / ...)"
  "FILE|config/integration_ffactory.yaml|FFactory integration config"
  "FILE|config/integration_smartfriend.yaml|SmartFriend integration config"

  # 5) Bridges & reports scripts
  "FILE|bin/hf_quality_report.sh|Quality system report script"
  "FILE|bin/hf_patterns_report.sh|Patterns report script"
  "FILE|bin/hf_lakehouse_sync.sh|Lakehouse sync/refresh script"
  "FILE|bin/hf_spider_to_knowledge.sh|Bridge: knowledge_spider → Knowledge DB"
  "FILE|bin/hf_bridge_ffactory.sh|Bridge: HyperFFactory ↔ FFactory"
  "FILE|bin/hf_bridge_smartfriend.sh|Bridge: HyperFFactory ↔ SmartFriend Suite"

  # 6) Application backends using these layers
  "DIR|apps/backend_coach_api|Backend Coach API (training/skills)"
  "DIR|apps/legacy_bridge|Legacy bridge apps"
)

missing=0
present=0
id=1

for entry in "${checks[@]}"; do
  IFS='|' read -r kind path desc <<<"$entry"

  if [ "$kind" = "DIR" ]; then
    if [ -d "$path" ]; then
      status="OK"
      icon="✅"
      ((present++))
    else
      status="MISSING"
      icon="❌"
      ((missing++))
    fi
  else
    if [ -f "$path" ]; then
      status="OK"
      icon="✅"
      ((present++))
    else
      status="MISSING"
      icon="❌"
      ((missing++))
    fi
  fi

  printf "%-3s %-6s %-45s %-8s %s %s\n" "$id" "$kind" "$path" "$status" "$icon" "$desc"
  id=$((id+1))
done

echo "--------------------------------------------------"
echo "📊 SUMMARY:"
echo "   موجود   : $present عنصر"
echo "   مفقود   : $missing عنصر"
echo "=================================================="
