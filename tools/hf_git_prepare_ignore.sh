#!/usr/bin/env bash
# HyperFFactory – prepare .gitignore for runtime data (no file deletion)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

BLOCK_START="# >>> HyperFFactory runtime ignore (auto) >>>"
BLOCK_END="# <<< HyperFFactory runtime ignore (auto) <<<"

if [ -f .gitignore ] && grep -q "$BLOCK_START" .gitignore; then
    echo "[hf_git_prepare_ignore] runtime ignore block already present."
    exit 0
fi

echo "[hf_git_prepare_ignore] appending runtime ignore block to .gitignore"

cat >> .gitignore <<'BLOCKEOF'
# >>> HyperFFactory runtime ignore (auto) >>>
# runtime databases and data
db/
data/
reports/
imported/
snapshot/
var/

# external stacks / imported suites (keep only orchestration code here)
opt/

# local heavy / generated files
hf_backups_report_*.txt
db_inventory_*.tsv

# generic logs and sqlite/db files
*.log
*.db
*.sqlite
# <<< HyperFFactory runtime ignore (auto) <<<
BLOCKEOF

echo "[hf_git_prepare_ignore] done."
