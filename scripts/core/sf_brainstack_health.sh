#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y-%m-%d %H:%M:%S')"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

check_endpoint() {
  local name="$1"
  local url="$2"

  if ! command -v curl >/dev/null 2>&1; then
    log "ERROR: curl غير مثبت. ثبّت الحزمة curl أولاً."
    exit 1
  fi

  log "🔎 فحص الخدمة: ${name} → ${url}"
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo "000")"

  if [ "$code" = "200" ]; then
    log "✅ ${name}: UP (HTTP $code)"
  else
    log "❌ ${name}: DOWN أو غير مستقر (HTTP $code)"
  fi
  echo
}

echo "==============================================="
echo "[${TS}] SmartFriend Brain + FFactory Health Check"
echo "==============================================="
echo

# SmartFriend Health Gate
check_endpoint "sf-health (Health Gate)" "http://127.0.0.1:8210/health"

# Memory API
check_endpoint "sf-memory (Memory API)" "http://127.0.0.1:8214/health"

# Unified API Gateway
check_endpoint "sf-unified (Unified API)" "http://127.0.0.1:8220/health"

# FFactory Healthd (لو endpoint مختلف نعدّله لاحقًا)
check_endpoint "ff-healthd (FFactory Healthd)" "http://127.0.0.1:9191/health"

echo "==============================================="
echo "الفحص انتهى."
echo "==============================================="
