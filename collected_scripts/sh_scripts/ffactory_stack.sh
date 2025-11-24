#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

FF_ROOT="/opt/ffactory"
STACK_DIR="$FF_ROOT/stack"
COMPOSE_FILE=""

log(){ echo "[$(date +'%H:%M:%S')] $*"; }
err(){ echo "[ERR] $*" >&2; exit 1; }

if [ ! -d "$FF_ROOT" ]; then
  err "لم أجد $FF_ROOT - تأكد أن ffactory موجودة هناك."
fi

if [ -f "$STACK_DIR/docker-compose.complete.yml" ]; then
  COMPOSE_FILE="$STACK_DIR/docker-compose.complete.yml"
elif [ -f "$STACK_DIR/docker-compose.ultimate.yml" ]; then
  COMPOSE_FILE="$STACK_DIR/docker-compose.ultimate.yml"
elif [ -f "$STACK_DIR/docker-compose.core.yml" ]; then
  COMPOSE_FILE="$STACK_DIR/docker-compose.core.yml"
else
  err "لم أجد أي ملف docker-compose.* في $STACK_DIR"
fi

CMD="${1:-status}"
shift || true

case "$CMD" in
  doctor)
    cd "$FF_ROOT"
    if [ -x "$FF_ROOT/ff_doctor.sh" ]; then
      "$FF_ROOT/ff_doctor.sh" "$@"
    else
      err "لم أجد ff_doctor.sh أو أنه غير قابل للتنفيذ."
    fi
    ;;
  up)
    cd "$STACK_DIR"
    log "تشغيل ffactory stack (up -d) باستخدام $COMPOSE_FILE ..."
    docker compose -f "$COMPOSE_FILE" up -d "$@"
    ;;
  down)
    cd "$STACK_DIR"
    log "إيقاف ffactory stack (down)..."
    docker compose -f "$COMPOSE_FILE" down "$@"
    ;;
  restart)
    cd "$STACK_DIR"
    log "إعادة تشغيل ffactory stack ..."
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    ;;
  status)
    cd "$STACK_DIR"
    log "حالة حاويات ffactory:"
    docker compose -f "$COMPOSE_FILE" ps
    ;;
  logs)
    cd "$STACK_DIR"
    log "آخر اللوجات (tail=100):"
    docker compose -f "$COMPOSE_FILE" logs -f --tail=100 "$@"
    ;;
  *)
    cat <<USAGE
استعمال: ffactory_stack.sh [doctor|up|down|restart|status|logs] [args...]

أمثلة:
  ffactory_stack.sh doctor
  ffactory_stack.sh up
  ffactory_stack.sh down
  ffactory_stack.sh restart
  ffactory_stack.sh status
  ffactory_stack.sh logs
USAGE
    ;;
esac
