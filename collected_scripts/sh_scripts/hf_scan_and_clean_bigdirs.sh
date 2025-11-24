#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="/root/hf_reports"
mkdir -p "$REPORT_DIR"

echo "=== [1] Scan: biggest dirs/files under /root ==="

# تقرير عام عن /root (عمق 3)
du -x -h --max-depth=3 /root | sort -h > "$REPORT_DIR/root_du_max3.txt"

# تركيز على hyper-factory* (عمق 2)
du -x -h --max-depth=2 /root/hyper-factory* 2>/dev/null | sort -h > "$REPORT_DIR/hyper_factories_du.txt"

# أكبر ملفات (>500M)
find /root -xdev -type f -size +500M -printf '%s %p\n' | sort -n > "$REPORT_DIR/bigfiles_over500M.txt"

# أكبر مجلدات (>2G)
du -x -BG --max-depth=6 /root | awk '$1+0 >= 2 {print}' | sort -n > "$REPORT_DIR/bigdirs_over2G.txt"

echo "Scan reports written to: $REPORT_DIR"
ls -1 "$REPORT_DIR" || true

echo
echo "=== [2] Target: backup venvs inside COMPLETE_CODE_BACKUP (code libs, NOT business data) ==="

TARGET_DIRS=(
  "/root/hyper-factory-merged/imported/backups/COMPLETE_CODE_BACKUP/opt/smartfrind/venv"
  "/root/hyper-factory-merged/imported/backups/COMPLETE_CODE_BACKUP/opt/smartfriend-suite/venv"
  "/root/hyper-factory-merged/imported/backups/COMPLETE_CODE_BACKUP/opt/smartfriend-suite/bots/venv"
  "/root/hyper-factory-merged/imported/backups/COMPLETE_CODE_BACKUP/opt/deepseek/venv"
)

for d in "\${TARGET_DIRS[@]}"; do
  if [ -d "\$d" ]; then
    echo "--- Found: \$d"
    du -sh "\$d" || true
  else
    echo ">>> Not found (already clean?): \$d"
  fi
done

echo
echo ">>> Deleting ONLY these backup venv folders (no live projects, no DBs)..."

for d in "\${TARGET_DIRS[@]}"; do
  if [ -d "\$d" ]; then
    echo "rm -rf \$d"
    rm -rf "\$d"
  fi
done

echo
echo "=== [3] Disk usage after cleanup ==="
df -h /
