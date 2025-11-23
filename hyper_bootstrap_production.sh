#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"   # run (افتراضي) | check
BASE="/root/HyperFFactory"
VENV_DIR="${BASE}/.venv"
REQ_FILE="${BASE}/requirements.txt"

echo "====================================="
echo " 🚀 HyperFFactory - Production Bootstrap"
echo "====================================="
echo "📅 $(date)"
echo "🖥️  $(hostname)"
echo "📁 BASE = ${BASE}"
echo "🎯 MODE = ${MODE}"
echo

cd "${BASE}"

echo "---- [1] 📦 تجهيز requirements.txt ----"
if [[ -f "${REQ_FILE}" ]]; then
  BACKUP="${REQ_FILE}.$(date +%Y%m%d_%H%M%S).bak"
  cp "${REQ_FILE}" "${BACKUP}"
  echo "✅ Backup: ${BACKUP}"
else
  echo "❌ requirements.txt غير موجود في ${REQ_FILE}"
  exit 1
fi
echo "✅ requirements.txt جاهز"
echo

echo "---- [2] 🐍 إعداد venv ----"
if [[ ! -d "${VENV_DIR}" ]]; then
  echo "🔧 إنشاء venv جديد في ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

# تفعيل venv
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

echo "✅ venv موجود مسبقاً: ${VENV_DIR}"
echo "🔓 venv مفعل: $(which python)"
pip --version || true
echo

if [[ "${MODE}" == "check" ]]; then
  echo "🔍 وضع CHECK فقط - لن نثبّت حزم."
  exit 0
fi

echo "---- [3] ⚡ تثبيت الحزم ----"
echo "🔧 Core stack (FastAPI + DB)..."
pip install \
  "fastapi==0.104.1" \
  "uvicorn==0.24.0" \
  "pydantic==2.5.0" \
  "sqlalchemy==2.0.23" \
  "aiofiles==23.2.1" \
  "python-dotenv==1.0.0" \
  "anyio>=3.7.1,<4.0.0" \
  "starlette==0.27.0" \
  "typing-extensions==4.8.0" \
  --upgrade

echo "🔧 حزم AI الأساسية..."
pip install \
  "numpy==1.24.3" \
  "torch==2.1.0" \
  "transformers==4.35.2" \
  --upgrade

echo "🔧 باقي المتطلبات من requirements.txt..."
if ! pip install -r "${REQ_FILE}"; then
  echo "⚠️ بعض الحزم فشلت، لكن الكور غالباً شغّال."
fi

echo "📊 عدد الحزم المثبتة: $(pip list | wc -l)"
echo

echo "---- [4] 🐳 Docker Stack (stack/core) ----"
if command -v docker &>/dev/null; then
  if [[ -f "${BASE}/stack/core/docker-compose.core.yml" ]]; then
    echo "🚀 docker compose up -d ..."
    docker compose -f "${BASE}/stack/core/docker-compose.core.yml" up -d
    echo "📊 حالة الخدمات:"
    docker compose -f "${BASE}/stack/core/docker-compose.core.yml" ps
  else
    echo "⚠️ ملف stack/core/docker-compose.core.yml غير موجود."
  fi
else
  echo "⚠️ docker غير مثبت أو غير متاح في PATH."
fi
echo

echo "---- [5] 📊 التقرير النهائي ----"
echo "💾 المساحة:"
df -h / | awk 'NR==1 || NR==2'
echo
echo "🧠 الذاكرة:"
free -h
echo
echo "✅ HyperFFactory bootstrap اكتمل (MODE=${MODE})"
