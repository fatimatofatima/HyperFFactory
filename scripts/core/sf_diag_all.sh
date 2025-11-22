#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

echo "🔍 SmartFriend / FFactory Full Diagnostics"
echo "=========================================="
date

echo
echo "🖥️  System"
echo "----------------------------------------"
uname -a || true
echo
free -h || true
echo
df -h / || true

echo
echo "🤖 SmartFriend Suite"
echo "----------------------------------------"
if have smartfriend; then
  echo "• smartfriend status:"
  smartfriend status || warn "smartfriend status فشل"
  echo
  echo "• smartfriend health:"
  smartfriend health || warn "smartfriend health فشل"
else
  warn "أمر smartfriend غير متاح في PATH"
fi

echo
echo "🐳 FFactory Docker Stack"
echo "----------------------------------------"
STACK_FILE="/opt/ffactory/stack/docker-compose.core.yml"
if [ -f "$STACK_FILE" ]; then
  if have docker; then
    ( cd /opt/ffactory && docker compose -f stack/docker-compose.core.yml ps ) || warn "تعذر تشغيل docker compose ps لـ FFactory"
  else
    warn "docker غير مثبت"
  fi
else
  warn "لم أجد: $STACK_FILE"
fi

echo
echo "🌐 Nginx"
echo "----------------------------------------"
if have nginx; then
  echo "• اختبار كونفيج nginx -t:"
  if ! nginx -t; then
    error "nginx -t أبلغ عن خطأ – غالباً ملف /etc/nginx/conf.d/ff-healthd.conf ما زال يحتاج إصلاح"
  fi
  echo
  echo "• قائمة ملفات الكونفيج في /etc/nginx/conf.d:"
  ls -1 /etc/nginx/conf.d 2>/dev/null || warn "لا توجد ملفات في /etc/nginx/conf.d أو المجلد غير موجود"
else
  warn "nginx غير مثبت"
fi

echo
echo "📡 Ports"
echo "----------------------------------------"
if have ss; then
  ss -tulpn | egrep ':(8000|8170|8211|8214|8220|5432|11434)\b' || warn "لا توجد بورتات مطابقة حالياً"
else
  netstat -tulpn 2>/dev/null | egrep ':(8000|8170|8211|8214|8220|5432|11434)\b' || warn "لا توجد بورتات مطابقة حالياً"
fi

echo
echo "📦 Python / Env"
echo "----------------------------------------"
python3 -V 2>/dev/null || warn "python3 غير موجود"
pip3 --version 2>/dev/null || warn "pip3 غير موجود"

echo
echo "🗃️  SmartFriend SQLite DBs"
echo "----------------------------------------"
if [ -d /opt/smartfriend-suite ]; then
  find /opt/smartfriend-suite -maxdepth 2 -type f -name "*.db" -printf "%p (%k KB)\n" 2>/dev/null || true
else
  warn "/opt/smartfriend-suite غير موجود"
fi

echo
echo "📋 Recent SmartFriend Logs (smart_core)"
echo "----------------------------------------"
LOG_DIR="/opt/smartfriend-suite/logs"
if [ -d "$LOG_DIR" ]; then
  ls -1t "$LOG_DIR" | head -n 5
  echo
  for f in smart_core.log smart_core_current.log smart_core_final.log; do
    if [ -f "$LOG_DIR/$f" ]; then
      echo "----- tail $f -----"
      tail -n 10 "$LOG_DIR/$f" || true
      echo
    fi
  done
else
  warn "مجلد اللوج غير موجود: $LOG_DIR"
fi

echo
echo "✅ انتهى فحص SmartFriend / FFactory"
