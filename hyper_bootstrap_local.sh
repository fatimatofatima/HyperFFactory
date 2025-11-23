#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-check}"   # check (default) | run

BASE="/root/HyperFFactory"
VENV_DIR="${BASE}/.venv"
CORE_COMPOSE="${BASE}/stack/core/docker-compose.core.yml"

echo "====================================="
echo " HyperFFactory - Local Bootstrap"
echo "====================================="
echo "Timestamp : $(date)"
echo "Hostname  : $(hostname)"
echo "Base Path : ${BASE}"
echo "Mode      : ${MODE}"
echo

# 0) التحقق من المجلد الأساسي
if [ ! -d "${BASE}" ]; then
  echo "❌ المجلد ${BASE} غير موجود"
  exit 1
fi

cd "${BASE}"

# 1) فحص Git مختصر
echo "---- [1] Git status (مختصر) ----"
if command -v git >/dev/null 2>&1; then
  git remote -v || echo "⚠️ لا يمكن قراءة remotes"
  git status --short --branch || echo "⚠️ git status فشل"
else
  echo "⚠️ git غير مثبت في PATH"
fi
echo

# 2) فحص المتطلبات الأساسية (python3, docker)
echo "---- [2] Prerequisites ----"
if command -v python3 >/dev/null 2>&1; then
  echo -n "python3: "
  python3 -V
else
  echo "⚠️ python3 غير موجود"
fi

if command -v docker >/dev/null 2>&1; then
  echo -n "docker : "
  docker --version || echo "⚠️ تعذر قراءة نسخة docker"
else
  echo "⚠️ docker غير موجود"
fi
echo

# 3) ملخص بسيط عن هيكل المجلدات الرئيسية
echo "---- [3] Top-level layout ----"
ls -1
echo

# 4) ملخص قواعد البيانات داخل HyperFFactory
echo "---- [4] DB layout (db/ , var/db) ----"
if [ -d "db" ]; then
  echo "db/:"
  find db -maxdepth 2 -type d | sed 's/^/  /'
else
  echo "ℹ️ لا يوجد مجلد db/"
fi
echo

if [ -d "var/db" ]; then
  echo "var/db/:"
  find var/db -maxdepth 2 -type d | sed 's/^/  /'
else
  echo "ℹ️ لا يوجد مجلد var/db/"
fi
echo

# 5) إعداد بيئة Python (في وضع run فقط)
if [ "${MODE}" = "run" ]; then
  echo "---- [5] Python venv & requirements ----"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "❌ لا يمكن إنشاء venv بدون python3"
  else
    if [ ! -d "${VENV_DIR}" ]; then
      echo "📦 إنشاء venv في ${VENV_DIR} ..."
      python3 -m venv "${VENV_DIR}"
    else
      echo "ℹ️ venv موجود مسبقًا في ${VENV_DIR}"
    fi

    # تفعيل البيئة
    # shellcheck disable=SC1090
    source "${VENV_DIR}/bin/activate"

    echo "📦 تحديث pip داخل venv..."
    pip install -U pip setuptools wheel >/dev/null 2>&1 || echo "⚠️ تعذر تحديث pip بالكامل"

    if [ -f "requirements.txt" ]; then
      echo "📦 تثبيت requirements.txt (قد يأخذ بعض الوقت)..."
      pip install -r requirements.txt || echo "⚠️ فشل بعض الحزم في requirements.txt"
    else
      echo "ℹ️ لا يوجد requirements.txt في الجذر"
    fi

    deactivate || true
  fi
  echo
fi

# 6) فحص / تشغيل Docker core stack
echo "---- [6] Docker core stack ----"
if [ -f "${CORE_COMPOSE}" ]; then
  if command -v docker >/dev/null 2>&1; then
    if [ "${MODE}" = "run" ]; then
      echo "🚀 تشغيل stack/core (docker compose up -d)..."
      docker compose -f "${CORE_COMPOSE}" up -d || echo "⚠️ فشل docker compose up -d"
    fi

    echo "📊 حالة الحاويات في stack/core:"
    docker compose -f "${CORE_COMPOSE}" ps || echo "⚠️ فشل docker compose ps"
  else
    echo "⚠️ docker غير متاح، لا يمكن فحص/تشغيل stack/core"
  fi
else
  echo "ℹ️ لا يوجد ملف ${CORE_COMPOSE}"
fi
echo

# 7) شجرة مختصرة (عمق 3) للهيكل الحالي
echo "---- [7] Directory tree (depth=3) ----"
if command -v tree >/dev/null 2>&1; then
  tree -L 3
else
  echo "ℹ️ tree غير مثبت، استخدام find كبديل:"
  find . -maxdepth 3 -mindepth 1 -type d | sort
fi
echo

echo "✅ HyperFFactory bootstrap (${MODE}) finished."
