#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="/opt/smartfriend-suite"
VENV="${APP_ROOT}/venv"
SPIDER_DIR="${APP_ROOT}/apps/harvester/spider"
CONFIG="${SPIDER_DIR}/spider.config.json"

cd "${SPIDER_DIR}"

if [ -d "${VENV}" ]; then
  # لو فيه venv للسويت نستخدمه، وإلا نستعمل python3 النظامي
  source "${VENV}/bin/activate"
fi

export SPIDER_CONFIG="${CONFIG}"

exec python3 "${SPIDER_DIR}/spider_main.py"
