#!/usr/bin/env bash
set -euo pipefail

BASE="/root/HyperFFactory"

echo "====================================="
echo " HyperFFactory - Quick Health Check"
echo "====================================="
echo "Timestamp : $(date)"
echo "Hostname  : $(hostname)"
echo "Base Path : ${BASE}"
echo

# 1) التحقق من وجود المجلد
if [ ! -d "$BASE" ]; then
  echo "❌ المجلد ${BASE} غير موجود"
  exit 1
fi

cd "$BASE"

# 2) حالة Git مختصرة
echo "---- [1] Git status ----"
if command -v git >/dev/null 2>&1; then
  git remote -v || echo "⚠️ لا يمكن قراءة remotes"
  git status --short --branch || echo "⚠️ git status فشل"
else
  echo "⚠️ git غير مثبت"
fi
echo

# 3) حالة القرص
echo "---- [2] Disk usage (/, HyperFFactory) ----"
df -h / "$BASE" | sed '1,3p'
echo

# 4) Python أساسي
echo "---- [3] Python check ----"
if command -v python3 >/dev/null 2>&1; then
  echo -n "python3: "
  python3 -V
else
  echo "⚠️ python3 غير موجود في PATH"
fi
echo

# 5) Docker Compose (stack/core) إن وجد
echo "---- [4] Docker core stack ----"
CORE_COMPOSE="stack/core/docker-compose.core.yml"
if [ -f "$CORE_COMPOSE" ]; then
  if command -v docker >/dev/null 2>&1; then
    docker compose -f "$CORE_COMPOSE" ps || echo "⚠️ فشل docker compose ps"
  else
    echo "⚠️ docker غير مثبت أو غير متاح"
  fi
else
  echo "ℹ️ لا يوجد ملف ${CORE_COMPOSE}"
fi
echo

# 6) شجرة المجلدات (عمق 3)
echo "---- [5] Directory tree (depth=3) ----"
if command -v tree >/dev/null 2>&1; then
  tree -L 3
else
  echo "ℹ️ tree غير مثبت، استخدام find كبديل:"
  find . -maxdepth 3 -mindepth 1 -type d | sort
fi
echo

echo "✅ HyperFFactory quick check finished."
