#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/root/HyperFFactory"
REPORT_DIR="${BASE_DIR}/reports/scripts_index"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="${REPORT_DIR}/scripts_index_${TS}.txt"

mkdir -p "${REPORT_DIR}"

echo "[*] Project base: ${BASE_DIR}"
echo "[*] Report file : ${REPORT_FILE}"
echo "====================================" > "${REPORT_FILE}"
echo "HyperFFactory Scripts Index - ${TS}" >> "${REPORT_FILE}"
echo "BASE_DIR = ${BASE_DIR}" >> "${REPORT_FILE}"
echo "====================================" >> "${REPORT_FILE}"
echo >> "${REPORT_FILE}"

# تصنيف السكربتات حسب النوع
echo "=== 1) Bash scripts (*.sh) ================================" >> "${REPORT_FILE}"
find "${BASE_DIR}" -type f -name '*.sh' ! -path '*/.git/*' \
  | sort \
  | nl -ba >> "${REPORT_FILE}"
echo >> "${REPORT_FILE}"

echo "=== 2) Python scripts (*.py) ==============================" >> "${REPORT_FILE}"
find "${BASE_DIR}" -type f -name '*.py' ! -path '*/.git/*' \
  | sort \
  | nl -ba >> "${REPORT_FILE}"
echo >> "${REPORT_FILE}"

echo "=== 3) Systemd units (*.service) ==========================" >> "${REPORT_FILE}"
find "${BASE_DIR}" -type f -name '*.service' ! -path '*/.git/*' \
  | sort \
  | nl -ba >> "${REPORT_FILE}"
echo >> "${REPORT_FILE}"

echo "=== 4) Docker / Compose (docker-compose*.yml / *.yaml) ===" >> "${REPORT_FILE}"
find "${BASE_DIR}" -type f \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \) ! -path '*/.git/*' \
  | sort \
  | nl -ba >> "${REPORT_FILE}"
echo >> "${REPORT_FILE}"

echo "=== 5) Other exec scripts (no extension, +x) =============" >> "${REPORT_FILE}"
find "${BASE_DIR}" -type f -perm -u+x ! -path '*/.git/*' \
  ! -name '*.sh' ! -name '*.py' ! -name '*.service' \
  ! -name 'docker-compose*.yml' ! -name 'docker-compose*.yaml' \
  | sort \
  | nl -ba >> "${REPORT_FILE}"
echo >> "${REPORT_FILE}"

echo "[*] Index written to: ${REPORT_FILE}"
