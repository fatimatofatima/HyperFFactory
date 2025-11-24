#!/usr/bin/env bash
set -euo pipefail

echo "=== Phase 2 cleanup: hyper-factory backups (SAFE) ==="

ARCHIVE_DIR="/root/hyper-factory-archives"
mkdir -p "$ARCHIVE_DIR"

CANDIDATES=(
  "/root/hyper-factory-backup-20251121_025349"
  "/root/hyper-factory-backup-20251121_092733"
  "/root/hyper-factory-backup-20251121_092759"
)

for d in "${CANDIDATES[@]}"; do
  if [ -d "$d" ]; then
    base="$(basename "$d")"
    tar_path="$ARCHIVE_DIR/${base}.tar.zst"

    echo "--- Archiving $d -> $tar_path"
    if [ ! -f "$tar_path" ]; then
      tar -I 'zstd -3' -cpf "$tar_path" -C /root "$base"
    else
      echo ">>> Archive already exists: $tar_path (skipping create)"
    fi

    echo "--- Removing original directory $d"
    rm -rf "$d"
  else
    echo ">>> Skip (not found): $d"
  fi
done

echo "=== Done. Disk usage now: ==="
df -h /
