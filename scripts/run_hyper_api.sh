#!/usr/bin/env bash
set -euo pipefail

BASE="/root/HyperFFactory"
VENV_DIR="${BASE}/.venv"
APP_MODULE="hyper_factory.api.main:app"
HOST="0.0.0.0"
PORT="8310"   # منفذ HyperFFactory Core API

echo "====================================="
echo " HyperFFactory Core API - Run Script"
echo "====================================="
echo "📅 $(date)"
echo "📁 BASE = ${BASE}"
echo "🐍 VENV = ${VENV_DIR}"
echo "🛰  APP  = ${APP_MODULE}"
echo "🔌 PORT = ${PORT}"
echo

cd "${BASE}"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "❌ venv غير موجود في ${VENV_DIR}"
  exit 1
fi

# تفعيل venv
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

# تضمين src في PYTHONPATH حتى يتعرف Python على hyper_factory
export PYTHONPATH="${BASE}/src:${PYTHONPATH:-}"

exec uvicorn "${APP_MODULE}" --host "${HOST}" --port "${PORT}"
