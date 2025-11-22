#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT=ffactory
BACKUP_DIR=/opt/ffactory/backups
DB_ENV=/opt/ffactory/stack/db.env

log(){ printf '[%(%F %T)T] %s\n' -1 "$*"; }

# اسماء الحاويات من لابيلات compose
DB_CONT=$(docker ps --filter "label=com.docker.compose.project=${PROJECT}" \
                    --filter "label=com.docker.compose.service=db" \
                    --format '{{.Names}}' | head -n1)
REDIS_CONT=$(docker ps --filter "label=com.docker.compose.project=${PROJECT}" \
                       --filter "label=com.docker.compose.service=redis" \
                       --format '{{.Names}}' | head -n1)

# بوتات تيليجرام
BOTS=(smartnext-bot myservtiydatatesr-bot)

# متغيرات DB (من الملف اللي حضرتك جهزته)
set -a; [ -f "$DB_ENV" ] && . "$DB_ENV"; set +a
: "${PGUSER:=${POSTGRES_USER:-forensic_user}}"
: "${PGPASSWORD:=${POSTGRES_PASSWORD:-forensic_pass}}"
: "${PGDB:=${POSTGRES_DB:-forensic_db}}"

mkdir -p "$BACKUP_DIR"

log "Health check: pg_isready"
docker exec -e PGPASSWORD="$PGPASSWORD" -i "$DB_CONT" \
  pg_isready -h 127.0.0.1 -U "$PGUSER" -d "$PGDB"

log "Backup: dumping $PGDB -> $BACKUP_DIR"
docker exec -e PGPASSWORD="$PGPASSWORD" -i "$DB_CONT" \
  pg_dump -U "$PGUSER" -d "$PGDB" --format=custom --no-owner --no-privileges \
  | gzip -c > "$BACKUP_DIR/${PGDB}-$(date +%F_%H%M%S).dump.gz"

log "DB CHECKPOINT"
docker exec -e PGPASSWORD="$PGPASSWORD" -i "$DB_CONT" \
  psql -U "$PGUSER" -d "$PGDB" -c "CHECKPOINT;"

log "Stopping bots gracefully"
for c in "${BOTS[@]}"; do docker stop --time 20 "$c" 2>/dev/null || true; done

log "Stopping core services"
docker stop --time 30 "$DB_CONT" "$REDIS_CONT" 2>/dev/null || true

log "Syncing disks"
sync

log "Rebooting host..."
/sbin/reboot
