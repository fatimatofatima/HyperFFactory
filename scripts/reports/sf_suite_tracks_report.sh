#!/usr/bin/env bash
set -Eeuo pipefail

# SmartFriend Suite - Service Tracks Report (sf-* فقط)

timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

track_for() {
    local svc="$1"
    case "$svc" in
        # Core / APIs
        sf-health.service|sf-memory.service|sf-unified.service|sf-web.service|sf-core.service|sf-smartfriend.service|sf-smartfrind.service)
            echo "Core / APIs"
            ;;
        # Brain & Learning
        sf-ingest.service|sf-learn.service|sf-learning.service|sf-kb-build.service|sf-fts-maint.service|sf-spider.service)
            echo "Brain & Learning"
            ;;
        # Bots / Interfaces
        sf-bot.service|sf-bot-assistant.service|sf-bot-programmer.service|sf-bot-behavior.service|sf-bot-dev.service|sf-bot-model.service|sf-telegram.service|sf-telegram-audit.service|sf-audit-bot.service)
            echo "Bots / Interfaces"
            ;;
        # Ops & Maintenance
        sf-db-backup.service|sf-db-maintenance.service|sf-backup.service|sf-factory.service|sf-smoke.service|sf-download.service|sf-keys-rotate.service|sf-smartfactory.service)
            echo "Ops & Maintenance"
            ;;
        # Analytics / Cognitive
        sf-cognitive.service)
            echo "Analytics / Cognitive"
            ;;
        # Default
        *)
            echo "Other"
            ;;
    esac
}

echo "SmartFriend Suite - Service Tracks Report (sf-*.service)"
echo "Generated at: ${timestamp}"
echo

# نجلب كل وحدات sf-*.service من systemd كـ unit files (بدون timers/targets)
mapfile -t services < <(systemctl list-unit-files 'sf-*.service' --no-legend 2>/dev/null | awk '{print $1}' | sort)

if [ "${#services[@]}" -eq 0 ]; then
    echo "لا توجد خدمات sf-*.service معرفة في systemd."
    exit 0
fi

# الهيدر
printf '%-28s %-10s %-10s %-24s %s\n' "SERVICE" "ACTIVE" "ENABLED" "TRACK" "EXEC_START"
printf '%0.s-' $(seq 1 120)
echo

# لكل خدمة: حالة التشغيل، حالة التفعيل، المسار، الـ Track
for svc in "${services[@]}"; do
    active="$(systemctl is-active "${svc}" 2>/dev/null || echo "unknown")"
    enabled="$(systemctl is-enabled "${svc}" 2>/dev/null || echo "unknown")"

    exec_raw="$(systemctl show -p ExecStart "${svc}" 2>/dev/null | sed 's/^ExecStart=//')"
    # نأخذ أول أمر فقط، ونزيل أي '-' في البداية
    exec_cmd="$(printf '%s\n' "${exec_raw}" | awk '{print $1}' | sed 's/^-\(.*\)$/\1/')"

    track="$(track_for "${svc}")"

    printf '%-28s %-10s %-10s %-24s %s\n' "${svc}" "${active}" "${enabled}" "${track}" "${exec_cmd}"
done
