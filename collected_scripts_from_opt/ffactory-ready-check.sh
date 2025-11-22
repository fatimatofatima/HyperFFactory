#!/usr/bin/env bash
set -Eeuo pipefail

ok(){ printf '• %s ... OK\n' "$1"; }
fail(){ printf '• %s ... FAIL\n' "$1"; }

is_running(){ docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null | grep -qx 'running'; }

check_container(){
  local name="$1"; local label="$2"
  if is_running "$name"; then ok "$label"; else
    fail "$label"
    if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
      echo "  ↳ status: $(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo 'unknown')"
      echo "  ↳ last-logs:"
      docker logs --tail 80 "$name" 2>&1 | sed 's/^/    /'
    else
      echo "  ↳ container not found"
    fi
  fi
}

get_token(){
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$1" 2>/dev/null | sed -n 's/^BOT_TOKEN=//p'
}

check_container smartnext-bot "smartnext-bot Up"
check_container myservtiydatatesr-bot "myservtiydatatesr-bot Up"
check_container ffactory-db-1 "ffactory-db-1 Up"
check_container ffactory-redis-1 "ffactory-redis-1 Up"

for c in smartnext-bot myservtiydatatesr-bot; do
  T=$(get_token "$c" || true)
  [ -n "${T:-}" ] || continue
  if curl -fsS "https://api.telegram.org/bot${T}/getMe" | grep -q '"ok":true'; then
    ok "Telegram getMe ($c)"
  else
    fail "Telegram getMe ($c)"
  fi
done

if docker exec -e PGPASSWORD=forensic_pass -i ffactory-db-1 psql -U forensic_user -d forensic_db -c "SELECT 1;" >/dev/null 2>&1; then
  ok "DB ping"
else
  fail "DB ping"
fi

if iptables -S DOCKER-USER 2>/dev/null | grep -Eq -- '-d (149\.154\.160\.0/20|91\.108\.4\.0/22).*REJECT'; then
  fail "DOCKER-USER has Telegram blocks"
else
  ok "DOCKER-USER clean"
fi
