#!/usr/bin/env bash
set -Eeuo pipefail

sec() {
  echo
  echo "============================================================"
  echo ">>> $1"
  echo "============================================================"
}

ROOT_OPT="/opt"
SUITE_DIR="/opt/smartfriend-suite"

sec "System info"
echo "Host:   $(hostname)"
echo "Date:   $(date)"
echo
echo "Uptime:"
uptime || true
echo
echo "Disk /:"
df -h / || true
echo
echo "Memory:"
free -h || true

sec "/opt relevant project directories"
ls -d \
  /opt/smartfriend-suite \
  /opt/smartfrind \
  /opt/SmartFriend \
  /opt/smartfrind_unified \
  /opt/SmartFrind_Miracle \
  /opt/ffactory \
  2>/dev/null || echo "No smart* or ffactory dirs found (by these names)."

echo
echo "--- sizes (du -sh) ---"
du -sh \
  /opt/smartfriend-suite \
  /opt/smartfrind \
  /opt/SmartFriend \
  /opt/smartfrind_unified \
  /opt/SmartFrind_Miracle \
  /opt/ffactory \
  2>/dev/null || true

sec "Systemd services (smart*/ffactory)"
systemctl list-units --type=service | \
  egrep -i 'smartfrind|smartfriend|SmartFrind|ffactory' || \
  echo "No matching systemd services found."

sec "Docker: running containers (filtered)"
if command -v docker >/dev/null 2>&1; then
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | \
    egrep -i 'smart|friend|ffactory|ollama|asr' || \
    echo "No matching containers running (smart*/ffactory/ollama/asr)."
else
  echo "docker not found."
fi

sec "Docker compose files under smartfriend-suite"
if [ -d "$SUITE_DIR" ]; then
  find "$SUITE_DIR" -maxdepth 4 -type f \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) 2>/dev/null | sort || true
else
  echo "$SUITE_DIR does not exist."
fi

# نجرب تشغيل docker compose ps لكل ملف نلقاه
if command -v docker >/dev/null 2>&1; then
  mapfile -t COMPOSE_FILES < <(
    find "$SUITE_DIR" -maxdepth 4 -type f \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) 2>/dev/null | sort
  ) || true

  if [ "${#COMPOSE_FILES[@]}" -gt 0 ]; then
    for f in "${COMPOSE_FILES[@]}"; do
      sec "docker compose ps for: $f"
      if docker compose -f "$f" ps 2>/dev/null; then
        :
      elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose -f "$f" ps || echo "docker-compose ps failed for $f"
      else
        echo "Neither 'docker compose' nor 'docker-compose' worked for $f"
      fi
    done
  else
    sec "No docker-compose files found under $SUITE_DIR"
  fi
else
  echo
  echo "docker not installed; skipping compose checks."
fi

sec "Docker logs (last 50 lines) for smart*/ffactory containers"
if command -v docker >/dev/null 2>&1; then
  mapfile -t C_NAMES < <(docker ps --format '{{.Names}}' | egrep -i 'smart|friend|ffactory' || true)
  if [ "${#C_NAMES[@]}" -eq 0 ]; then
    echo "No running containers matching smart*/ffactory."
  else
    for c in "${C_NAMES[@]}"; do
      echo
      echo "----- $c : last 50 log lines -----"
      docker logs --tail=50 "$c" 2>&1 || echo "Failed to read logs for $c"
    done
  fi
else
  echo "docker not found; skipping logs."
fi

echo
echo "===================== END OF REPORT ========================="
