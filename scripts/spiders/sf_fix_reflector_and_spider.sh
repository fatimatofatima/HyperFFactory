#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

CANON_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
TS="$(date +%Y%m%d_%H%M%S)"

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN] ${NC}$*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR] ${NC}$*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK] ${NC}$*"; }

ensure_state_table(){
  local db="$1"
  if [[ ! -f "$db" ]]; then
    warn "تخطي: لا يوجد ملف DB عند $db"
    return
  fi

  log "ضمان جدول state في: $db"
  sqlite3 "$db" <<'SQL'
PRAGMA foreign_keys=OFF;
BEGIN;
CREATE TABLE IF NOT EXISTS state (
    id INTEGER PRIMARY KEY,
    last_reflection_at TIMESTAMP,
    last_harvest_at    TIMESTAMP,
    last_ingest_at     TIMESTAMP,
    meta               JSON
);
INSERT INTO state (id, last_reflection_at, last_harvest_at, last_ingest_at, meta)
SELECT 1, NULL, NULL, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM state WHERE id=1);
COMMIT;
SQL
  success "تم ضمان جدول state في $db"
}

link_legacy_to_canon(){
  local legacy="$1"

  mkdir -p "$(dirname "$legacy")"

  # لو فيه ملف حقيقي (مش symlink) نعمل له backup
  if [[ -f "$legacy" && ! -L "$legacy" ]]; then
    local backup="${legacy}.bak_${TS}"
    warn "نقل نسخة قديمة من $legacy إلى $backup"
    mv "$legacy" "$backup"
  fi

  # إنشاء symlink للقاعدة الرسمية
  if [[ -L "$legacy" ]]; then
    log "الرابط موجود مسبقًا: $legacy -> $(readlink -f "$legacy")"
  else
    ln -s "$CANON_DB" "$legacy"
    success "ربط $legacy => $CANON_DB"
  fi
}

main(){
  log "=== [1] التحقق من القاعدة الرسمية ==="
  if [[ ! -f "$CANON_DB" ]]; then
    error "القاعدة الرسمية غير موجودة: $CANON_DB"
    exit 1
  fi
  ls -lh "$CANON_DB" || true

  log "=== [2] ضمان جدول state في قواعد smartfriend_unified.db المهمة ==="
  local DBS=(
    "$CANON_DB"
    "/opt/smartfriend-suite/data/db/smartfriend_unified.db"
    "/opt/smartfriend-suite/data/smartfriend_unified.db"
    "/root/smartfriend_unified.db"
  )

  for db in "${DBS[@]}"; do
    if [[ -f "$db" ]]; then
      ensure_state_table "$db"
    else
      warn "تخطي DB مفقودة: $db"
    fi
  done

  log "=== [3] ربط المسارات القديمة بالقاعدة الرسمية (symlinks) ==="
  link_legacy_to_canon "/opt/smartfriend-suite/data/db/smartfriend_unified.db"
  link_legacy_to_canon "/opt/smartfriend-suite/data/smartfriend_unified.db"

  log "=== [4] تهيئة smartfrind-reflector لاستخدام القاعدة الرسمية ==="
  local REF_DROPIN_DIR="/etc/systemd/system/smartfrind-reflector.service.d"
  mkdir -p "$REF_DROPIN_DIR"

  cat > "${REF_DROPIN_DIR}/40-db-path.conf" <<REFEOF
[Service]
Environment=SMARTFRIEND_DB=${CANON_DB}
Environment=SMARTFRIND_DB=${CANON_DB}
REFEOF

  success "تم كتابة ${REF_DROPIN_DIR}/40-db-path.conf"

  log "=== [5] إصلاح sf-spider.service (WorkingDirectory + DB + config) ==="
  local SPIDER_DROPIN_DIR="/etc/systemd/system/sf-spider.service.d"
  mkdir -p "$SPIDER_DROPIN_DIR"

  cat > "${SPIDER_DROPIN_DIR}/40-workingdir-and-env.conf" <<SPIDEREOF
[Service]
WorkingDirectory=/opt/smartfriend-suite/services/harvester/spider
Environment=SMARTFRIEND_DB=${CANON_DB}
Environment=SMARTFRIND_DB=${CANON_DB}
Environment=SPIDER_CONFIG=/opt/smartfriend-suite/ops/spider_config_complete.yaml
SPIDEREOF

  success "تم كتابة ${SPIDER_DROPIN_DIR}/40-workingdir-and-env.conf"

  log "=== [6] daemon-reload + إعادة تشغيل الخدمات ==="
  systemctl daemon-reload

  systemctl restart smartfrind-reflector.service || warn "تعذّر إعادة تشغيل smartfrind-reflector.service"
  systemctl restart sf-spider.service || warn "تعذّر إعادة تشغيل sf-spider.service"

  log "=== [7] snapshot سريع للحالة ==="
  systemctl status smartfrind-reflector.service --no-pager -l || true
  systemctl status sf-spider.service --no-pager -l || true

  success "اكتمل إصلاح reflector + spider وربط DB موحدة."
}

main "$@"
