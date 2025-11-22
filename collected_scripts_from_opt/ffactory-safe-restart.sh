#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT=ffactory
COMPOSE=/opt/ffactory/stack/docker-compose.all.yml
DB_ENV=/opt/ffactory/stack/db.env
BACKUP_DIR=/opt/ffactory/backups/db
mkdir -p "$BACKUP_DIR"

log(){ printf '[%(%F %T)T] %s\n' -1 "$*"; }

# حمّل متغيرات DB
set -a; [ -f "$DB_ENV" ] && . "$DB_ENV"; set +a
PGUSER="${PGUSER:-${POSTGRES_USER:-forensic_user}}"
PGPASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:-forensic_pass}}"
PGDB="${PGDB:-${POSTGRES_DB:-forensic_db}}"

# اسم حاوية الـ DB من لابيلات compose
DB_CONT=$(docker ps --filter "label=com.docker.compose.project=${PROJECT}" \
                    --filter "label=com.docker.compose.service=db" \
                    --format '{{.Names}}' | head -n1)

backup_db(){
  local ts=$(date +%F_%H%M%S)
  local out="${BACKUP_DIR}/pg_${PGDB}_${ts}.sql.gz"
  log "DB backup -> $out"
  docker exec -e PGPASSWORD="$PGPASSWORD" "$DB_CONT" \
    bash -lc "pg_dump -U '$PGUSER' -d '$PGDB' | gzip -9" > "$out"
  [ -s "$out" ] || { log "Backup failed (empty file)"; rm -f "$out"; exit 1; }
  # احتفظ بآخر 14 نسخة
  ls -1t "$BACKUP_DIR"/pg_${PGDB}_*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm -f
  log "Backup done."
}

stop_bots(){
  log "Stopping bots gracefully"
  docker stop -t 20 smartnext-bot myservtiydatatesr-bot >/dev/null 2>&1 || true
}

compose_cycle(){
  log "Compose down"
  docker compose -p "$PROJECT" -f "$COMPOSE" down
  log "Compose up -d"
  docker compose -p "$PROJECT" -f "$COMPOSE" up -d
}

ready_check(){
  log "Running ready-check"
  /usr/local/sbin/ffactory-status.sh || true
}

case "${1:-}" in
  --reboot)
    backup_db
    stop_bots
    compose_cycle
    ready_check
    log "Rebooting system"
    reboot
    ;;
  ""|--restart)
    backup_db
    stop_bots
    compose_cycle
    ready_check
    log "Safe restart completed."
    ;;
  --down)
    stop_bots
    docker compose -p "$PROJECT" -f "$COMPOSE" down
    log "Stopped."
    ;;
  --up)
    docker compose -p "$PROJECT" -f "$COMPOSE" up -d
    ready_check
    ;;
  *)
    echo "Usage: $(basename "$0") [--restart|--reboot|--down|--up]"; exit 1
    ;;
esac
