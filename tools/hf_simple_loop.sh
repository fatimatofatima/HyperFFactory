#!/usr/bin/env bash
# HyperFFactory – Simple SmartFriend/Integration Watch Loop
# يعرض حالة الخدمات الرئيسية وواجهات HTTP كل فترة زمنية.

set -Euo pipefail

INTERVAL="${1:-60}"

echo "==============================================="
echo "HF Simple Watch Loop – interval = ${INTERVAL} seconds"
echo "Ctrl+C للإيقاف."
echo "==============================================="

check_service() {
    local svc="$1"
    if systemctl is-active "${svc}" >/dev/null 2>&1; then
        echo "SERVICE OK   : ${svc}"
    else
        # يمكن أن يكون غير موجود أو inactive – نعرضه كـ NOT-OK
        if systemctl status "${svc}" >/dev/null 2>&1; then
            echo "SERVICE DOWN : ${svc} (موجود لكن غير active)"
        else
            echo "SERVICE N/A  : ${svc} (غير معرف على هذا السيرفر)"
        fi
    fi
}

check_http() {
    local name="$1"
    local url="$2"

    if command -v curl >/dev/null 2>&1; then
        code="$(curl -s -o /dev/null -w '%{http_code}' "${url}" || echo "000")"
        if [[ "$code" == "200" ]]; then
            echo "HTTP OK      : ${name} (${url}) -> 200"
        else
            echo "HTTP WARN    : ${name} (${url}) -> ${code}"
        fi
    else
        echo "HTTP N/A     : curl غير متوفر لفحص ${name}"
    fi
}

while true; do
    echo
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "--- الخدمات (systemd) ---"
    check_service "sf-web.service"
    check_service "sf-core.service"
    check_service "sf-health.service"
    check_service "sf-memory.service"
    check_service "sf-bot.service"

    echo "--- واجهات HTTP (SmartFriend / Gateway / FFactory) ---"
    check_http "SmartFriend Memory" "http://127.0.0.1:8214/health"
    check_http "SmartFriend Web"    "http://127.0.0.1:8390/health"
    check_http "SmartFriend Health" "http://127.0.0.1:8215/health"
    check_http "SmartFriend Gateway" "http://127.0.0.1:8220/health"
    check_http "FFactory ASR/Echo"   "http://127.0.0.1:8086/health"
    check_http "FFactory Ollama"     "http://127.0.0.1:11435/health"

    echo "-----------------------------------------------"
    echo "انتظار ${INTERVAL} ثانية..."
    sleep "${INTERVAL}"
done

