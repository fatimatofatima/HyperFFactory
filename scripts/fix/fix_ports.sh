#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${ROOT_DIR}/config"

echo "[PORTS] Checking declared ports in apps.yaml and stacks (static list)."
echo

# من apps.yaml
echo "== Apps Ports =="
awk '/ports:/{flag=1;next}/description:/{flag=0}flag' "${CONFIG_DIR}/apps.yaml" | awk '/- ".*"/{print $2}' | tr -d '"' | sort -u | while read -r P; do
  [ -z "$P" ] && continue
  if ss -tulpn | grep -q ":${P} "; then
    echo "  - ${P}: BUSY"
  else
    echo "  - ${P}: FREE"
  fi
done

echo
echo "== Core Stack Known Ports =="
# قائمة ثابتة من docker-compose (يمكن تعديلها حسب الحاجة)
for P in 9200 5601 9091 3000 5439 8280; do
  if ss -tulpn | grep -q ":${P} "; then
    echo "  - ${P}: BUSY"
  else
    echo "  - ${P}: FREE"
  fi
done

echo
echo "[PORTS] No automatic changes performed. Use this التقرير لاتخاذ قرار يدوي."
