#!/usr/bin/env bash
set -Eeuo pipefail
OUT="/tmp/sf_audit_$(date +%Y%m%d_%H%M%S).log"
{
  echo "=== SmartFriend Readonly Audit ==="
  date
  echo "Ports:"; ss -ltnp | egrep ':8210|:8214|:8220|:8383' || true
  echo; echo "Health:"
  for p in 8214 8383 8220 8210; do echo "::$p"; curl -fsS "http://127.0.0.1:$p/health" 2>/dev/null || echo "down"; done
  echo; echo "DB:"
  DB="/opt/smartfriend-suite/data/smartfriend_unified.db"
  [ -f "$DB" ] && du -h "$DB" && sqlite3 "$DB" "PRAGMA integrity_check;"
  echo; echo "Bots (3):"
  systemctl is-active sf-smartfrind.service sf-smartfactory.service sf-audit-bot.service || true
  echo; echo "Recent errors:"
  journalctl -p 3 -n 30 --no-pager || true
} | tee "$OUT"
echo "📊 التقرير: $OUT"
