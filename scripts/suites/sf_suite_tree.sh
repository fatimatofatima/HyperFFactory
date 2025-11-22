#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/opt/smartfriend-suite"
OUT="/root/sf_suite_tree_$(date +%Y%m%d_%H%M%S).log"

if [ ! -d "$ROOT" ]; then
  echo "Directory $ROOT not found."
  exit 1
fi

{
  echo "SmartFriend Suite Tree – $(date)"
  echo "Root: $ROOT"
  echo

  echo "=== du -sh (top level) ==="
  du -sh "$ROOT"/* 2>/dev/null | sort -h
  echo

  echo "=== subdirs (maxdepth 2) ==="
  find "$ROOT" -maxdepth 2 -type d | sort
  echo

  echo "=== python/bash entrypoints (top 3 levels) ==="
  find "$ROOT" -maxdepth 3 -type f \( -name '*.py' -o -name '*.sh' \) | head -n 200
} | tee "$OUT"

echo
echo "Tree report saved to: $OUT"
