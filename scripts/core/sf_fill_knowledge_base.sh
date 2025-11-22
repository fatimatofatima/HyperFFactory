#!/usr/bin/env bash
set -Eeuo pipefail

GREEN='\033[0;32m'; NC='\033[0m'
ok(){ echo -e "${GREEN}[✓]${NC} $*"; }

echo "==========================================="
echo "   🧠 SmartFriend - Fill Knowledge Base (Phase B)"
echo "==========================================="
echo

# تشغيل script النقل
python3 /opt/smartfrind/tools/ai_memory_to_kb.py

echo
ok "✅ Phase B completed - Knowledge base filled"
echo "   Next: Run Phase C to test Net Learner"
