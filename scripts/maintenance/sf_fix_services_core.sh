#!/bin/bash
set -euo pipefail

echo "=== SmartFriend Suite – Core Fix ==="
echo "[$(date)]"
echo

SUITE_ROOT="/opt/smartfriend-suite"
APP_ROOT="$SUITE_ROOT/smartfriend"

echo "[1] Fix directories and permissions..."
mkdir -p "$APP_ROOT/logs" /var/lib/smartfrind /var/log/smartfrind

# نضمن أن smartfrind يقدر يكتب في اللوج والداتا
chown -R smartfrind:smartfrind \
  /var/lib/smartfrind \
  /var/log/smartfrind \
  "$APP_ROOT/logs" 2>/dev/null || true

# صلاحيات المسارات الرئيسية والـ venv
chmod 755 /opt /opt/smartfriend-suite "$APP_ROOT" 2>/dev/null || true
chmod 755 "$APP_ROOT/venv" "$APP_ROOT/venv/bin" 2>/dev/null || true
if [ -e "$APP_ROOT/venv/bin/python" ]; then
  chmod 755 "$APP_ROOT/venv/bin/python" || true
fi

echo "[2] Fix systemd unit files issues..."

# 2.1 إصلاح smartfrind-monitor.service (إزالة WorkingDirectory من [Install] ووضعه تحت [Service])
MON_UNIT="/etc/systemd/system/smartfrind-monitor.service"
if [ -f "$MON_UNIT" ]; then
  echo "   - Fixing $MON_UNIT (WorkingDirectory in [Install])"
  awk '
  BEGIN { section = "" }
  /^\[.*\]/ { section = $0 }
  {
    # احذف أي WorkingDirectory داخل قسم [Install]
    if (section == "[Install]" && $1 ~ /^WorkingDirectory=/) next;
    print
  }' "$MON_UNIT" > "${MON_UNIT}.tmp" && mv "${MON_UNIT}.tmp" "$MON_UNIT"

  # لو ما فيش WorkingDirectory في [Service] نضيفه
  if ! grep -q "^WorkingDirectory=" "$MON_UNIT"; then
    awk '
      /^\[Service\]$/ { print; print "WorkingDirectory=/opt/smartfriend-suite"; next }
      { print }
    ' "$MON_UNIT" > "${MON_UNIT}.tmp" && mv "${MON_UNIT}.tmp" "$MON_UNIT"
  fi
fi

# 2.2 إعادة إنشاء smartfrind-watch.service كوحدة oneshot تشغّل sf_smart_monitor.sh
WATCH_UNIT="/etc/systemd/system/smartfrind-watch.service"
if [ -f "$WATCH_UNIT" ]; then
  echo "   - Backing up existing $WATCH_UNIT"
  mv "$WATCH_UNIT" "${WATCH_UNIT}.bak.$(date +%Y%m%d_%H%M%S)" || true
fi

cat > "$WATCH_UNIT" << 'UNIT'
[Unit]
Description=SmartFrind Smart Monitor Wrapper
After=network.target

[Service]
Type=oneshot
ExecStart=/root/sf_smart_monitor.sh

[Install]
WantedBy=multi-user.target
UNIT

chmod 644 "$WATCH_UNIT"

# 2.3 إنشاء EnvironmentFile مفقودة لـ raw-clean / runner / trainer
echo "   - Ensuring EnvironmentFile for raw-clean / runner / trainer..."
for svc in smartfrind-raw-clean smartfrind-runner smartfrind-trainer; do
  unit="/etc/systemd/system/${svc}.service"
  [ -f "$unit" ] || continue
  grep -E '^EnvironmentFile=' "$unit" | cut -d= -f2- | while read -r envfile; do
    [ -z "$envfile" ] && continue
    # لو فيها "-" في البداية (اختياري) نشيله من المسار الفعلي
    envpath="${envfile#-}"
    if [ ! -f "$envpath" ]; then
      echo "     * Creating env file: $envpath"
      mkdir -p "$(dirname "$envpath")"
      {
        echo "# Autocreated by sf_fix_services_core.sh"
        echo "# TODO: Fill real values if this service will be used."
      } > "$envpath"
      chmod 640 "$envpath" 2>/dev/null || true
    fi
  done
done

echo "[3] Disable experimental / conflicting services (keep core stable)..."

DISABLE_SERVICES="
smartfrind-ai-gateway
smartfrind-advanced
smartfrind-local
smartfrind-unified
smartfriend-unified
smartfriend-hybrid
smartfriend-smartcore
smartfrind-runner
smartfrind-trainer
smartfrind-raw-clean
smartfrind-ultra
smartfrind-qa
sf-unified
sf-web
"

for svc in $DISABLE_SERVICES; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo "   - Stopping & disabling: $svc.service"
    systemctl stop "${svc}.service" 2>/dev/null || true
    systemctl disable "${svc}.service" 2>/dev/null || true
  fi
done

echo "[4] Reload systemd & restart core services..."

systemctl daemon-reload

CORE_SERVICES="
sf-core
sf-health
sf-memory
smartfrind-api
smartfrind-ask
smartfrind-simple
sf-telegram
"

for svc in $CORE_SERVICES; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo "   - Restarting: $svc.service"
    systemctl restart "${svc}.service" 2>/dev/null || true
  fi
done

echo
echo "[5] Final status (active / failed):"
systemctl list-units "sf-*" "smartfrind-*" --state=active,failed --no-pager

echo
echo "=== Core fix finished. ==="
echo "• لو sf-telegram ما زال يفشل → راجع التوكن داخل /etc/smartfriend/sf-telegram.env"
echo "• الخدمات المعطّلة (ai-gateway, advanced, unified, qa, ultra...) يمكن إعادة تفعيلها لاحقًا بعد تصحيح الكود."
