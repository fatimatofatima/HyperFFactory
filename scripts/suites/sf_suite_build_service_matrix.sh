#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

LOG_TAG="[SF-MATRIX]"
OUT_DIR="/opt/smartfriend-suite/reports"
mkdir -p "$OUT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
MATRIX_FILE="$OUT_DIR/sf_suite_service_matrix_${TS}.tsv"

echo "${LOG_TAG} Building service matrix into: $MATRIX_FILE"

# حفظ خريطة البورتات الحالية
TMP_SS="$(mktemp /tmp/sf_ss_XXXXXX)"
ss -tulpn 2>/dev/null | tr -s ' ' > "$TMP_SS" || true

# ترويسة الملف
{
  echo -e "family\tunit\tkind\trole\tactive_state\tsub_state\tmain_pid\tports\tfragment_path"
} > "$MATRIX_FILE"

# جمع كل الـ units المستهدفة
mapfile -t UNITS < <(
  systemctl list-units 'sf-*.service' 'sf-*.timer' 'smartfrind-*.service' 'smartfrind-*.timer' \
    --all --no-legend --no-pager 2>/dev/null \
  | awk '{print $1}' \
  | sort -u
)

detect_family() {
  local u="$1"
  if [[ "$u" == sf-* ]]; then
    echo "suite"
  elif [[ "$u" == smartfrind-* ]]; then
    echo "legacy"
  else
    echo "other"
  fi
}

detect_kind() {
  local u="$1"
  if [[ "$u" == *.timer ]]; then
    echo "timer"
  else
    echo "service"
  fi
}

detect_role() {
  local u="$1"
  local lu="${u,,}"

  if [[ "$lu" == *"bot"* || "$lu" == *"telegram"* || "$lu" == *"smartfactory"* ]]; then
    echo "bot"
  elif [[ "$lu" == *"web"* ]]; then
    echo "web"
  elif [[ "$lu" == *"memory"* ]]; then
    echo "memory"
  elif [[ "$lu" == *"spider"* || "$lu" == *"harvest"* || "$lu" == *"ingest"* || "$lu" == *"cma"* ]]; then
    echo "spider/ingest"
  elif [[ "$lu" == *"health"* || "$lu" == *"watchdog"* || "$lu" == *"guard"* || "$lu" == *"guardian"* || "$lu" == *"monitor"* ]]; then
    echo "health/guard"
  elif [[ "$lu" == *"gateway"* || "$lu" == *"api"* || "$lu" == *"unified"* || "$lu" == *"core"* ]]; then
    echo "api/core"
  else
    echo "other"
  fi
}

get_ports_for_pid() {
  local pid="$1"
  local ports

  if [[ -z "$pid" || "$pid" == "0" ]]; then
    echo "-"
    return 0
  fi

  ports="$(
    awk -v pid="pid=${pid}" '
      $0 ~ pid {
        # الحقل الخامس عادةً فيه local_address:port
        gsub(/^[ \t]+/, "", $5);
        print $5
      }
    ' "$TMP_SS" 2>/dev/null | sort -u | paste -sd ',' -
  )"

  if [[ -z "$ports" ]]; then
    echo "-"
  else
    echo "$ports"
  fi
}

for unit in "${UNITS[@]}"; do
  family="$(detect_family "$unit")"
  kind="$(detect_kind "$unit")"
  role="$(detect_role "$unit")"

  active_state="$(systemctl show -p ActiveState --value "$unit" 2>/dev/null || echo "unknown")"
  sub_state="$(systemctl show -p SubState --value "$unit" 2>/dev/null || echo "unknown")"
  main_pid="$(systemctl show -p MainPID --value "$unit" 2>/dev/null || echo "0")"
  fragment_path="$(systemctl show -p FragmentPath --value "$unit" 2>/dev/null || echo "-")"

  ports="$(get_ports_for_pid "$main_pid")"

  echo -e "${family}\t${unit}\t${kind}\t${role}\t${active_state}\t${sub_state}\t${main_pid}\t${ports}\t${fragment_path}" \
    >> "$MATRIX_FILE"
done

rm -f "$TMP_SS" || true

echo "${LOG_TAG} DONE. Matrix written to: $MATRIX_FILE"
