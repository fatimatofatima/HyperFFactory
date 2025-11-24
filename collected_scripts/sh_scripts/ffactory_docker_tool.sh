#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# تحميل environment variables
set -a
[ -f "/opt/ffactory/.env.docker" ] && source "/opt/ffactory/.env.docker"
set +a

if [ $# -lt 1 ]; then
  echo "Usage: $0 {up|down|restart|ps|logs|logs-once|pull|doctor}"
  exit 1
fi

CMD="$1"
STACK_DIR="/opt/ffactory/stack"
COMPOSE_FILE="$STACK_DIR/docker-compose.core.yml"

if ! have docker; then
  error "docker غير مثبت"
  exit 1
fi

cd "$STACK_DIR"

case "$CMD" in
  up)
    log "تشغيل FFactory stack (up -d)..."
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  down)
    log "إيقاف FFactory stack..."
    docker compose -f "$COMPOSE_FILE" down
    ;;
  restart)
    log "إعادة تشغيل FFactory stack..."
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  ps)
    log "عرض حالة الحاويات"
    docker compose -f "$COMPOSE_FILE" ps
    ;;
  logs)
    log "متابعة اللوجات (live)..."
    docker compose -f "$COMPOSE_FILE" logs -f
    ;;
  logs-once)
    log "عرض آخر 100 سطر من اللوج"
    docker compose -f "$COMPOSE_FILE" logs --tail=100
    ;;
  pull)
    log "سحب أحدث الصور..."
    docker compose -f "$COMPOSE_FILE" pull
    ;;
  doctor)
    log "فحص صحة FFactory stack..."
    echo "=== Environment Variables ==="
    env | grep -E "(PG_|PORT|TZ)" | sort
    echo
    echo "=== Docker Status ==="
    docker ps --filter "name=ffactory" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    echo "=== Volumes ==="
    docker volume ls | grep ffactory
    ;;
  *)
    error "أمر غير معروف: $CMD"
    echo "استخدام: $0 {up|down|restart|ps|logs|logs-once|pull|doctor}"
    exit 1
    ;;
esac
