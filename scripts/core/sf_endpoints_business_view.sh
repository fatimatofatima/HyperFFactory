#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

PORTS=("80" "443" "8170" "8210" "8211" "8220" "8383" "8390")

describe_port() {
  local p="$1"
  case "$p" in
    80)   echo "Nginx HTTP proxy (Public Web / Suite UI)" ;;
    443)  echo "Nginx HTTPS proxy (Secure Web / Suite UI)" ;;
    8170) echo "Factory / ffactory gateway (internal APIs)" ;;
    8210) echo "SmartFriend / SmartFrind unified gateway (LLM API)" ;;
    8211) echo "SmartFrind local gateway (no-key localhost)" ;;
    8220) echo "SmartFriend API (official HTTP API for Suite)" ;;
    8383) echo "Health / metrics / internal dashboard" ;;
    8390) echo "Experimental / QA endpoints" ;;
    *)    echo "غير مصنّف" ;;
  esac
}

log "=== SmartFriend Suite – خريطة منافذ الـ API (Business View) ==="
echo

if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
  warn "لا يوجد ss أو netstat على النظام – لا يمكن فحص المنافذ."
  exit 1
fi

TMP="/tmp/sf_endpoints_$$.tmp"
trap 'rm -f "$TMP"' EXIT

if command -v ss >/dev/null 2>&1; then
  ss -ltnp > "$TMP"
else
  netstat -ltnp 2>/dev/null > "$TMP"
fi

printf "%-8s | %-45s | %-30s | %-40s\n" "PORT" "BIND" "PROCESS" "BUSINESS ROLE"
printf -- "--------+-----------------------------------------------+--------------------------------+------------------------------------------\n"

for p in "${PORTS[@]}"; do
  # ابحث عن السطر الخاص بالمنفذ
  line="$(grep -E ":${p} " "$TMP" || true)"
  if [ -z "$line" ]; then
    continue
  fi

  # استخراج bind / process بشكل تقريبي
  bind="$(echo "$line" | awk '{print $4}' | head -n1)"
  proc="$(echo "$line" | awk -F'"' '{print $2}' | head -n1)"
  [ -z "$proc" ] && proc="$(echo "$line" | awk '{print $NF}' | head -n1)"

  role="$(describe_port "$p")"

  printf "%-8s | %-45s | %-30s | %-40s\n" "$p" "$bind" "$proc" "$role"
done

echo
ok "تم توليد خريطة المنافذ. هذا السكربت للعرض فقط ولا يغيّر أي خدمة."
