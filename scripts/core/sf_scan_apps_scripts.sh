#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
OUT="/root/sf_scan_apps_scripts_${TS}.txt"

ROOTS=(
  "/opt"
  "/srv"
  "/root"
  "/var/www"
)

echo "=== SmartFriend Apps/Scripts Scan @ $(date) ===" | tee "$OUT"
echo "Roots: ${ROOTS[*]}" | tee -a "$OUT"
echo >> "$OUT"

scan_root() {
  local base="$1"

  if [[ ! -d "$base" ]]; then
    echo "[SKIP] $base (not a dir)" | tee -a "$OUT"
    echo >> "$OUT"
    return
  fi

  echo "=== Root: $base ===" | tee -a "$OUT"

  find "$base" \
    -maxdepth 8 \
    -type d \( -iname "app" -o -iname "apps" -o -iname "script" -o -iname "scripts" \) \
    2>/dev/null \
  | sort | tee -a "$OUT"

  echo >> "$OUT"
}

for base in "${ROOTS[@]}"; do
  scan_root "$base"
done

echo "=== DONE ===" | tee -a "$OUT"
echo "Report: $OUT" | tee -a "$OUT"
