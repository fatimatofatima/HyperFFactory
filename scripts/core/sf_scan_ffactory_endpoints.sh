#!/usr/bin/env bash
set -Eeuo pipefail

BASES=("http://127.0.0.1:8000" "http://127.0.0.1:8220")
PATHS=(
  "/"
  "/health"
  "/api/health"
  "/docs"
  "/redoc"
  "/openapi.json"
  "/ffactory"
  "/ffactory/"
  "/ui"
  "/board"
  "/dashboard"
  "/ff-board"
  "/web"
  "/app"
  "/frontend"
)

echo "=== Scan candidate endpoints for FFactory / Unified APIs ==="
for base in "${BASES[@]}"; do
  echo
  echo ">>> BASE = ${base}"
  for path in "${PATHS[@]}"; do
    url="${base}${path}"
    code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo '000')"
    printf "  [%3s] %s\n" "$code" "$path"
  done
done
