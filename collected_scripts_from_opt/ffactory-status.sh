#!/usr/bin/env bash
set -Eeuo pipefail
cstat(){ local c="$1"; printf '• %-22s ... ' "$c"; 
  if ! docker inspect "$c" >/dev/null 2>&1; then echo "MISSING"; return; fi
  local run=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || echo false)
  local hth=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$c" 2>/dev/null || echo n/a)
  if [[ "$run" == "true" ]]; then echo "RUNNING (health=$hth)"; else echo "STOPPED (health=$hth)"; fi
}
for c in ffactory-db-1 ffactory-redis-1 metabase smartnext-bot myservtiydatatesr-bot; do cstat "$c"; done
