#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE_DIR="/opt/smartfriend-suite"
REPORT_DIR="$BASE_DIR/reports"
mkdir -p "$REPORT_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
OUT="$REPORT_DIR/sf_suite_service_matrix_${TS}.yaml"

log(){ echo "[$(date '+%F %T')] $*"; }

classify_family() {
  local unit="$1"
  case "$unit" in
    sf-*)           echo "sf-suite" ;;
    smartfriend-*)  echo "smartfriend-suite" ;;
    smartfrind-*)   echo "smartfrind-legacy" ;;
    *)              echo "other" ;;
  esac
}

classify_category() {
  local unit="$1"
  case "$unit" in
    *bot*|*telegram*)                           echo "bots" ;;
    *core*|*api*|*gateway*|*unified*)           echo "api" ;;
    *memory*)                                   echo "memory" ;;
    *web*)                                      echo "web" ;;
    *spider*|*harvest*|*ingest*)                echo "spider" ;;
    *learn*|*learning*|*kb-*|*fts-*|*brain*)    echo "brain" ;;
    *health*|*guard*|*watchdog*|*monitor*|*smoke*)
                                                echo "health" ;;
    *backup*|*maintenance*|*download*|*keys-*|*db-*|*rotate*)
                                                echo "ops" ;;
    *)                                          echo "other" ;;
  esac
}

log "إعداد Matrix للخدمات – الإخراج في: $OUT"

{
  echo "# SmartFriend Suite – Service Matrix"
  echo "# Timestamp: $(date '+%F %T')"
  echo "# Hostname : $(hostname)"
  echo
  echo "services:"
} > "$OUT"

for prefix in sf- smartfriend- smartfrind-; do
  units="$(systemctl list-unit-files "${prefix}*" --no-legend 2>/dev/null | awk '{print $1" "$2}' || true)"

  [ -z "$units" ] && continue

  while read -r line; do
    [ -z "$line" ] && continue
    unit="$(printf '%s\n' "$line" | awk '{print $1}')"
    state="$(printf '%s\n' "$line" | awk '{print $2}')"

    family="$(classify_family "$unit")"
    category="$(classify_category "$unit")"

    active="$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")"
    substate="$(systemctl show "$unit" -p SubState --value 2>/dev/null || echo "unknown")"
    fragment="$(systemctl show "$unit" -p FragmentPath --value 2>/dev/null || echo "")"
    desc="$(systemctl show "$unit" -p Description --value 2>/dev/null || echo "")"

    {
      echo "  - unit: $unit"
      echo "    family: $family"
      echo "    category: $category"
      echo "    enabled_state: $state"
      echo "    active_state: $active"
      echo "    sub_state: $substate"
      echo "    fragment_path: $fragment"
      echo "    # description: $desc"
    } >> "$OUT"

  done <<< "$units"
done

log "تم إنشاء Matrix الخدمات:"
log "  $OUT"
