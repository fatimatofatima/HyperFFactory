#!/usr/bin/env bash
# HyperFFactory – Unified Ops Starter:
# SmartFriend Suite + ffactory stack + Telegram bots
# كل شيء يعمل من داخل /root/HyperFFactory فقط.

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_ops_start_suite_and_ffactory_${TS}.log"

# توجيه الخرج إلى اللوج + الشاشة
exec > >(tee -a "$LOG") 2>&1

echo "====================================================="
echo "HyperFFactory – Start SmartFriend Suite + ffactory + Telegram Bots"
echo "ROOT : $ROOT"
echo "TIME : $TS"
echo "LOG  : $LOG"
echo "====================================================="
echo

# ------------------------------------------------------
# 1) تحديد مسارات SmartFriend و ffactory
# ------------------------------------------------------
SF_ROOT="/opt/smartfriend-suite"
SF_START_SCRIPT="/root/sf_suite_start_all.sh"

FF_DIR=""
for d in "/opt/ffactory" "/root/ffactory" "/root/hyper-factory"; do
  if [ -d "$d" ]; then
    FF_DIR="$d"
    break
  fi
done

echo "SmartFriend root : $SF_ROOT (exists: $( [ -d "$SF_ROOT" ] && echo YES || echo NO ))"
echo "ffactory root    : ${FF_DIR:-<not found>}"
echo

# Helpers
have() { command -v "$1" >/dev/null 2>&1; }

sf_start_service() {
  local svc="$1"
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    echo "  → starting $svc ..."
    if systemctl start "$svc" 2>/dev/null; then
      echo "    ✅ $svc started"
    else
      echo "    ⚠️ failed to start $svc"
    fi
  else
    echo "  → $svc not defined (skipped)"
  fi
}

sf_status_service() {
  local svc="$1"
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    local st
    st="$(systemctl is-active "$svc" 2>/dev/null || true)"
    echo "  - $svc : ${st:-unknown}"
  fi
}

# ------------------------------------------------------
# 2) تشغيل SmartFriend Suite
# ------------------------------------------------------
echo "== Step 1: Start SmartFriend Suite =="
if [ -x "$SF_START_SCRIPT" ]; then
  echo "  استخدام سكربت: $SF_START_SCRIPT"
  if "$SF_START_SCRIPT"; then
    echo "  ✅ sf_suite_start_all.sh انتهى"
  else
    echo "  ⚠️ sf_suite_start_all.sh انتهى بخطأ (نكمّل على أي حال)"
  fi
else
  echo "  ℹ️ لم يتم العثور على $SF_START_SCRIPT – سنبدأ الخدمات يدويًا عبر systemd."
  for svc in \
    sf-core.service \
    sf-web.service \
    sf-health.service \
    sf-db-main.service \
    sf-bot.service \
    sf-bot-pro.service
  do
    sf_start_service "$svc"
  done
fi

echo
echo "== SmartFriend services status =="
for svc in \
  sf-core.service \
  sf-web.service \
  sf-health.service \
  sf-db-main.service \
  sf-bot.service \
  sf-bot-pro.service
do
  sf_status_service "$svc"
done
echo

# ------------------------------------------------------
# 3) Health check لـ SmartFriend APIs
# ------------------------------------------------------
echo "== Step 2: SmartFriend HTTP Health Checks =="
if have curl; then
  for url in \
    "http://127.0.0.1:8214/health" \
    "http://127.0.0.1:8390/health" \
    "http://127.0.0.1:8215/health"
  do
    echo "  - $url"
    if curl -fsS "$url" >/tmp/hf_health_check.$$ 2>&1; then
      echo "    ✅ OK"
    else
      echo "    ⚠️ FAILED"
    fi
  done
  rm -f /tmp/hf_health_check.$$ || true
else
  echo "  ⚠️ curl غير موجود – تخطّي health checks."
fi
echo

# ------------------------------------------------------
# 4) تشغيل ffactory stack (Docker)
# ------------------------------------------------------
echo "== Step 3: Start ffactory stack (Docker) =="
if [ -n "$FF_DIR" ]; then
  echo "  استخدام ffactory من: $FF_DIR"
  if have docker; then
    (
      cd "$FF_DIR"
      if [ -f "stack/docker-compose.core.yml" ]; then
        echo "  → docker compose -f stack/docker-compose.core.yml up -d"
        if docker compose -f stack/docker-compose.core.yml up -d; then
          echo "    ✅ ffactory stack started (core)"
        else
          echo "    ⚠️ docker compose returned non-zero (تحقق من اللوج)"
        fi
      else
        echo "  ⚠️ لم أجد stack/docker-compose.core.yml داخل $FF_DIR"
      fi
    )
  else
    echo "  ⚠️ docker غير موجود – لا يمكن تشغيل ffactory stack."
  fi
else
  echo "  ⚠️ لم يتم العثور على أي مسار ffactory – تم تخطّي هذه الخطوة."
fi
echo

if have docker; then
  echo "== ffactory containers snapshot =="
  docker ps --format '  - {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep 'ffactory' || \
    echo "  (لا يوجد حاويات بأسماء تحتوي ffactory حالياً)"
  echo
fi

# ------------------------------------------------------
# 5) تشغيل بوتات التليجرام (SmartFriend)
#    (قد تكون بدأت بالفعل في خطوة Suite، لكن نعيد التأكيد)
# ------------------------------------------------------
echo "== Step 4: Telegram Bots (SmartFriend) =="
for svc in sf-bot.service sf-bot-pro.service; do
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    echo "  → ensuring $svc is running..."
    systemctl start "$svc" 2>/dev/null || echo "    ⚠️ failed to start $svc"
    sf_status_service "$svc"
  fi
done
echo

# ------------------------------------------------------
# 6) ملخص نهائي
# ------------------------------------------------------
echo "====================================================="
echo "DONE – Unified start flow executed:"
echo "  • SmartFriend Suite"
echo "  • ffactory stack (إن وجد)"
echo "  • Telegram bots (sf-bot / sf-bot-pro عند توفرها)"
echo
echo "Log saved to:"
echo "  $LOG"
echo "====================================================="
